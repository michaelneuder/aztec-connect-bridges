// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AztecTypes} from "rollup-encoder/libraries/AztecTypes.sol";
import {ErrorLib} from "../base/ErrorLib.sol";
import {BridgeBase} from "../base/BridgeBase.sol";
import {AddressRegistry} from "../registry/AddressRegistry.sol";

// Get function definition from: https://github.com/ourzora/v3/blob/1d4c0c951ccd5c1d446283ce6fef3757ad97b804/contracts/modules/Asks/V1.1/AsksV1_1.sol#L302.
contract ZoraAsk {
    function fillAsk(
        address _tokenContract,
        uint256 _tokenId,
        address _fillCurrency,
        uint256 _fillAmount,
        address _finder
    ) external {}
}

contract ZoraBridge is BridgeBase {
    struct NftAsset {
        address collection;
        uint256 tokenId;
    }
    // Holds the VIRTUAL token -> NFT relationship.
    mapping(uint256 => NftAsset) public nftAssets;

    // Other contracts.
    ZoraAsk internal za;
    AddressRegistry public immutable registry;

    // Need to pass the zora & registry addresses to construct the bridge.
    constructor(address _rollupProcessor, address _zora, address _registry) BridgeBase(_rollupProcessor) {
        za = ZoraAsk(_zora);
        registry = AddressRegistry(_registry);
    }

    event Debug (
        uint256 auxData
    );

    // Converts ETH into a virtual token by filling an ask on the Zora contract.
    function convert(
        AztecTypes.AztecAsset calldata _inputAssetA,
        AztecTypes.AztecAsset calldata,
        AztecTypes.AztecAsset calldata _outputAssetA,
        AztecTypes.AztecAsset calldata,
        uint256 _totalInputValue,
        uint256 _interactionNonce,
        uint64 _auxData,
        address
    ) external payable override (BridgeBase) onlyRollup returns (uint256 outputValueA, uint256 outputValueB, bool async) {
        // Invalid input and output types.
        if (_inputAssetA.assetType == AztecTypes.AztecAssetType.NOT_USED ||
            _inputAssetA.assetType == AztecTypes.AztecAssetType.ERC20
        ) revert ErrorLib.InvalidInputA();
        if (
            _outputAssetA.assetType == AztecTypes.AztecAssetType.NOT_USED ||
            _outputAssetA.assetType == AztecTypes.AztecAssetType.ERC20
        ) revert ErrorLib.InvalidOutputA();

        /* 
            This contract supports a number of operations. The user indicates
            what function they want to call by using function selector codes.
            Below are the operations we support and the function selector for
            each. The 4 least-significant bits of the aux data will be
            interpreted as the function selector. The remaining bits of the aux 
            data will be used for additional data specified in each function. 

            NOTE: We cast the function selector to a uint8 because that is the
            smallest integer size supported. We LAND the bits with 0xf so that
            we only consider the four least-significant bits.

            Basic:
              -- deposit       funcSelector = uint8(0)
              -- withdraw      funcSelector = uint8(1)

            Zora Asks: https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1
              -- createAsk     funcSelector = uint8(2)
              -- cancelAsk     funcSelector = uint8(3)
              -- fillAsk       funcSelector = uint8(4)

            Zora Ethereum Auction: https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH
              -- createAuction funcSelector = uint8(5)
              -- cancelAuction funcSelector = uint8(6)
              -- settleAuction funcSelector = uint8(7)
              -- createBid     funcSelector = uint8(8)

            Zora Offers: https://docs.zora.co/docs/smart-contracts/modules/Offers/zora-v3-offers-latest
              -- createOffer   funcSelector = uint8(9)
        */

        uint8 funcSelector = uint8(_auxData & 0xf);

        /* 
            withdraw
          
            _auxData = 
                bits[0-4)   = funcSelector
                bits[4-64)  = registryKey
        */ 
        if (funcSelector == 1) {
            // Input type needs to be VIRTUAL.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be ETH.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidOutputA();
            }

            // Fetch the NFT details from the mapping using the virtual token id as the key.
            NftAsset memory token = nftAssets[_inputAssetA.id];
            if (token.collection == address(0x0)) {
                revert ErrorLib.InvalidInputA();
            }

            address to = registry.addresses(_auxData >> 4);
            emit Debug(
                _auxData >> 4
            );
            
            if (to == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }
            delete nftAssets[_inputAssetA.id];
            IERC721(token.collection).transferFrom(address(this), to, token.tokenId);
            return (0, 0, false);
        }
        /* 
            fillAsk: https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1#fillask
          
            _auxData = 
                bits[0-4)   = funcSelector
                bits[4-34)  = collectionKey
                bits[34-64) = tokenId
        */ 
        else if (funcSelector == 4) {
            // Input type needs to be ETH.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }

            uint256 collectionKey = (_auxData >> 4) & 0x3fffffff;
            uint256 tokenId = _auxData >> 34;

            address collection = registry.addresses(collectionKey);
            if (collection == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }

            za.fillAsk(
                collection,
                tokenId,
                address(0x0),     // 0 address to indicate this sale is in ETH.
                _totalInputValue, // Use the total input value to specify how much ETH to fill the ask with.
                address(0x0)      // Leave the finder address empty.
            );

            // Update the mapping with the virtual token Id.
            nftAssets[_interactionNonce] = NftAsset({
                collection: collection,
                tokenId: tokenId
            });

            // Return the virtual token.
            return (1, 0, false);
        } else {
            revert ErrorLib.InvalidAuxData();
        }
    }
}
