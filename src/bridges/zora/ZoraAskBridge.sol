// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AztecTypes} from "rollup-encoder/libraries/AztecTypes.sol";
import {ErrorLib} from "../base/ErrorLib.sol";
import {BridgeBase} from "../base/BridgeBase.sol";
import {AddressRegistry} from "../registry/AddressRegistry.sol";

// https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1
contract ZoraAsk {
    function createAsk(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _askPrice,
        address _askCurrency,
        address _sellerFundsRecipient,
        uint16 _findersFeeBps
    ) external {}

    function fillAsk(
        address _tokenContract,
        uint256 _tokenId,
        address _fillCurrency,
        uint256 _fillAmount,
        address _finder
    ) external {}

    function cancelAsk(address _tokenContract, uint256 _tokenId) external {}
}

contract ZoraAskBridge is BridgeBase {
    struct NftAsset {
        address collection;
        uint256 tokenId;
    }

    // Holds the VIRTUAL token -> NFT relationship.
    mapping(uint256 => NftAsset) public nftAssets;

    error InvalidVirtualAssetId();

    // Other contracts.
    ZoraAsk internal zAsk;
    AddressRegistry public immutable registry;

    // Constants
    uint64 internal constant MASK_4  = 0xf;
    uint64 internal constant MASK_30 = 0x3fffffff;

    // Need to pass the zora & registry addresses to construct the bridge.
    constructor(address _rollupProcessor, address _zoraAsk, address _registry) BridgeBase(_rollupProcessor) {
        zAsk = ZoraAsk(_zoraAsk);
        registry = AddressRegistry(_registry);
    }

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
        */

        uint8 funcSelector = uint8(_auxData & MASK_4);

        /* 
            deposit
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-64)  = unused        [60 bits]
        */ 
        if (funcSelector == 0) {
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidInputA();
            }
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }

            // Send back a virtual asset.
            return (1, 0, false);
        }
        /* 
            withdraw
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-64)  = registryKey   [60 bits]
        */ 
        if (funcSelector == 1) {
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidOutputA();
            }
            // Fetch the NFT details from the mapping using the virtual token id as the key.
            NftAsset memory token = nftAssets[_inputAssetA.id];
            if (token.collection == address(0x0)) {
                revert ErrorLib.InvalidInputA();
            }
            // Fetch the address to send the NFT to from the registry.
            address to = registry.addresses(_auxData >> 4);
            if (to == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }
            // Delete the asset from storage and transfer it out.
            delete nftAssets[_inputAssetA.id];
            IERC721(token.collection).transferFrom(address(this), to, token.tokenId);
            return (0, 0, false);
        }
        /* 
            createAsk: https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1#createask
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-34)  = askPrice      [30 bits]
                bits[34-64) = registryKey   [30 bits]
        */ 
        else if (funcSelector == 2) {
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }
            // Fetch the NFT details from the mapping using the virtual token id as the key.
            NftAsset memory token = nftAssets[_inputAssetA.id];
            if (token.collection == address(0x0)) {
                revert ErrorLib.InvalidInputA();
            }
            // Parse auxData.
            uint256 askPrice = (_auxData >> 4) & MASK_30; 
            address sellerFundsRecipient = registry.addresses(_auxData >> 34);
            if (sellerFundsRecipient == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }
            // Call external zora contract.
            zAsk.createAsk(
                token.collection,
                token.tokenId,
                askPrice,
                address(0x0),         // 0 address to indicate this ask is in ETH.
                sellerFundsRecipient,
                0                     // Leave the finder fee as 0.
            );
            // Update the asset map to correlate new virtual token with existing
            // bridge-owned nft.
            _updateVirtualAssetId(_inputAssetA.id, _interactionNonce);
            return (1, 0, false);
        }
        /* 
            cancelAsk: https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1#cancelask
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-64)  = unused        [60 bits]
        */ 
        else if (funcSelector == 3) {
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }
            // Fetch the NFT details from the mapping using the virtual token id as the key.
            NftAsset memory token = nftAssets[_inputAssetA.id];
            if (token.collection == address(0x0)) {
                revert ErrorLib.InvalidInputA();
            }
            // Call external zora contract.
            zAsk.cancelAsk(token.collection, token.tokenId);
            // Update the asset map to correlate new virtual token with existing
            // bridge-owned nft.
            _updateVirtualAssetId(_inputAssetA.id, _interactionNonce);
            return (1, 0, false);
        }
        /* 
            fillAsk: https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1#fillask
          
            _auxData = 
                bits[0-4)   = funcSelector   [ 4 bits]
                bits[4-34)  = collectionKey  [30 bits]
                bits[34-64) = tokenId        [30 bits]
        */ 
        else if (funcSelector == 4) {
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidInputA();
            }
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }
            // Parse aux data.
            uint256 collectionKey = (_auxData >> 4) & MASK_30;
            uint256 tokenId = _auxData >> 34;
            // Fetch collection address using collection key.
            address collection = registry.addresses(collectionKey);
            if (collection == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }
            zAsk.fillAsk(
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

    // Function to match a virtual token id with an NFT and transfer the ownership to the bridge.
    function matchAndPull(uint256 _virtualAssetId, address _collection, uint256 _tokenId) external {
        // Virtual token already associated with a different ERC-721 in the mapping.
        if (nftAssets[_virtualAssetId].collection != address(0x0)) {
            revert InvalidVirtualAssetId();
        }
        nftAssets[_virtualAssetId] = NftAsset({
            collection: _collection,
            tokenId: _tokenId
        });
        IERC721(_collection).transferFrom(msg.sender, address(this), _tokenId);
    }

    // Function to update the nftAssets mapping to a new virtual asset id.
    function _updateVirtualAssetId(uint256 _inputAssetId, uint256 _interactionNonce) internal {
        NftAsset memory token = nftAssets[_inputAssetId];
        nftAssets[_interactionNonce] = token;
        delete nftAssets[_inputAssetId];
    }
}
