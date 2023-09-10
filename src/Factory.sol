// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import { AccessControl } from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Collection } from "./Collection.sol";
import { Pocket } from "./Pocket.sol";
import { Prizes } from "./Prizes.sol";
import { Album} from "./Album.sol";
/* 
WARNING 
Highly experimental and quickly done

*/

contract Factory is AccessControl {
    using Counters for Counters.Counter;
    bytes32 public constant ADMIN = keccak256("ADMIN");

    uint public fee;
    uint64 _subscriptionId;

    mapping(address => bool) public allowedTokens;
    mapping(address => address) public paymentToken;

    address public collectionTemplate;
    address public pocketTemplate;
    address public prizesTemplate; // this is going to be probably multiple (mapping)
    address public albumTemplate;

    mapping(address => uint) public creatorBalance;
    mapping(address => uint) _protocolBalance;
    
    Counters.Counter public index;
    mapping(uint => address) public collections;
    mapping(address => uint) public albumPrice;
    mapping(address => mapping(address => address)) public albums;

    event NewCollection(uint index, address creator, address paymentToken, address collection, address prizes, address packs);
    event AlbumCreated(address indexed owner, address indexed album);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);
    }

    function setFee(uint _fee) public onlyRole(ADMIN) {
        // make it over 10000
        fee = _fee;
    }

    function setSubscriptionId(uint64 subscriptionId) public onlyRole(ADMIN) {
        _subscriptionId = subscriptionId;
    }
/* 
    function withdrawProtocol(address beneficiary, address collection) public onlyRole(ADMIN) {
        Collection(collection).protocolWithdraw(beneficiary);
    }
 */
    function withdrawSobres(address beneficiary, address collection) public onlyRole(ADMIN) {
        // TODO
    }
    function setAllowedToken(address token, bool allowed) public onlyRole(ADMIN) {
        allowedTokens[token] = allowed;
    } 
    
    // TEMPLATES
    function setCollectionTemplate(address template) public onlyRole(DEFAULT_ADMIN_ROLE) {
        collectionTemplate = template;
    }
    function setPocketTemplate(address template) public onlyRole(DEFAULT_ADMIN_ROLE) {
        pocketTemplate = template;
    }
    function setPrizesTemplate(address template) public onlyRole(DEFAULT_ADMIN_ROLE) {
        prizesTemplate = template;
    }
    function setAlbumTemplate(address template) public onlyRole(DEFAULT_ADMIN_ROLE) {
        albumTemplate = template;
    }

    function protocolWithdraw(address beneficiary, address collection) public onlyRole(ADMIN) {
        IERC20(paymentToken[collection]).transfer(beneficiary, _protocolBalance[collection]);
        _protocolBalance[collection] = 0;
    }

    function creatorWithdraw(address beneficiary, address collection) public {
        require(msg.sender == Collection(collection).creator(), "Only creator can call");
        IERC20(paymentToken[collection]).transfer(beneficiary, creatorBalance[collection]);
        creatorBalance[collection] = 0;
    }

    function createCollection(        
        address _paymentToken,
        uint _albumPrice,
        string memory uri, 
        uint8[] memory _densityCurveFigus
    ) public returns (address) {
        uint currentIndex = index._value;
        index.increment();
        address creator = msg.sender;
        address nPocket = Clones.clone(pocketTemplate);
        Pocket(nPocket).initialize(creator, _subscriptionId);
        address nCollectionAddress = Clones.clone(collectionTemplate);
        address nPrizesAddress = Clones.clone(prizesTemplate);
        Prizes(nPrizesAddress).initialize(nCollectionAddress);
        albumPrice[nCollectionAddress] = _albumPrice;
        Collection(nCollectionAddress).initialize(
            creator, 
            uri, 
            nPocket,
            nPrizesAddress,
            _densityCurveFigus 
        );
        paymentToken[nCollectionAddress] = _paymentToken;
        collections[currentIndex] = nCollectionAddress;
        emit NewCollection(currentIndex, creator, _paymentToken, nCollectionAddress, nPrizesAddress, nPocket);
        return nCollectionAddress;
    }
 
    function getAlbum(address collection) public {
        require(albums[collection][msg.sender] == address(0), "Already owner of an album");
        uint _albumPrice = albumPrice[collection];
        if (_albumPrice > 0) {
            uint _protocolAlbumPrice = _albumPrice * fee / 10000;
            creatorBalance[collection] += _albumPrice - _protocolAlbumPrice;
            _protocolBalance[collection] += _protocolAlbumPrice;
            IERC20(paymentToken[collection]).transferFrom(msg.sender, address(this), _albumPrice);
        }
        address albumCreatedAddress = Clones.clone(albumTemplate);
        Album(albumCreatedAddress).initialize(msg.sender, collection);
        albums[collection][msg.sender] = albumCreatedAddress;
        emit AlbumCreated(msg.sender, albumCreatedAddress);
    }

}
