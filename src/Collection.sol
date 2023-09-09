// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { OwnableUpgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { ERC1155Upgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155SupplyUpgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { Initializable } from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Pocket } from "./Pocket.sol";
import { Album} from "./Album.sol";
import { Prizes } from "./Prizes.sol";

contract Collection is 
    Initializable,
    ERC1155Upgradeable, 
    ERC1155SupplyUpgradeable, 
    OwnableUpgradeable, 
    ReentrancyGuard {
    uint8[] public densityCurveFigus;   // later private // limits total amount of figus to 256
    uint8 public numberFigus;           // limited to 255

    address _factory;
    address _creator;
    uint _creatorBalance;
    uint _protocolBalance;
    uint public fee;

    Pocket public sobres;    
    Prizes public top;

    address _paymentToken;
    uint _albumPrice;
    uint _protocolAlbumPrice;

    mapping(address => address) public albums;

    event AlbumPriceConfig(address indexed paymentToken, uint value);
    event AlbumCreated(address indexed owner, address indexed album);
    event SobreOpened(address indexed owner, uint id, uint[] ids);

    function initialize(
        address creator,
        string memory uri, 
        uint _fee,
        address _sobres,
        address _top,
        uint8[] memory _densityCurveFigus
    ) initializer public {
        _factory = msg.sender;
        numberFigus = uint8(_densityCurveFigus.length);
        fee = _fee;
        _creator = creator;
        __ERC1155_init(uri);
        __Ownable_init();
        __ERC1155Supply_init();

        sobres = Pocket(_sobres);
        top = Prizes(_top);
        
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

    function setAlbumPrice(address paymentToken, uint price) public {
        require(msg.sender == _creator, "Only creator can set");
        _paymentToken = paymentToken;
        _albumPrice = price;
        _protocolAlbumPrice = fee * price / 10000;
        emit AlbumPriceConfig(paymentToken, price);
    }

    function getAlbum() public {
        require(albums[msg.sender] == address(0), "Already owner of an album");
        if (_albumPrice > 0) {
            IERC20(_paymentToken).transferFrom(msg.sender, address(this), _albumPrice);
            _creatorBalance += _albumPrice - _protocolAlbumPrice;
            _protocolBalance += _protocolAlbumPrice;
        }
        Album albumCreated = new Album(msg.sender, address(this));
        address albumCreatedAddress = address(albumCreated);
        albums[msg.sender] = albumCreatedAddress;
        emit AlbumCreated(msg.sender, albumCreatedAddress);
    }

    function openEnvelopes(uint id) public nonReentrant() {
        require(sobres.ownerOf(id) == msg.sender, "Not owner of sobre");
        (uint amount, uint random) = sobres.getSobreInformation(id);
        
        uint256[] memory ids = new uint256[](amount);
        uint256[] memory amounts = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            // another way? like checking if id exists and bump index in amounts?
            uint index = (uint256(keccak256(abi.encode(random, i))) % (densityCurveFigus.length - 1)) + 1;
            ids[i] = densityCurveFigus[index];
            amounts[i] = 1;
            }
        sobres.burn(id);
        _mintBatch(msg.sender, ids, amounts, "");
        emit SobreOpened(msg.sender, id, ids);
    }

    function protocolWithdraw(address beneficiary) public onlyOwner() {
        //require(msg.sender == factory, "Only factory can call");
        IERC20(_paymentToken).transfer(beneficiary, _protocolBalance);
        _protocolBalance = 0;
    }

    function creatorWithdraw(address beneficiary) public {
        require(msg.sender == _creator, "Only creator can call");
        IERC20(_paymentToken).transfer(beneficiary, _creatorBalance);
        _creatorBalance = 0;
    }

    // OVERRIDES
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

}
