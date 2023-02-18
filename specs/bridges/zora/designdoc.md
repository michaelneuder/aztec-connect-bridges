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
- _misc:_ The virtual 

### Internal data structures

### Test cases
