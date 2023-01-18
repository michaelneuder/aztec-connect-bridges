// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {BridgeTestBase} from "./../../aztec/base/BridgeTestBase.sol";
import {AztecTypes} from "rollup-encoder/libraries/AztecTypes.sol";

// Example-specific imports
import {ZoraBridge} from "../../../bridges/zora/ZoraBridge.sol";
import {ZoraAsk} from "../../../bridges/zora/ZoraBridge.sol";
import {ZoraAuction} from "../../../bridges/zora/ZoraBridge.sol";
import {ZoraOffer} from "../../../bridges/zora/ZoraBridge.sol";
import {AddressRegistry} from "../../../bridges/registry/AddressRegistry.sol";
import {ErrorLib} from "../../../bridges/base/ErrorLib.sol";
import {ERC721PresetMinterPauserAutoId} from
    "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

/**
 * @notice The purpose of this test is to test the bridge in an environment that is as close to the final deployment
 *         as possible without spinning up all the rollup infrastructure (sequencer, proof generator etc.).
 */
contract ZoraBridgeE2ETest is BridgeTestBase {
    ZoraBridge internal bridge;
    AddressRegistry private registry;
    ZoraAsk private ask;
    ZoraAuction private auction;
    ZoraOffer private offer;
    ERC721PresetMinterPauserAutoId private nftContract;

    // To store the id of the bridge after being added
    uint256 private id;
    // To store the interactionNonce/virtual token id during fill ask.
    uint256 private interactionNonce;
    uint256 private registryBridgeId;
    address private constant REGISTER_ADDRESS = address(0xdeadbeef);
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    uint64  private constant TOKEN_ID = 1;
    
    // Test AztecAssets.
    AztecTypes.AztecAsset private ethAsset;
    AztecTypes.AztecAsset private erc20OutputAsset =
        AztecTypes.AztecAsset({id: 1, erc20Address: DAI, assetType: AztecTypes.AztecAssetType.ERC20});
    AztecTypes.AztecAsset private virtualAsset1 =
        AztecTypes.AztecAsset({id: 1, erc20Address: address(0), assetType: AztecTypes.AztecAssetType.VIRTUAL});

    // TODO(mikeneuder): add events.

    function setUp() public {
        // Initialize all contracts.
        registry = new AddressRegistry(address(ROLLUP_PROCESSOR));
        ask = new ZoraAsk();
        auction = new ZoraAuction();
        offer = new ZoraOffer();
        bridge = new ZoraBridge(address(ROLLUP_PROCESSOR), address(ask), address(auction), address(offer), address(registry));

        // Create test NFT contract and mint 2 ERC-721 tokens (tokenIds 0 & 1).
        nftContract = new ERC721PresetMinterPauserAutoId("test", "NFT", "");
        // The owner is the bridge. Mint 2 so that we have a non-zero token id.
        nftContract.mint(address(bridge)); // tokenID = 0
        nftContract.mint(address(bridge)); // tokenID = 1

        ethAsset = ROLLUP_ENCODER.getRealAztecAsset(address(0));

        vm.label(address(registry), "AddressRegistry Bridge");
        vm.label(address(bridge), "Zora Bridge");

        // Impersonate the multi-sig to add a new bridge.
        vm.startPrank(MULTI_SIG);

        // WARNING: If you set this value too low the interaction will fail for seemingly no reason!
        // OTOH if you set it too high bridge users will pay too much.
        ROLLUP_PROCESSOR.setSupportedBridge(address(registry), 120000);
        ROLLUP_PROCESSOR.setSupportedBridge(address(bridge), 120000);

        vm.stopPrank();

        // Fetch the id of the bridges.
        registryBridgeId = ROLLUP_PROCESSOR.getSupportedBridgesLength() - 1;
        id = ROLLUP_PROCESSOR.getSupportedBridgesLength();

        // Get virtual assets to use for registry.
        ROLLUP_ENCODER.defiInteractionL2(
            registryBridgeId, ethAsset, emptyAsset, virtualAsset1, emptyAsset, 0, 1
        );
        ROLLUP_ENCODER.processRollupAndGetBridgeResult();

        // Register 0xdeadbeef, which we use as a fake customer address.
        uint160 inputAmount = uint160(REGISTER_ADDRESS);
        ROLLUP_ENCODER.defiInteractionL2(
            registryBridgeId, virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, inputAmount
        );
        // 0 -> address(0xdeadbeef).
        ROLLUP_ENCODER.processRollupAndGetBridgeResult();

        // Register the nftContract address. This is the collection of our fake
        // NFTs.
        inputAmount = uint160(address(nftContract));
        ROLLUP_ENCODER.defiInteractionL2(
            registryBridgeId, virtualAsset1, emptyAsset, virtualAsset1, emptyAsset, 0, inputAmount
        );
        // 1 -> address(nftContract).
        ROLLUP_ENCODER.processRollupAndGetBridgeResult();
    }

    // Success test case -- fillAsk.
    function testFillAsk() public {
        uint64 funcSelector = 4;
        // The nftContract is registered with key=1.
        uint64 collectionKey = 1;
        uint64 auxData = (TOKEN_ID << 34) | (collectionKey << 4) | funcSelector;

        // Get the current interaction nonce. This is the id of the virtual
        // token that is created during fillAsk.
        interactionNonce = ROLLUP_ENCODER.getNextNonce();
        
        // Fill the ask.
        ROLLUP_ENCODER.defiInteractionL2(
            id, ethAsset, emptyAsset, virtualAsset1, emptyAsset, auxData, 1
        );

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = ROLLUP_ENCODER.processRollupAndGetBridgeResult();

        assertEq(outputValueA, 1, "Output value A doesn't equal 1.");
        assertEq(outputValueB, 0, "Output value B is not 0.");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode.");

        // TODO(mikeneuder) expect an emit here
        (address returnedCollection, uint256 returnedId) = bridge.nftAssets(interactionNonce);
        assertEq(returnedCollection, address(nftContract), "Unexpected collection address.");
        assertEq(returnedId, TOKEN_ID, "Unexpected tokenId.");
    }

    function testWithdraw() public {
        // Successful fillAsk.
        testFillAsk();

        uint64 funcSelector = 1;
        // The output address is registered with key=0.
        uint64 registryKey = 0;
        // Construct auxData.
        uint64 auxData = (registryKey << 4) | funcSelector;

        AztecTypes.AztecAsset memory virtualAssetInteractionNonce = AztecTypes.AztecAsset({
            id: interactionNonce, 
            erc20Address: address(0), 
            assetType: AztecTypes.AztecAssetType.VIRTUAL
        });

        // TODO(mikeneuder) expect an emit here
        // Then withdraw.
        ROLLUP_ENCODER.defiInteractionL2(
            id, virtualAssetInteractionNonce, emptyAsset, ethAsset, emptyAsset, auxData, 1
        );
        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = ROLLUP_ENCODER.processRollupAndGetBridgeResult();
        address owner = nftContract.ownerOf(TOKEN_ID);
        assertEq(REGISTER_ADDRESS, owner, "Registered address is not the owner.");
        assertEq(outputValueA, 0, "Output value A is not 0.");
        assertEq(outputValueB, 0, "Output value B is not 0.");
        assertTrue(!isAsync, "Bridge is incorrectly in an async mode.");

        (address returnedCollection, uint256 returnedID) = bridge.nftAssets(interactionNonce);
        assertEq(returnedCollection, address(0), "collection address is not 0");
        assertEq(returnedID, 0, "token id is not 0");
    }
}