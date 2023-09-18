// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC1155Upgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155SupplyUpgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { Initializable } from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Pocket } from "./Pocket.sol";
import { Factory } from "./Factory.sol";
import { Album} from "./Album.sol";

contract Collection is 
    Initializable,
    ERC1155Upgradeable, 
    ERC1155SupplyUpgradeable 
{
    uint8[] densityCurveFigus;
    uint8 public numberFigus;           // limited to 255

    address public factory;
    address public creator;
    Pocket public pocket;    

    event PackOpened(address indexed owner, uint id, uint[] ids);

    function initialize(
        address _creator,
        string memory uri, 
        address _pocket,
        uint8[] memory _densityCurveFigus
    ) initializer public {
        factory = msg.sender;
        numberFigus = uint8(_densityCurveFigus.length);
        creator = _creator;
        __ERC1155_init(uri);
        __ERC1155Supply_init();

        pocket = Pocket(_pocket);
        
        // populate densityCurveFigus        
        densityCurveFigus.push(0);                      // discarded slot (because of normalization of VRF)
        for (uint i = 0; i < numberFigus; i++) {
            uint8 repetition = _densityCurveFigus[i];
            for (uint j=0; j < repetition; j++) {
                densityCurveFigus.push(uint8(i));
            }
        }
    }

    function openPack(uint id) public {
        require(pocket.ownerOf(id) == msg.sender, "Not owner of pack");
        pocket.burn(id);
        (uint amount, uint random) = pocket.getPackInformation(id);
        
        uint256[] memory ids = new uint256[](amount);
        uint256[] memory amounts = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            // another way? like checking if id exists and bump index in amounts?
            uint index = (uint256(keccak256(abi.encode(random, i))) % (densityCurveFigus.length - 1)) + 1;
            ids[i] = densityCurveFigus[index];
            amounts[i] = 1;
        }
        _mintBatch(msg.sender, ids, amounts, "");
        emit PackOpened(msg.sender, id, ids);
    }
    
    // OVERRIDES
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

}
