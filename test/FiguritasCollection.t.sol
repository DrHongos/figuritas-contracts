// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FiguritasCollection} from "../src/FiguritasCollection.sol";
import { ERC20PresetMinterPauser } from "../lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import { AlbumFiguritas } from "../src/AlbumFiguritas.sol";
import { CollectorsTop } from "../src/CollectorsIncentive.sol";
import { SobresFactory } from "../src/SobresFactory.sol";
import { FigusCreator } from "../src/FigusCreator.sol";
import { TradingPit } from "../src/TradingPit.sol";

/* 
    IMPORTANT
    currently this is not testing important stuff, only a reference of UX
    - add tests, security, integration, etc
    

*/

contract FiguritasCollectionTest is Test {
    FiguritasCollection public collection;
    SobresFactory public sobres;
    CollectorsTop public top;
    FigusCreator public factory;
    ERC20PresetMinterPauser public paymentToken;
    TradingPit public tradingPit;

    string uri = "fake_uri/";

    address creator;
    address admin;
    address alice;
    address bob;

    uint pricePerUnit = 1 * 10 ** 17;
    uint fee = 500; // 5 %
    uint64 subscriptionId = 4963;

    function setUp() public {
        admin = address(69);
        creator = address(666);
        alice = address(1);
        bob = address(2);

        paymentToken = new ERC20PresetMinterPauser("Payment token", "PTOK");        
        paymentToken.mint(alice, 1*10**20);
        paymentToken.mint(bob, 1*10**20);
        paymentToken.mint(creator, 20*10**18);
        // launch factory (on admin's name)
        vm.startPrank(admin);
        factory = new FigusCreator();
        tradingPit = new TradingPit();

        factory.setFee(fee);
        factory.setSubscriptionId(subscriptionId);
        
        vm.stopPrank();
    }

    function configCollection() public {
        vm.startPrank(creator);
        // move collection creation to tests
        uint8[] memory densityCurve = new uint8[](6);
        densityCurve[0] = 3;
        densityCurve[1] = 4;
        densityCurve[2] = 5;
        densityCurve[3] = 8;        
        densityCurve[4] = 10;        
        densityCurve[5] = 1;

        address collectionAddress = factory.createCollection(
            uri,
            densityCurve
        );

        collection = FiguritasCollection(collectionAddress);
        sobres = collection.sobres();
        top = collection.top();
        vm.stopPrank();
    }
    function get_repeated_address(address to, uint amo) public pure returns(address[] memory) {
        address[] memory res = new address[](amo);
        for (uint i = 0; i < amo; i++) {
            res[i] = to;
        }
        return res;
    }

    function configSale() public {
        vm.startPrank(creator);
        sobres.configSobre(3, 1*10**18, address(paymentToken),type(uint256).max);
        collection.setAlbumPrice(address(paymentToken), 2*10**18);
        vm.stopPrank();
    }

    function configIncentives() public {
        vm.startPrank(creator);
        uint[] memory positions = new uint[](3);
        uint[] memory amounts = new uint[](3);       
        positions[0] = 0;
        positions[1] = 1;
        positions[2] = 2;

        amounts[0] = 10*10**18;
        amounts[1] = 5*10**18;
        amounts[2] = 2*10**18;

        paymentToken.approve(address(top), 17*10**18);

        top.addIncentiveERC20(
            positions,
            address(paymentToken),
            amounts
        );
        vm.stopPrank();
    }

    function test_creation() public {
        configCollection();
        uint8 test_random_select = collection.densityCurveFigus(4);        
        uint8 test_last = collection.densityCurveFigus(31); 
        assertEq(test_random_select, 1);
        assertEq(test_last, 5);
        assertEq(collection.uri(0), uri);
//        assertEq(address(collection.paymentsToken()), address(paymentToken));
    }

    function test_my_first_envelope() public {
        configCollection();
        configSale();
        vm.startPrank(alice);
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyFigus(alice, 0, 10, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openEnvelopes(0);
    }

    function test_my_first_album() public {
        configCollection();
        configSale();
        vm.startPrank(alice);
        paymentToken.approve(address(collection), 2*10**18);
        collection.getAlbum();
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyFigus(alice, 0, 10, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openEnvelopes(0);
        // according to tests => ids = [1, 2, 3]
        uint[] memory ids = new uint[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        AlbumFiguritas album = AlbumFiguritas(collection.albums(alice));
        collection.setApprovalForAll(address(album), true);
        album.stickFigus(ids);
        vm.stopPrank();
        vm.prank(admin);
        factory.withdrawProtocol(admin, address(collection));
        assertGt(paymentToken.balanceOf(admin), 0);
    }

    function test_tradingPit_first() public {
        configCollection();
        configSale();
        vm.startPrank(alice);
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyFigus(alice, 0, 1, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openEnvelopes(0);
        // IDS: 1,2, 3 
        // create offer
        uint[] memory idsOffered = new uint[](2);
        idsOffered[0] = 1;
        idsOffered[1] = 2;
        uint[] memory idsRequired = new uint[](2);
        idsRequired[0] = 4;
        idsRequired[1] = 3;
        collection.setApprovalForAll(address(tradingPit), true);
        TradingPit.Item memory offered = TradingPit.Item (
            TradingPit.TokenType.ERC1155,
            address(collection),
            idsOffered        // id
        );

        TradingPit.Item memory required = TradingPit.Item (
            TradingPit.TokenType.ERC1155,
            address(collection),
            idsRequired                           // id
        );
        uint offerId = tradingPit.createOffer(offered, required);
        vm.stopPrank();
        
        vm.startPrank(bob);
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyFigus(bob, 0, 1, 345);
        sobres.setApprovalForAll(address(collection), true);
        collection.openEnvelopes(1);
        // IDS: 3,4,4 <<
        collection.setApprovalForAll(address(tradingPit), true);
        // take the offer
        tradingPit.takeOffer(offerId);
        vm.stopPrank();
        assertEq(collection.balanceOf(alice, 4), 1);
        assertEq(collection.balanceOf(bob, 1), 1);
    }

    function test_my_first_prize() public {
        // make someone win! 
        configCollection();
        configSale();
        configIncentives();
    
        vm.startPrank(alice);
        paymentToken.approve(address(collection), 2*10**18);
        collection.getAlbum();
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyFigus(alice, 0, 2, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openEnvelopes(0);
        collection.openEnvelopes(1);
// lucky to find it all!

        uint[] memory all_ids = new uint[](6);
        all_ids[0] = 0;
        all_ids[1] = 1;
        all_ids[2] = 2;
        all_ids[3] = 3;
        all_ids[4] = 4;
        all_ids[5] = 5;
        address[] memory rep = get_repeated_address(alice, 6);
        collection.balanceOfBatch(rep, all_ids);

        AlbumFiguritas album = AlbumFiguritas(collection.albums(alice));
        collection.setApprovalForAll(address(album), true);
        album.stickFigus(all_ids);
        // claim!
        top.claim();        
        vm.stopPrank();
       
        vm.startPrank(bob);
        paymentToken.approve(address(collection), 2*10**18);
        collection.getAlbum();
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyFigus(bob, 0, 2, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openEnvelopes(2);
        collection.openEnvelopes(3);
    
        AlbumFiguritas albumBob = AlbumFiguritas(collection.albums(bob));
        collection.setApprovalForAll(address(albumBob), true);
        albumBob.stickFigus(all_ids);
        top.claim();        
        vm.stopPrank();
    }

    // TO BE CONTINUED

/* 
    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
 */
}
