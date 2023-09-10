// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Collection} from "../src/Collection.sol";
import { ERC20PresetMinterPauser } from "../lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import { Album } from "../src/Album.sol";
import { Prizes } from "../src/Prizes.sol";
import { Pocket } from "../src/Pocket.sol";
import { Factory } from "../src/Factory.sol";
import { TradingPit } from "../src/TradingPit.sol";

/* 
    IMPORTANT
    currently this is not testing important stuff, only a reference of UX
    - add tests, security, integration, etc
    
    - test different tokens
*/

contract FiguritasTest is Test {
    Collection public collection;
    Pocket public sobres;
    Prizes public top;
    Factory public factory;
    ERC20PresetMinterPauser public paymentToken;
    ERC20PresetMinterPauser public paymentToken2;
    TradingPit public tradingPit;
    Album public albumContract;

    string public uri = "fake_uri/";

    address public creator;
    address public admin;
    address public alice;
    address public bob;

    address public collectionTemplate;
    address public pocketTemplate;
    address public prizesTemplate;
    address public albumTemplate;

    uint public pricePerUnit = 1 * 10 ** 17;
    uint public fee = 500; // 5 %
    uint64 public subscriptionId = 4963;

    function setUp() public {
        admin = address(69);
        creator = address(666);
        alice = address(1);
        bob = address(2);

        paymentToken = new ERC20PresetMinterPauser("Payment token", "PTOK");        
        paymentToken2 = new ERC20PresetMinterPauser("Another Payment token", "APTOK");        
        paymentToken.mint(alice, 1*10**20);
        paymentToken.mint(bob, 1*10**20);
        paymentToken2.mint(alice, 1*10**20);
        paymentToken2.mint(bob, 1*10**20);

        paymentToken.mint(creator, 20*10**18);
        // launch factory (on admin's name)
        vm.startPrank(admin);
        
        collection = new Collection();
        Pocket pocket = new Pocket();
        top = new Prizes();
        tradingPit = new TradingPit();
        albumContract = new Album();

        factory = new Factory();
        factory.setCollectionTemplate(address(collection));
        factory.setPocketTemplate(address(pocket));
        factory.setAlbumTemplate(address(albumContract));
        factory.setPrizesTemplate(address(top));
        factory.setFee(fee);
        factory.setAllowedToken(address(paymentToken), true);
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
            address(paymentToken),
            2*10**18,      // albumPrice
            uri,
            densityCurve
        );

        collection = Collection(collectionAddress);
        sobres = collection.sobres();
        top = collection.top();
        vm.stopPrank();
    }
    function getRepeatedAddress(address to, uint amo) public pure returns(address[] memory) {
        address[] memory res = new address[](amo);
        for (uint i = 0; i < amo; i++) {
            res[i] = to;
        }
        return res;
    }

    function configSale() public {
        vm.startPrank(creator);
        sobres.configPack(3, 1*10**18, address(paymentToken),type(uint256).max);
        //collection.setAlbumPrice(address(paymentToken), 2*10**18);
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

    function testCreation() public {
        configCollection();
        uint8 testRandomSelect = collection.densityCurveFigus(4);        
        uint8 testLast = collection.densityCurveFigus(31); 
        assertEq(testRandomSelect, 1);
        assertEq(testLast, 5);
        assertEq(collection.uri(0), uri);
        
//        assertEq(address(collection.paymentsToken()), address(paymentToken));
    }

    function testPocket() public {
        configCollection();
        configSale();
        vm.startPrank(alice);
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyPack(alice, 0, 10, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openPack(0);
        vm.expectRevert();
        collection.openPack(0);
        vm.stopPrank();
        vm.expectRevert();
        vm.prank(bob);
        collection.openPack(1);
    }

    function testAlbum() public {
        configCollection();
        configSale();
        vm.startPrank(alice);
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyPack(alice, 0, 10, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openPack(0);
        // according to tests => ids = [1, 2, 3]
        uint[] memory ids = new uint[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        paymentToken.approve(address(factory), 2*10**18);
        factory.getAlbum(address(collection));
        Album album = Album(factory.albums(address(collection), alice));
        collection.setApprovalForAll(address(album), true);
        album.stickFigus(ids);
        vm.stopPrank();
        vm.prank(admin);
        factory.protocolWithdraw(admin, address(collection));
        assertGt(paymentToken.balanceOf(admin), 0);
    }

    function testTradingPit() public {
        configCollection();
        configSale();
        vm.startPrank(alice);
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyPack(alice, 0, 1, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openPack(0);
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
        sobres.buyPack(bob, 0, 1, 345);
        sobres.setApprovalForAll(address(collection), true);
        collection.openPack(1);
        // IDS: 3,4,4 <<
        collection.setApprovalForAll(address(tradingPit), true);
        // take the offer
        tradingPit.takeOffer(offerId);
        vm.stopPrank();
        assertEq(collection.balanceOf(alice, 4), 1);
        assertEq(collection.balanceOf(bob, 1), 1);
    }

    function testPrize() public {
        // make someone win! 
        configCollection();
        configSale();
        configIncentives();
    
        vm.startPrank(alice);
        paymentToken.approve(address(factory), 2*10**18);
        factory.getAlbum(address(collection));
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyPack(alice, 0, 2, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openPack(0);
        collection.openPack(1);
// lucky to find it all!

        uint[] memory allIds = new uint[](6);
        allIds[0] = 0;
        allIds[1] = 1;
        allIds[2] = 2;
        allIds[3] = 3;
        allIds[4] = 4;
        allIds[5] = 5;
        address[] memory rep = getRepeatedAddress(alice, 6);
        collection.balanceOfBatch(rep, allIds);

        Album album = Album(factory.albums(address(collection), alice));
        collection.setApprovalForAll(address(album), true);
        album.stickFigus(allIds);
        // claim!
        top.claim();        
        vm.stopPrank();
       
        vm.startPrank(bob);
        paymentToken.approve(address(factory), 2*10**18);
        factory.getAlbum(address(collection));
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyPack(bob, 0, 2, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openPack(2);
        collection.openPack(3);
    
        Album albumBob = Album(factory.albums(address(collection), bob));
        collection.setApprovalForAll(address(albumBob), true);
        albumBob.stickFigus(allIds);
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
