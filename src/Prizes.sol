// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import { Initializable } from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { Collection } from "./Collection.sol";
import { Album } from "./Album.sol";

/* 
    Make it more open, like an abstract contract with the functions claim() and neccessary storage to build upon

    Make a fallback(?) fn in order to increase the prizes with external money
    can be used to create prizes from figus sells

    Put prices in proportion and cancel out the winners (?)

*/

contract Prizes is Initializable, OwnableUpgradeable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Collection _collection;
    address[] public top;

    struct Prize {                      // try to re-use for multiple prizes and types
        address paymentToken;           // could be any digital asset address
        uint amount;                    // could be amount or ID (ie: ERC721)
    }
    mapping(uint => Prize) public prizes;

    Counters.Counter private _currentPosition;

    event AlbumCompleted(address indexed collector, address indexed album, uint position);
    event IncentiveAdded(address indexed paymentToken, uint[] positions, uint[] amounts);

    function initialize() initializer() public {
        _collection = Collection(msg.sender);
    } 

    function addIncentiveERC20(uint[] calldata positions, address paymentToken, uint[] calldata amounts) public {
        uint totalAmount;
        require(positions.length == amounts.length, "Error on inputs");
        for (uint i = 0; i < positions.length; i++) {
            require(prizes[i].paymentToken == address(0), "Immutable!?");

            prizes[i] = Prize (
                paymentToken,
                amounts[i]
            );
            totalAmount += amounts[i];
        }
        IERC20(paymentToken).transferFrom(msg.sender, address(this), totalAmount);
        emit IncentiveAdded(paymentToken, positions, amounts);
    }
    // function addIncentiveERC721(uint[] positions, address[] paymentTokens, uint[] amounts) public {};
    // function addIncentiveERC1155(uint[] positions, address[] paymentTokens, uint[] amounts) public {};

    function claim() public nonReentrant() {
        address albumAddress = _collection.albums(msg.sender);
        // checks album is completed
        require(Album(albumAddress).fullAlbumProof() == true, "Album is not completed");
        // stores the album in top
        top.push(msg.sender);
        // launches incentives
        uint currentPosition = _currentPosition._value;
        if (prizes[currentPosition].amount > 0) {
            IERC20(prizes[currentPosition ].paymentToken).transfer(msg.sender, prizes[currentPosition].amount);
        }
        _currentPosition.increment();    
        emit AlbumCompleted(msg.sender, albumAddress, currentPosition);
    }        

}
