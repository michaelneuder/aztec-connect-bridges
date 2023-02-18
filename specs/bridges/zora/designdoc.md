## Zora bridge design doc

_purpose: Present the internal workings of the Zora Bridge including (a) the interface it exposes, (b) the internal data structures and
their relationships, and (c) the test cases covered in the unit and e2e tests._

### Overview 

The Zora Bridge allows users to interact with the [Zora NFT marketplace](https://zora.co/) privately through [Aztec Connect](https://aztec.network/connect/).
The two modules we support are [Zora Asks](https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1) and [Zora Ethereum Auctions](https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH).

### Interface

The bridge functionality is accessed through the `convert` function which is defined in `BridgeBase`: https://github.com/michaelneuder/aztec-connect-bridges/blob/b59fa1304acc4fe00bb1c8b7099f60e556d72bab/src/bridges/base/BridgeBase.sol#L33-L42

This bridge makes use of five of the input parameters `_inputAssetA, _outputAssetA, _totalInputValue, _interactionNonce, _auxData`: https://github.com/michaelneuder/aztec-connect-bridges/blob/b59fa1304acc4fe00bb1c8b7099f60e556d72bab/src/bridges/zora/ZoraBridge.sol#L105-L114

We use the function selector pattern to determine which functionality the user wants to call on the bridge. The 4 least-significant bits of the 
aux data are interpreted as the function selector. The following shows the functions and their respective selectors.

```
Basic:
  -- deposit       funcSelector = uint8(0)
  -- withdrawNft   funcSelector = uint8(1)
  -- withdrawEth   funcSelector = uint8(2)

Zora Asks: https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1
  -- createAsk     funcSelector = uint8(3)
  -- cancelAsk     funcSelector = uint8(4)
  -- fillAsk       funcSelector = uint8(5)

Zora Ethereum Auction: https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH
  -- createAuction funcSelector = uint8(6)
  -- cancelAuction funcSelector = uint8(7)
  -- settleAuction funcSelector = uint8(8)
  -- createBid     funcSelector = uint8(9)
```

We will go through each of these functions individually. 

#### deposit -> funcSelector = 0

- _purpose:_ allows the users to deposit ERC-721 tokens into the bridge. 
- _inputs:_ 
  - `_inputAssetA      : AztecTypes.AztecAssetType.ETH`
  - `_outputAssetA     : AztecTypes.AztecAssetType.VIRTUAL`
  - `_totalInputValue  : not used`
  - `_interactionNonce : tokenId of retruned virtual token`
  - `_auxData          : not used`
- _description:_ The user first calls `deposit` to issue a VirtualAsset and then calls `matchAndPull` on the contract to transfer the token to the bridge. 
- _state modification:_ In `matchAndPull`, the `nftAssets` mapping is updated with the virtual asset tokenId (which is the `_interactionNonce`) to map the 
collection and token Id of the ERC-721 token.
- _token transfers:_ `matchAndPull` transfers the ERC-721 token from the caller address to the bridge.
- _checks_: 
  - Assert that the virtual token Id does not already correspond to an NFT in the the `nftAssets` mapping.
  - Check that the NFT being deposited does not have an outstanding bid in the bridge. If it does, then mark that bid as `withdrawEthOnly`.
- _misc:_
  - The second check above is needed to avoid multiple virtual tokens being able to withdraw the NFT from the bridge. If there is an outstanding bid for the NFT, then by definition, the bid must have lost the auction on Zora, so marking the bid as `withdrawEthOnly` ensures that the owner of that bid is only able to withdraw the ETH that they used for the bid rather than the NFT.

#### withdrawNft -> funcSelector = 1

- _purpose:_ allows the users to withdraw ERC-721 tokens from the bridge. 
- _inputs:_ 
  - `_inputAssetA      : AztecTypes.AztecAssetType.VIRTUAL`
  - `_outputAssetA     : AztecTypes.AztecAssetType.ETH`
  - `_totalInputValue  : not used`
  - `_interactionNonce : not used`
  - `_auxData          : bits[4-64) = registryKey`
- _description:_ The user calls tihs function with a virtual token that corresponds to an NFT in the bridge. They are then allowed to withdraw it to an address stored in the address registry. 
- _state modification:_ The `nftAssets` entry is deleted if the token is succesfully transfered.
- _token transfers:_  the ERC-721 token is transferred from the bridge to the address fetched from the address registry.
- _checks_: 
  - Assert that the virtual token Id corresponds to an NFT in the the `nftAssets` mapping.
  - Check that the NFT being withdrawn does not have an outstanding bid that is marked as `withdrawEthOnly` in the bridge.
- _misc:_
  - The second check above is to make sure that this virtual token is the true owner of the NFT.

#### withdrawEth -> funcSelector = 2

- _purpose:_ allows the users to withdraw ETH from the bridge due to a losing auction bid.
- _inputs:_ 
  - `_inputAssetA      : AztecTypes.AztecAssetType.VIRTUAL`
  - `_outputAssetA     : AztecTypes.AztecAssetType.ETH`
  - `_totalInputValue  : not used`
  - `_interactionNonce : not used`
  - `_auxData          : not used`
- _description:_ The function first fetches the NFT details corresponding to the virtual token from `nftAssets`. Then it fetches the bid details from `auctionBids`. Using these two pieces of data it checks the `ZoraAuctions` contract for an existing auction on that NFT. If the auction is still running, and this bid is still the max bid, don't let the withdrawl proceed. Otherwise, allow them to withdraw the ETH.
- _state modification:_ In `matchAndPull`, the `nftAssets` mapping is updated with the virtual asset tokenId (which is the `_interactionNonce`) to map the 
collection and token Id of the ERC-721 token.
- _token transfers:_ ETH is returned in the `_outputValueA`.
- _checks_: 
  - Assert that the virtual token Id corresponds to a NFT in `nftAssets`.
  - Assert that the virtual token Id corresponds to a bid in `nftBids`.
  - Assert that the bid is no longer the max bid on the auction.
- _misc:_
  - The third check above is needed to make sure the user isn't withdrawing ETH from a currently running auction.


#### createAsk -> funcSelector = 3

- _purpose:_ allows the users to create an Ask on the Zora contract. 
- _inputs:_ 
  - `_inputAssetA      : AztecTypes.AztecAssetType.VIRTUAL`
  - `_outputAssetA     : AztecTypes.AztecAssetType.VIRTUAL`
  - `_totalInputValue  : not used`
  - `_interactionNonce : tokenId of returned virtual token`
  - `_auxData          : bits[4-34) = askPrice, bits[34-64) = registryKey`
- _description:_ The NFT which the ask is being created for must be owned by the bridge. The user specifies a recipient for the seller funds as well as an ask price by using the aux data. 


### Internal data structures

### Test cases
