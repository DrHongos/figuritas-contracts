// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC1155HolderUpgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import { Initializable } from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Collection } from "./Collection.sol";

contract Album is Initializable, ERC1155HolderUpgradeable {
    Collection _collection;
    bool public completed;
    address public collector;

    event FiguSticked(uint[] id);
    event FiguUnsticked(uint[] id);

    modifier onlyOwner() {
        require(msg.sender == collector, "Only owner of album");
        _;
    }
    
    function initialize(address _collector, address collection) initializer() public {
        collector = _collector;
        _collection = Collection(collection);
    } 

    function stickFigus(uint[] calldata ids) public onlyOwner() {
        uint length = ids.length;
        address[] memory addressAr = new address[](length);
        for (uint i = 0; i < length; i++) {
            addressAr[i] = address(this);
        }
        uint[] memory balances = _collection.balanceOfBatch(addressAr, ids);
        uint[] memory amounts = new uint[](length);

        for (uint j = 0; j < length; j++) {
            amounts[j] = balances[j] == 0 ? 1 : 0;
        }        
        _collection.safeBatchTransferFrom(
            msg.sender, 
            address(this), 
            ids, 
            amounts, 
            ""
        );
        
        // maybe move this to onERC1155BarchReceived()
        if (fullAlbumProof() == true) {
            completed = true;
        }
        
        emit FiguSticked(ids);
    }        

    function unstickFigus(address to, uint[] memory ids) public onlyOwner() {
        require(completed == false, "Album completed!");
        uint length = ids.length;
        uint256[] memory amounts = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            amounts[i] = 1;
        }
        _collection.safeBatchTransferFrom(
            address(this), to, ids, amounts, ""
        );
        emit FiguUnsticked(ids);
    }

    function fullAlbumProof() public view returns (bool) {
        uint figusLength = _collection.numberFigus();
        for (uint i = 0; i < figusLength; i++) {
            if (_collection.balanceOf(address(this), i) == 0) {
                return false;
            }
        }
        return true;     
    }
}
