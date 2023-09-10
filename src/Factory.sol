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
    address public paymentToken;    // move to mapping of approvedTokens 

    address public collectionTemplate;
    address public pocketTemplate;
    address public prizesTemplate; // this is going to be probably multiple (mapping)
    address public albumTemplate;

    uint _creatorBalance;
    uint _protocolBalance;
    
    Counters.Counter public index;
    mapping(uint => address) public collections;
    mapping(address => uint) public albumPrice;
    mapping(address => mapping(address => address)) public albums;

    event NewCollection(uint index, address creator, address collection);
    event AlbumCreated(address indexed owner, address indexed album);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);
    }

    function setFee(uint _fee) public onlyRole(ADMIN) {
        // make it over 1000
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
    // later update for a mapping
    function setPaymentToken(address token) public {    // , bool accepted
        paymentToken = token;
    }
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
// add fee and albumPrice
    function createCollection(
        
        uint _albumPrice,
        string memory uri, 
        uint8[] memory _densityCurveFigus
    ) public returns (address) {
        uint currentIndex = index._value;
        index.increment();
        address creator = msg.sender;
        address npocket = Clones.clone(pocketTemplate);
        Pocket(npocket).initialize(creator, _subscriptionId);
        address nCollectionAddress = Clones.clone(collectionTemplate);
        address nPrizesAddress = Clones.clone(prizesTemplate);
        Prizes(nPrizesAddress).initialize(nCollectionAddress);
        albumPrice[nCollectionAddress] = _albumPrice;
        Collection(nCollectionAddress).initialize(
            creator, 
            uri, 
            fee, 
            npocket,
            nPrizesAddress,
            _densityCurveFigus 
        );

        collections[currentIndex] = nCollectionAddress;
        emit NewCollection(currentIndex, creator, nCollectionAddress);
        return nCollectionAddress;
    }
 
    function getAlbum(address collection) public {
        require(albums[collection][msg.sender] == address(0), "Already owner of an album");
        uint _albumPrice = albumPrice[collection];
        if (_albumPrice > 0) {
            uint _protocolAlbumPrice = _albumPrice * fee / 10000;
            _creatorBalance += _albumPrice - _protocolAlbumPrice;
            _protocolBalance += _protocolAlbumPrice;
            IERC20(paymentToken).transferFrom(msg.sender, address(this), _albumPrice);
        }
        address albumCreatedAddress = Clones.clone(albumTemplate);
        Album(albumCreatedAddress).initialize(msg.sender, collection);
        albums[collection][msg.sender] = albumCreatedAddress;
        emit AlbumCreated(msg.sender, albumCreatedAddress);
    }

}
