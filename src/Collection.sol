// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC1155Upgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155SupplyUpgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { Initializable } from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Pocket } from "./Pocket.sol";
import { Album} from "./Album.sol";
import { Prizes } from "./Prizes.sol";

contract Collection is 
    Initializable,
    ERC1155Upgradeable, 
    ERC1155SupplyUpgradeable 
{
    uint8[] public densityCurveFigus;   // later private // limits total amount of figus to 256
    uint8 public numberFigus;           // limited to 255

    address public factory;
    address public creator;

    Pocket public sobres;    
    Prizes public top;

    address _paymentToken;
    uint _albumPrice;
    uint _protocolAlbumPrice;

    event PackOpened(address indexed owner, uint id, uint[] ids);

    function initialize(
        address _creator,
        string memory uri, 
        address _sobres,
        address _top,
        uint8[] memory _densityCurveFigus
    ) initializer public {
        factory = msg.sender;
        numberFigus = uint8(_densityCurveFigus.length);
        creator = _creator;
        __ERC1155_init(uri);
        __ERC1155Supply_init();

        sobres = Pocket(_sobres);
        top = Prizes(_top);
        
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
        require(sobres.ownerOf(id) == msg.sender, "Not owner of sobre");
        sobres.burn(id);
        (uint amount, uint random) = sobres.getPackInformation(id);
        
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
