// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {BridgeTestBase} from "./../../aztec/base/BridgeTestBase.sol";
import {AztecTypes} from "rollup-encoder/libraries/AztecTypes.sol";
import {ERC721PresetMinterPauserAutoId} from "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ErrorLib} from "../../../bridges/base/ErrorLib.sol";
import {AddressRegistry} from "../../../bridges/registry/AddressRegistry.sol";
import {ZoraBridge} from "../../../bridges/zora/ZoraBridge.sol";
import {ZoraAsk} from "../../../bridges/zora/ZoraBridge.sol";
import {ZoraAuction} from "../../../bridges/zora/ZoraBridge.sol";

// @notice The purpose of this test is to directly test convert functionality of the bridge.
contract ZoraUnitTest is BridgeTestBase {
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant REGISTER_ADDRESS = address(0xdeadbeef);
    uint256 private constant INTERACTION_NONCE = 84;
    uint256 private constant TOKEN_ID = 1;
    
    address private rollupProcessor;

    ZoraAsk private ask;
    ZoraAuction private auction;
    ZoraBridge private bridge;
    AddressRegistry private registry;
    ERC721PresetMinterPauserAutoId private nftContract;

    // Test AztecAssets.
    AztecTypes.AztecAsset private ethAsset =
        AztecTypes.AztecAsset({id: 0, erc20Address: address(0x0), assetType: AztecTypes.AztecAssetType.ETH});
    AztecTypes.AztecAsset private erc20OutputAsset =
        AztecTypes.AztecAsset({id: 1, erc20Address: DAI, assetType: AztecTypes.AztecAssetType.ERC20});
    AztecTypes.AztecAsset private virtualAsset1 =
        AztecTypes.AztecAsset({id: 1, erc20Address: address(0x0), assetType: AztecTypes.AztecAssetType.VIRTUAL});
    AztecTypes.AztecAsset private virtualAssetInteractionNonce =
        AztecTypes.AztecAsset({id: INTERACTION_NONCE, erc20Address: address(0x0), assetType: AztecTypes.AztecAssetType.VIRTUAL});

    // @dev This method exists on RollupProcessor.sol. It's defined here in order to be able to receive ETH like a real
    //      rollup processor would.
    function receiveEthFromBridge(uint256 _interactionNonce) external payable {}

    function setUp() public {
        // In unit tests we set address of rollupProcessor to the address of this test contract
        rollupProcessor = address(this);

        // Initialize all contracts.
        registry = new AddressRegistry(rollupProcessor);
        ask = new ZoraAsk();
        auction = new ZoraAuction();
        bridge = new ZoraBridge(rollupProcessor, address(ask), address(auction), address(registry));
        
        // Set ETH balance of bridge to 50000.
        vm.deal(address(bridge), 50000);

        // Create test NFT contract and mint 2 ERC-721 tokens (tokenIds 0 & 1).
        nftContract = new ERC721PresetMinterPauserAutoId("test", "NFT", "");
        // The owner is the bridge. Mint 2 to have a non-zero token id.
        nftContract.mint(address(this)); // tokenID = 0
        nftContract.mint(address(this)); // tokenID = 1
        nftContract.approve(address(bridge), 0);
        nftContract.approve(address(bridge), 1);

        // Get virtual assets to use for registry.
        registry.convert(ethAsset, emptyAsset, virtualAsset1, emptyAsset, 1, 0, 0, address(0x0));
        
        // Register 0xdeadbeef, which we use as a fake customer address.
        uint256 inputAmount = uint160(address(REGISTER_ADDRESS));
        // 0 -> address(0xdeadbeef).
        registry.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, inputAmount, 0, 0, address(0x0));

        // Register the nftContract address. This is the collection of our fake
        // NFTs.
        inputAmount = uint160(address(nftContract));
        // 1 -> address(nftContract).
        registry.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, inputAmount, 0, 0, address(0x0));
    }

    // Misc unit tests.
    function testInvalidCaller(address _callerAddress) public {
        vm.assume(_callerAddress != rollupProcessor);
        // Use HEVM cheatcode to call from a different address than is address(this)
        vm.prank(_callerAddress);
        vm.expectRevert(ErrorLib.InvalidCaller.selector);
        bridge.convert(emptyAsset, emptyAsset, emptyAsset, emptyAsset, 0, 0, 0, address(0x0));
    }

    function testInvalidInputAssetType() public {
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(emptyAsset, emptyAsset, emptyAsset, emptyAsset, 0, 0, 0, address(0x0));
    }

    function testInvalidOutputAssetType() public {
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        bridge.convert(ethAsset, emptyAsset, erc20OutputAsset, emptyAsset, 0, 0, 0, address(0x0));
    }

    function testInvalidFuncSelector() public {
        uint64 funcSelector = 15; // func selector doesn't exist.
        vm.expectRevert(ErrorLib.InvalidAuxData.selector);
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    /*  
        function   |   selector
        --------------------------------------
        deposit    |   uint8(0)
    */

    // Revert test cases.
    function testDepositInvalidInputAType() public {
        uint64 funcSelector = 0;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be eth type.
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testDepositInvalidOutputAType() public {
        uint64 funcSelector = 0;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    // Success test case.
    function testDepositSuccess() public {
        uint64 funcSelector = 0;

        // Deposit. 
        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            ethAsset,
            emptyAsset,
            virtualAssetInteractionNonce,
            emptyAsset,
            0,                  // _totalInputValue 
            INTERACTION_NONCE,  // _interactionNonce 
            funcSelector,       // auxData
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 1, "Output value A is not 0");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Call match and pull with tokenId = 1.
        bridge.matchAndPull(INTERACTION_NONCE, address(nftContract), TOKEN_ID);

        // Check that owner is now the bridge.
        assertEq(IERC721(address(nftContract)).ownerOf(TOKEN_ID), address(bridge));

        // Check that the internal nftAssets mapping is updated.
        (address storedCollection, uint256 storedTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(storedCollection, address(nftContract), "Unexpected collection address");
        assertEq(storedTokenId, TOKEN_ID, "Unexpected tokenId");
    }

    /*  
        function   |   selector
        --------------------------------------
        withdraw   |   uint8(1)
    */

    // Revert test cases.
    function testWithdrawInvalidInputAType() public {
        uint64 funcSelector = 1;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testWithdrawInvalidOutputAType() public {
        uint64 funcSelector = 1;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be eth type.
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testWithdrawInvalidVirtualTokenId() public {
        uint64 funcSelector = 1;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // No NFTs in the bridge, so fetching collection address fails.
        bridge.convert(virtualAsset1, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testWithdrawAddressNotRegistered() public {
        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);

        uint64 funcSelector = 1;
        // This registryKey is out of range for the registry.
        uint64 registryKey = uint64(registry.addressCount());
        // Construct auxData.
        uint64 auxData = (registryKey << 4) | funcSelector;
        vm.expectRevert(ErrorLib.InvalidAuxData.selector);
        bridge.convert(virtualAssetInteractionNonce, emptyAsset, ethAsset, emptyAsset, 0, 0, auxData, address(0x0));
    }

    // Success test case.
    function testWithdrawSuccess() public {
        uint64 funcSelector = 1;
        // The output address is registered with key=0.
        uint64 registryKey = 0;
        // Construct auxData.
        uint64 auxData = (registryKey << 4) | funcSelector;

        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);

        // Then withdraw. 
        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            virtualAssetInteractionNonce,
            emptyAsset,
            ethAsset,
            emptyAsset,
            0,       // _totalInputValue 
            0,       // _interactionNonce 
            auxData, // _auxData -> withdraw to 0xdeadbeef
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 0, "Output value A is not 0");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets mapping is deleted.
        (address storedCollection, uint256 storedTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(storedCollection, address(0x0), "Unexpected collection address");
        assertEq(storedTokenId, 0, "Unexpected tokenId");

        // Check that the transfer happened.
        address owner = IERC721(address(nftContract)).ownerOf(TOKEN_ID);
        assertEq(owner, REGISTER_ADDRESS);
    }

    /*  
        function   |   selector
        --------------------------------------
        createAsk  |   uint8(2)
    */
 
    // Revert test cases.
    function testCreateAskInvalidInputAType() public {
        uint64 funcSelector = 2;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateAskInvalidOutputAType() public {
        uint64 funcSelector = 2;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be virtual type.
        bridge.convert(virtualAsset1, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateAskInvalidCollectionAddress() public {
        uint64 funcSelector = 2;
        // No NFTs in the bridge, so fetching collection address fails.
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateAskInvalidRecipient() public {
        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);

        uint64 funcSelector = 2;
        // This registryKey is out of range for the registry.
        uint64 registryKey = uint64(registry.addressCount());
        // Construct auxData.
        uint64 auxData = (registryKey << 34) | funcSelector;
        // sellerFundsRecipient will be null address.
        vm.expectRevert(ErrorLib.InvalidAuxData.selector);
        bridge.convert(virtualAssetInteractionNonce, emptyAsset, virtualAssetInteractionNonce, emptyAsset, 0, 0, auxData, address(0x0));
    }

    // Success test case.
    function testCreateAskSuccess() public {
        uint64 funcSelector = 2;
        // The output address is registered with key=0.
        uint64 registryKey = 0;
        // Construct auxData.
        uint64 auxData = (registryKey << 34) | funcSelector;

        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);

        // Then withdraw. 
        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            virtualAssetInteractionNonce,
            emptyAsset,
            virtualAssetInteractionNonce,
            emptyAsset,
            0,                      // _totalInputValue 
            INTERACTION_NONCE + 1,  // use next nonce to update mapping.
            auxData,
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 1, "Output value A is not 0");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets mapping is updated.
        (address storedCollection, uint256 storedTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(storedCollection, address(0x0), "Unexpected collection address");
        assertEq(storedTokenId, 0, "Unexpected tokenId");

        (storedCollection, storedTokenId) = bridge.nftAssets(INTERACTION_NONCE+1);
        assertEq(storedCollection, address(nftContract), "Unexpected collection address");
        assertEq(storedTokenId, TOKEN_ID, "Unexpected tokenId");
    }

    /*  
        function   |   selector
        --------------------------------------
        cancelAsk  |   uint8(3)
    */
 
    // Revert test cases.
    function testCancelAskInvalidInputAType() public {
        uint64 funcSelector = 3;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCancelAskInvalidOutputAType() public {
        uint64 funcSelector = 3;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be virtual type.
        bridge.convert(virtualAsset1, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCancelAskInvalidCollectionAddress() public {
        uint64 funcSelector = 3;
        // No NFTs in the bridge, so fetching collection address fails.
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    // Success test case.
    function testCancelAskSuccess() public {
        uint64 funcSelector = 3;
        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);

        // Then withdraw. 
        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            virtualAssetInteractionNonce,
            emptyAsset,
            virtualAssetInteractionNonce,
            emptyAsset,
            0,                      // _totalInputValue 
            INTERACTION_NONCE + 1,  // use next nonce to update mapping.
            funcSelector,
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 1, "Output value A is not 0");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets mapping is updated.
        (address storedCollection, uint256 storedTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(storedCollection, address(0x0), "Unexpected collection address");
        assertEq(storedTokenId, 0, "Unexpected tokenId");

        (storedCollection, storedTokenId) = bridge.nftAssets(INTERACTION_NONCE+1);
        assertEq(storedCollection, address(nftContract), "Unexpected collection address");
        assertEq(storedTokenId, TOKEN_ID, "Unexpected tokenId");
    }

    /*  
        function   |   selector
        --------------------------------------
        fillAsk    |   uint8(4)
    */

    // Revert test cases.
    function testFillAskInvalidInputAType() public {
        uint64 funcSelector = 4;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be eth type.
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testFillAskInvalidOutputAType() public {
        uint64 funcSelector = 4;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testFillAskCollectionAddressNotRegistered() public {
        uint64 funcSelector = 4;
        // This collection is out of range for the registry.
        uint64 collectionKey = uint64(registry.addressCount());
        uint64 auxData = (collectionKey << 4) | funcSelector;
        vm.expectRevert(ErrorLib.InvalidAuxData.selector);
        bridge.convert(ethAsset, emptyAsset, virtualAsset1, emptyAsset, 0, 0, auxData, address(0x0));
    }

    // Success test case.
    function testFillAskSuccess() public {
        uint64 funcSelector = 4;
        // The nftContract is registered with key=1.
        uint64 collectionKey = 1;
        // Construct auxData.
        uint64 auxData = (uint64(TOKEN_ID) << 34) | (collectionKey << 4) | funcSelector;

        uint256 inputValue = 2000;

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            ethAsset,
            emptyAsset,
            virtualAsset1,
            emptyAsset,
            inputValue,
            INTERACTION_NONCE,
            auxData,
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 1, "Output value A is not 1");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets mapping is updated.
        (address storedCollection, uint256 storedTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(storedCollection, address(nftContract), "Unexpected collection address");
        assertEq(storedTokenId, TOKEN_ID, "Unexpected tokenId");
    }

    /*  
        function         |   selector
        --------------------------------------
        createAuction    |   uint8(5)
    */

    // Revert test cases.
    function testCreateAuctionInvalidInputAType() public {
        uint64 funcSelector = 5;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateAuctionInvalidOutputAType() public {
        uint64 funcSelector = 5;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be virtual type.
        bridge.convert(virtualAsset1, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateAuctionNoNFTPresent() public {
        uint64 funcSelector = 5;
        // Virtual asset not associated with an NFT in the bridge.
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateAuctionAddressNotRegistered() public {
        uint64 funcSelector = 5;
        // Deposit an NFT. 
        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);

        // Address registry key out of range.
        uint64 registryKey = uint64(registry.addressCount());
        uint64 auxData = (registryKey << 32) | funcSelector;
        vm.expectRevert(ErrorLib.InvalidAuxData.selector);
        bridge.convert(virtualAssetInteractionNonce, emptyAsset, virtualAsset1, emptyAsset, 0, 0, auxData, address(0x0));
    }

    // Success test case.
    function testCreateAuctionSuccess() public {
        // Deposit an NFT. 
        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);
        uint64 funcSelector = 5;

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            virtualAssetInteractionNonce,
            emptyAsset,
            virtualAsset1,
            emptyAsset,
            0,
            INTERACTION_NONCE+1,
            funcSelector,
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 1, "Output value A is not 1");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets mapping is updated.
        (address emptyCollection, uint256 emptyTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(emptyCollection, address(0x0), "Unexpected collection address");
        assertEq(emptyTokenId, 0, "Unexpected tokenId");

        (address newCollection, uint256 newTokenId) = bridge.nftAssets(INTERACTION_NONCE+1);
        assertEq(newCollection, address(nftContract), "Unexpected collection address");
        assertEq(newTokenId, TOKEN_ID, "Unexpected tokenId");
    }

    /*  
        function         |   selector
        --------------------------------------
        cancelAuction    |   uint8(6)
    */

    // Revert test cases.
    function testCancelAuctionInvalidInputAType() public {
        uint64 funcSelector = 6;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCancelAuctionInvalidOutputAType() public {
        uint64 funcSelector = 6;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be virtual type.
        bridge.convert(virtualAsset1, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCancelAuctionNoNFTPresent() public {
        uint64 funcSelector = 6;
        // Virtual asset not associated with an NFT in the bridge.
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    // Success test case.
    function testCancelAuctionSuccess() public {
        // Deposit an NFT. 
        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);
        uint64 funcSelector = 6;

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            virtualAssetInteractionNonce,
            emptyAsset,
            virtualAsset1,
            emptyAsset,
            0,
            INTERACTION_NONCE+1,
            funcSelector,
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 1, "Output value A is not 1");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets is updated.
        (address emptyCollection, uint256 emptyTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(emptyCollection, address(0x0), "Unexpected collection address");
        assertEq(emptyTokenId, 0, "Unexpected tokenId");

        (address newCollection, uint256 newTokenId) = bridge.nftAssets(INTERACTION_NONCE+1);
        assertEq(newCollection, address(nftContract), "Unexpected collection address");
        assertEq(newTokenId, TOKEN_ID, "Unexpected tokenId");
    }

    /*  
        function         |   selector
        --------------------------------------
        settleAuction    |   uint8(7)
    */

    // Revert test cases.
    function testSettleAuctionInvalidInputAType() public {
        uint64 funcSelector = 7;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testSettleAuctionInvalidOutputAType() public {
        uint64 funcSelector = 7;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be eth type.
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testSettleAuctionNoNFTPresent() public {
        uint64 funcSelector = 7;
        // Virtual asset not associated with an NFT in the bridge.
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(virtualAsset1, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    // Success test case.
    function testSettleAuctionSuccess() public {
        // Deposit an NFT. 
        depositIntoBridge(INTERACTION_NONCE, TOKEN_ID);
        uint64 funcSelector = 7;

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            virtualAssetInteractionNonce,
            emptyAsset,
            ethAsset,
            emptyAsset,
            0,
            INTERACTION_NONCE,
            funcSelector,
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 0, "Output value A is not 0");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets is now empty.
        (address emptyCollection, uint256 emptyTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(emptyCollection, address(0x0), "Unexpected collection address");
        assertEq(emptyTokenId, 0, "Unexpected tokenId");
    }

    /*  
        function     |   selector
        --------------------------------------
        createBid    |   uint8(8)
    */

    // Revert test cases.
    function testCreateBidInvalidInputAType() public {
        uint64 funcSelector = 8;
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        // Input A needs to be eth type.
        bridge.convert(virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateBidInvalidOutputAType() public {
        uint64 funcSelector = 8;
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        // Output A needs to be virtual type.
        bridge.convert(ethAsset, emptyAsset, ethAsset, emptyAsset, 0, 0, funcSelector, address(0x0));
    }

    function testCreateBidCollectionAddressNotRegistered() public {
        uint64 funcSelector = 8;
        // This collection is out of range for the registry.
        uint64 collectionKey = uint64(registry.addressCount());
        uint64 auxData = (collectionKey << 4) | funcSelector;
        vm.expectRevert(ErrorLib.InvalidAuxData.selector);
        bridge.convert(ethAsset, emptyAsset, virtualAsset1, emptyAsset, 0, 0, auxData, address(0x0));
    }

    // Success test case.
    function testCreateBidSuccess() public {
        uint64 funcSelector = 8;
        // The nftContract is registered with key=1.
        uint64 collectionKey = 1;
        // Construct auxData.
        uint64 auxData = (uint64(TOKEN_ID) << 34) | (collectionKey << 4) | funcSelector;

        uint256 inputValue = 2000;

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            ethAsset,
            emptyAsset,
            virtualAsset1,
            emptyAsset,
            inputValue,
            INTERACTION_NONCE,
            auxData,
            address(0x0)
        );

        // Check outputs.
        assertEq(outputValueA, 1, "Output value A is not 1");
        assertEq(outputValueB, 0, "Output value B is not 0");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // Check that the internal nftAssets mapping is updated.
        (address storedCollection, uint256 storedTokenId) = bridge.nftAssets(INTERACTION_NONCE);
        assertEq(storedCollection, address(nftContract), "Unexpected collection address");
        assertEq(storedTokenId, TOKEN_ID, "Unexpected tokenId");
    }

    function depositIntoBridge(uint256 _virtualAssetId, uint256 _tokenId) internal {
        uint64 funcSelector = 0;

        // Deposit. 
        bridge.convert(
            ethAsset,
            emptyAsset,
            virtualAssetInteractionNonce,
            emptyAsset,
            0,                  // _totalInputValue 
            _virtualAssetId,    // _interactionNonce 
            funcSelector,       // auxData
            address(0x0)
        );

        // Call match and pull with tokenId.
        bridge.matchAndPull(_virtualAssetId, address(nftContract), _tokenId);
    }
}
