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

// https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH
contract ZoraAuction {
    struct Auction {
        address seller;
        uint96 reservePrice;
        address sellerFundsRecipient;
        uint96 highestBid;
        address highestBidder;
        uint32 duration;
        uint32 startTime;
        uint32 firstBidTime;
    }

    mapping(address => mapping(uint256 => Auction)) public auctionForNFT;

    function createAuction(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _duration,
        uint256 _reservePrice,
        address _sellerFundsRecipient,
        uint256 _startTime
    ) external {}

    function cancelAuction(address _tokenContract, uint256 _tokenId) external {}
    function settleAuction(address _tokenContract, uint256 _tokenId) external {}
    function createBid(address _tokenContract, uint256 _tokenId) external payable {}
}

contract ZoraBridge is BridgeBase {
        struct NftAsset {
            address collection;
            uint256 tokenId;
        }

        struct AuctionBid {
            uint256  amount;
            bool     withdrawEthOnly;
            uint32   startTime;
        }

    // Holds the VIRTUAL token -> NFT relationship.
    mapping(uint256 => NftAsset) public nftAssets;
    // Holds the VIRTUAL token -> Bid relationship.
    mapping(uint256 => AuctionBid) public auctionBids;
    // Holds the collection -> tokenId -> virtualTokenId mapping. 
    mapping(address => mapping(uint256 => uint256)) public nftsWithBids;

    error InvalidVirtualAssetId();

    // Other contracts.
    ZoraAsk internal zAsk;
    ZoraAuction internal zAuc;
    AddressRegistry public immutable registry;

    // Constants
    uint64 internal constant MASK_4           = 0xf;
    uint64 internal constant MASK_10          = 0x3ff;
    uint64 internal constant MASK_20          = 0xfffff;
    uint64 internal constant MASK_28          = 0xfffffff;
    uint64 internal constant MASK_30          = 0x3fffffff;
    uint64 internal constant SECONDS_IN_HOUR  = 60 * 60;
    uint64 internal constant WEI_PER_MICROETH = 1000 * 1000000000;

    // Need to pass the zora & registry addresses to construct the bridge.
    constructor(address _rollupProcessor, address _zoraAsk, address _zoraAuction, address _registry) BridgeBase(_rollupProcessor) {
        zAsk = ZoraAsk(_zoraAsk);
        zAuc = ZoraAuction(_zoraAuction);
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
        */

        uint8 funcSelector = uint8(_auxData & MASK_4);

        /* 
            deposit
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-64)  = unused        [60 bits]
        */ 
        if (funcSelector == 0) {
            // Input type needs to be ETH.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }

            // Send back a virtual asset.
            return (1, 0, false);
        }
        /* 
            withdrawNft
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-64)  = registryKey   [60 bits]
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
            // Check for the presence of a bid with withdrawEthOnly == true.
            AuctionBid memory bid = auctionBids[_inputAssetA.id];
            if (bid.withdrawEthOnly) {
                revert ErrorLib.InvalidInputA();
            }
            // Cannot store the address locally because of stack too deep.
            if (registry.addresses(_auxData >> 4) == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }
            delete nftAssets[_inputAssetA.id];
            IERC721(token.collection).transferFrom(address(this), registry.addresses(_auxData >> 4), token.tokenId);
            return (0, 0, false);
        }
        /* 
            withdrawEth
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-64)  = registryKey   [60 bits]
        */ 
        if (funcSelector == 2) {
            // Input type needs to be VIRTUAL.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be ETH.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidOutputA();
            }
            uint256 inputAssetId = _inputAssetA.id;
            // Fetch the NFT details from the mapping using the virtual token id as the key.
            NftAsset memory token = nftAssets[inputAssetId];
            if (token.collection == address(0x0)) {
                revert ErrorLib.InvalidInputA();
            }
            // Fetch the bid details.
            AuctionBid memory bid = auctionBids[inputAssetId];
            if (bid.amount == 0) {
                revert ErrorLib.InvalidInputA();
            }
            // Check that the bid is no longer the highest in the auction.
            (,,,,,, uint32 startTime,) = zAuc.auctionForNFT(token.collection, token.tokenId);
            if (bid.startTime == startTime) {
                revert ErrorLib.InvalidInputA();
            }
            delete nftAssets[inputAssetId];
            delete auctionBids[inputAssetId];
            return (bid.amount, 0, false);
        }
        /* 
            createAsk: https://docs.zora.co/docs/smart-contracts/modules/Asks/zora-v3-asks-v1.1#createask
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-34)  = askPrice      [30 bits]
                bits[34-64) = registryKey   [30 bits]
        */ 
        else if (funcSelector == 3) {
            // Input type needs to be VIRTUAL.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
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
        else if (funcSelector == 4) {
            // Input type needs to be VIRTUAL.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
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
        else if (funcSelector == 5) {
            // Input type needs to be ETH.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }

            uint256 collectionKey = (_auxData >> 4) & MASK_30;
            uint256 tokenId = _auxData >> 34;

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

            // Check if the token has a bid associated with it.
            uint256 bidVirtualToken = nftsWithBids[collection][tokenId];
            if (bidVirtualToken != 0) {
                auctionBids[bidVirtualToken].withdrawEthOnly = true;
            }

            // Update the mapping with the virtual token Id.
            nftAssets[_interactionNonce] = NftAsset({
                collection: collection,
                tokenId: tokenId
            });

            // Return the virtual token.
            return (1, 0, false);
        }
        /* 
            createAuction: https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH#createauction
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-32)  = reservePrice  [28 bits]  in microether (1000 GWEI). max = 2^28-1 = 268435455000 GWEI ~= 268.4 ETH
                bits[32-52) = registryKey   [20 bits]
                bits[52-56) = startTime     [ 4 bits]  in hours from now. max = 2^4-1 = 15 hours
                bits[56-63) = duration      [ 8 bits]  in 4 hour increments from now. max = 4 * 2^8-1 = 4 * 255 = 1020 hours = 42.5 days
        */ 
        else if (funcSelector == 6) {
            // Input type needs to be VIRTUAL.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }

            // Set to avoid stack too deep.
            uint256 assetId = _inputAssetA.id;

            // Fetch the NFT details from the mapping using the virtual token id as the key.
            NftAsset memory token = nftAssets[assetId];
            if (token.collection == address(0x0)) {
                revert ErrorLib.InvalidInputA();
            }

            // Calculate reserve price in WEI (passed in microether so we have to convert).
            uint256 reservePrice = ((_auxData >> 4) & MASK_28) * WEI_PER_MICROETH;

            // Extract the fee recipient registry key and get the address.
            // uint256 registryKey = ((_auxData >> 32) & MASK_20);
            address sellerFundsRecipient = registry.addresses((_auxData >> 32) & MASK_20);
            if (sellerFundsRecipient == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }

            // Calculate start time in epoch seconds (we convert hours to seconds).
            uint256 startTime = block.timestamp + ((_auxData >> 52) & MASK_4) * SECONDS_IN_HOUR;

            // Calculate the duration of the auction in seconds.
            uint256 duration = 4 * (_auxData >> 56) * SECONDS_IN_HOUR;

            zAuc.createAuction(
                token.collection,
                token.tokenId,
                duration,
                reservePrice,
                sellerFundsRecipient,
                startTime
            );

            // Update the asset map to correlate new virtual token with existing
            // bridge-owned nft.
            _updateVirtualAssetId(assetId, _interactionNonce);

            // Return the virtual token.
            return (1, 0, false);
        } 
        /* 
            cancelAuction: https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH#cancelauction
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-63)  = unused        [60 bits]
        */ 
        else if (funcSelector == 7) {
            // Input type needs to be VIRTUAL.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }

            // Fetch the NFT details from the mapping using the virtual token id as the key.
            NftAsset memory token = nftAssets[_inputAssetA.id];
            if (token.collection == address(0x0)) {
                revert ErrorLib.InvalidInputA();
            }

            zAuc.cancelAuction(
                token.collection,
                token.tokenId
            );

            // Update the asset map to correlate new virtual token with existing
            // bridge-owned nft.
            _updateVirtualAssetId(_inputAssetA.id, _interactionNonce);

            // Return the virtual token.
            return (1, 0, false);
        }
        /* 
            settleAuction: https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH#settleauction
          
            _auxData = 
                bits[0-4)   = funcSelector  [ 4 bits]
                bits[4-63)  = unused        [60 bits]
        */ 
        else if (funcSelector == 8) {
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

            zAuc.settleAuction(
                token.collection,
                token.tokenId
            );

            // Delete the NFT from the mapping. If settleAuction succeeds, then
            // that means the NFT is transferred out to the winning bid.
            delete nftAssets[_inputAssetA.id];

            return (0, 0, false);
        }
        /* 
            createBid: https://docs.zora.co/docs/smart-contracts/modules/ReserveAuctions/Core/zora-v3-auctions-coreETH#createbid
          
            _auxData = 
                bits[0-4)   = funcSelector   [ 4 bits]
                bits[4-34)  = collectionKey  [30 bits]
                bits[34-64) = tokenId        [30 bits]
        */ 
        else if (funcSelector == 9) {
            // Input type needs to be ETH.
            if (_inputAssetA.assetType != AztecTypes.AztecAssetType.ETH) {
                revert ErrorLib.InvalidInputA();
            }
            // Output type needs to be VIRTUAL.
            if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) {
                revert ErrorLib.InvalidOutputA();
            }

            uint256 collectionKey = (_auxData >> 4) & MASK_30;
            uint256 tokenId = _auxData >> 34;

            address collection = registry.addresses(collectionKey);
            if (collection == address(0x0)) {
                revert ErrorLib.InvalidAuxData();
            }

            zAuc.createBid{value: _totalInputValue}(
                collection,
                tokenId
            );

            // Update the mapping with the virtual token Id.
            nftAssets[_interactionNonce] = NftAsset({
                collection: collection,
                tokenId: tokenId
            });

            // Fetch the start time of the auction.
            (,,,,,, uint32 startTime,) = zAuc.auctionForNFT(collection, tokenId);

            // Update the auctionBids mapping.
            auctionBids[_interactionNonce] = AuctionBid({
                amount: _totalInputValue,
                withdrawEthOnly: false,
                startTime: startTime
            });

            // Update the inverse mapping.
            nftsWithBids[collection][tokenId] = _interactionNonce;

            // Return virtual asset.
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
        // Check if the token has a bid associated with it.
        uint256 bidVirtualToken = nftsWithBids[_collection][_tokenId];
        if (bidVirtualToken != 0) {
            auctionBids[bidVirtualToken].withdrawEthOnly = true;
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
