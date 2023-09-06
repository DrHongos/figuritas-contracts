// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { ERC1155 } from "../lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC1155Supply } from "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { SobresFactory } from "./SobresFactory.sol";
import { AlbumFiguritas } from "./AlbumFiguritas.sol";
import { CollectorsTop } from "./CollectorsIncentive.sol";

contract FiguritasCollection is ERC1155, ERC1155Supply, Ownable, ReentrancyGuard {
    uint8[] public densityCurveFigus;   // later private // limits total amount of figus to 256
    uint8 public numberFigus;           // limited to 255

    SobresFactory public sobres;    
    CollectorsTop public top;

    address _paymentToken;
    uint _albumPrice;

    mapping(address => address) public albums;

    event AlbumPriceConfig(address indexed paymentToken, uint value);
    event AlbumCreated(address indexed owner, address indexed album);
    event SobreOpened(address indexed owner, uint id, uint[] ids);

    constructor(
        string memory uri, 
        uint64 _subscriptionId,
        uint8[] memory _densityCurveFigus
    )
    ERC1155(uri)
    {
        sobres = new SobresFactory(
            "sobresFactory", 
            "SOBRE", 
            msg.sender,             // admin of sobresFactory
            _subscriptionId);

        numberFigus = uint8(_densityCurveFigus.length);

        // populate densityCurveFigus        
        densityCurveFigus.push(0);                      // discarded slot (because of normalization of VRF)
        for (uint i = 0; i < numberFigus; i++) {
            // find a better way
            uint8 repetition = _densityCurveFigus[i];
            for (uint j=0; j < repetition; j++) {
                densityCurveFigus.push(uint8(i));
            }
        }
    }

    function setAlbumPrice(address paymentToken, uint price) public onlyOwner() {
//        require(paymentToken == address(0), "Price already set");
        _paymentToken = paymentToken;
        _albumPrice = price;  
        emit AlbumPriceConfig(paymentToken, price);
    }

    function getAlbum() public {
        require(albums[msg.sender] == address(0), "Already owner of an album");
        if (_albumPrice > 0) {
            IERC20(_paymentToken).transferFrom(msg.sender, address(this), _albumPrice);
        }
        AlbumFiguritas albumCreated = new AlbumFiguritas(msg.sender, address(this));
        address albumCreatedAddress = address(albumCreated);
        albums[msg.sender] = albumCreatedAddress;
        emit AlbumCreated(msg.sender, albumCreatedAddress);
    }

    function openEnvelopes(uint id) public nonReentrant() {
        (uint amount, uint random) = sobres.getSobreInformation(id);
        
        uint256[] memory ids = new uint256[](amount);
        uint256[] memory amounts = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            // another way? like checking if id exists and bump index in amounts?
            uint index = (uint256(keccak256(abi.encode(random, i))) % (densityCurveFigus.length - 1)) + 1;     // look a better way
            ids[i] = densityCurveFigus[index];
            amounts[i] = 1;
            }
        sobres.burn(id);
        _mintBatch(msg.sender, ids, amounts, "");
        emit SobreOpened(msg.sender, id, ids);
    }

    // OVERRIDES
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

}
