// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { AccessControl } from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import { FiguritasCollection } from "./FiguritasCollection.sol";

contract FigusCreator is AccessControl {
    using Counters for Counters.Counter;
    bytes32 public constant ADMIN = keccak256("ADMIN");

    uint fee;
    uint64 subscriptionId;

    Counters.Counter public _index;
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

    function setSubscriptionId(uint64 _subscriptionId) public onlyRole(ADMIN) {
        subscriptionId = _subscriptionId;
    }

    function withdrawProtocol(address beneficiary, address collection) public onlyRole(ADMIN) {
        FiguritasCollection(collection).protocolWithdraw(beneficiary);
    }

    function withdrawSobres(address beneficiary, address collection) public onlyRole(ADMIN) {
        // TODO
    }

    function createCollection(
        string memory uri, 
        uint8[] memory _densityCurveFigus
    ) public returns (address) {
        uint currentIndex = _index._value;
        _index.increment();
        address creator = msg.sender;
        FiguritasCollection nalbum = new FiguritasCollection(
            creator,
            uri,
            fee,
            subscriptionId,
            _densityCurveFigus
        );
        address nalbumAddress = address(nalbum);
        collections[currentIndex] = nalbumAddress;
        emit NewCollection(currentIndex, creator, nalbumAddress);
        return nalbumAddress;
    }


}
