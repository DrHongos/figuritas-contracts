// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { AccessControl } from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import { ERC1155Holder } from "../lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC1155Receiver } from "../lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import { ERC721Holder } from "../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC1155 } from "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";

contract TradingPit is AccessControl, ERC1155Holder, ERC721Holder {
    using Counters for Counters.Counter;
    bytes32 public constant ADMIN = keccak256("ADMIN");

    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Item {
        TokenType token;
        address tokenAddress;
        uint amount;
    }

    struct Offer {
        Item offered;
        Item required;
        address creator;
        bool open;
    }

    Counters.Counter public _index;
    mapping(uint => Offer) public offers;

    event NewOffer(uint index, address creator);
    event OfferTaken(uint index, address taker);
    event OfferCancelled(uint index);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);
    }
    /* 
    // very limited 
        only 1 to 1 item
        only 1 ERC1155 (amount defines the ID)
    */
    function createOffer(
        Item calldata offering,
        Item calldata requires
    ) public returns (uint) {
        uint nOfferIndex = _index._value;
        _index.increment();
        offers[nOfferIndex] = Offer(
            offering,
            requires,
            msg.sender,
            true
        );
        // transfer the items to this contract
        transferItem(msg.sender, address(this), offering);
        emit NewOffer(nOfferIndex, msg.sender);
        return nOfferIndex;
    }

    function takeOffer(uint id) public {
        Offer storage offerTaken = offers[id];
        require(offerTaken.open == true, "Offer not available");
        transferItem(msg.sender, offerTaken.creator, offerTaken.required);        
        transferItem(address(this), msg.sender, offerTaken.offered);
        offerTaken.open = false;
        emit OfferTaken(id, msg.sender);
    }

    function cancelOffer(uint id) public {
        Offer storage offerCancel = offers[id];
        require(offerCancel.open == true, "Offer not available");
        require(msg.sender == offerCancel.creator, "Only creator can cancel");
        offerCancel.open = false;
        transferItem(address(this), msg.sender, offerCancel.offered);
        emit OfferCancelled(id);
    }

    function transferItem(address from, address to, Item memory item) internal {
        if (item.token == TokenType.ERC20) {
            IERC20(item.tokenAddress).transferFrom(from, to, item.amount);
        } else if (item.token == TokenType.ERC721) {
            IERC721(item.tokenAddress).safeTransferFrom(from, to, item.amount, "");
        } else if (item.token == TokenType.ERC1155) {
            IERC1155(item.tokenAddress).safeTransferFrom(from, to, item.amount, 1, "");
        } else {
            revert("Token type not supported");
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Receiver, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
