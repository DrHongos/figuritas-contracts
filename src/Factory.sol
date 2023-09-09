// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import { AccessControl } from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import { Collection } from "./Collection.sol";
import { Pocket } from "./Pocket.sol";
import { Prizes } from "./Prizes.sol";

/* 
WARNING 
Highly experimental and quickly done

*/

contract Factory is AccessControl {
    using Counters for Counters.Counter;
    bytes32 public constant ADMIN = keccak256("ADMIN");

    uint public fee;
    uint64 _subscriptionId;

    address public collectionTemplate;
    address public pocketTemplate;
    address public prizesTemplate; // this is going to be probably multiple (mapping)

    Counters.Counter public index;
    mapping(uint => address) public collections;

    event NewCollection(uint index, address creator, address collection);

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

    function withdrawProtocol(address beneficiary, address collection) public onlyRole(ADMIN) {
        Collection(collection).protocolWithdraw(beneficiary);
    }

    function withdrawSobres(address beneficiary, address collection) public onlyRole(ADMIN) {
        // TODO
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

    function createCollection(
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
        Prizes(nPrizesAddress).initialize();
        
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


}
