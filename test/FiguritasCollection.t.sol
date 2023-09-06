// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FiguritasCollection} from "../src/FiguritasCollection.sol";
import { ERC20PresetMinterPauser } from "../lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import { AlbumFiguritas } from "../src/AlbumFiguritas.sol";
import { CollectorsTop } from "../src/CollectorsIncentive.sol";
import { SobresFactory } from "../src/SobresFactory.sol";

contract FiguritasCollectionTest is Test {
    FiguritasCollection public collection;
    SobresFactory public sobres;
    CollectorsTop public top;

    ERC20PresetMinterPauser public paymentToken;

    string uri = "fake_uri/";

    address alice;
    address bob;

    uint pricePerUnit = 1 * 10 ** 17;

    function setUp() public {
        alice = address(1);
        bob = address(2);

        paymentToken = new ERC20PresetMinterPauser("Payment token", "PTOK");        
        paymentToken.mint(alice, 1*10**20);
        paymentToken.mint(bob, 1*10**20);

        uint8[] memory densityCurve = new uint8[](6);
        densityCurve[0] = 3;
        densityCurve[1] = 4;
        densityCurve[2] = 5;
        densityCurve[3] = 8;        
        densityCurve[4] = 10;        
        densityCurve[5] = 1;

        collection = new FiguritasCollection(
            uri, 
//            address(paymentToken), 
//            pricePerUnit,
            4963,           // VRF subscription
            densityCurve
        );
        sobres = collection.sobres();
        top = collection.top();
    }

    function configSale() public {
        sobres.configSobre(3, 1*10**18, address(paymentToken),type(uint256).max);
        collection.setAlbumPrice(address(paymentToken), 2*10**18);
    }

    function test_creation() public {
        uint8 test_random_select = collection.densityCurveFigus(4);        
        uint8 test_last = collection.densityCurveFigus(31); 
        assertEq(test_random_select, 1);
        assertEq(test_last, 5);
        assertEq(collection.uri(0), uri);
//        assertEq(address(collection.paymentsToken()), address(paymentToken));
    }

//    function test_config() public {}

    function test_my_first_envelope() public {
        configSale();
        vm.startPrank(alice);
        paymentToken.approve(address(sobres), 10*10**18); 
        sobres.buyFigus(alice, 0, 10, 666);
        sobres.setApprovalForAll(address(collection), true);
        collection.openEnvelopes(0);
    }

    function test_my_first_album() public {
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
            
    }

    // TO BE CONTINUED

/* 
    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
 */
}
