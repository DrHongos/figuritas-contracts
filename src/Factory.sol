// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
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


/* 
    Pack fees
To do this, i need to know:
    - cost of VRF service
    - Price of LINK

    OR, easy peasy, subject to a minimum (according to token) known as upper limit + x%

*/

contract Factory is AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    bytes32 public constant ADMIN = keccak256("ADMIN");

    uint public fee;
    uint64 _subscriptionId;
    uint public minPackPrice = 1*10**17;       // CAREFUL! this is token dependent

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

    mapping(address => address) public prizes;

    event NewCollection(uint index, address creator, address paymentToken, address collection, address prizes, address packs);
    event AlbumCreated(address indexed owner, address indexed album);
    event PackBought(address indexed owner, address indexed collection, uint _type, uint amount);

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
        Pocket(nPocket).initialize(minPackPrice, creator,  _subscriptionId);
        address nCollectionAddress = Clones.clone(collectionTemplate);
        address nPrizesAddress = Clones.clone(prizesTemplate);
        Prizes(nPrizesAddress).initialize(nCollectionAddress);
        prizes[nCollectionAddress] = nPrizesAddress;
        albumPrice[nCollectionAddress] = _albumPrice;
        Collection(nCollectionAddress).initialize(
            creator, 
            uri, 
            nPocket,
//            nPrizesAddress,
            _densityCurveFigus 
        );
        paymentToken[nCollectionAddress] = _paymentToken;
        collections[currentIndex] = nCollectionAddress;
        emit NewCollection(currentIndex, creator, _paymentToken, nCollectionAddress, nPrizesAddress, nPocket);
        return nCollectionAddress;
    }
 
    function getAlbum(address collection) public nonReentrant() {
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


    function buyPack(address beneficiary, address collection, uint _config, uint amount, uint fakeRandom) public nonReentrant() {
        Pocket pkt = Pocket(Collection(collection).pocket()); 
        (, uint price, uint limit) = pkt.configurations(_config);
        require(limit >= amount, "Not enough in sale!");

        uint totalValue = amount * price;
        uint _protocolPay = totalValue * fee / 10000;
        creatorBalance[collection] += totalValue - _protocolPay;
        _protocolBalance[collection] += _protocolPay;
        IERC20(paymentToken[collection]).transferFrom(msg.sender, address(this), totalValue);
        
        // _requestRandomWords(beneficiary, amount, _config);                   // real
        pkt.fakeFulfillRandomWords(fakeRandom, amount, beneficiary, _config);   // bypass

        emit PackBought(beneficiary, collection, _config, amount);
    }

}
