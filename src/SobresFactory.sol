// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract SobresFactory is ERC721, ERC721Burnable, Ownable, VRFConsumerBaseV2, ReentrancyGuard {
    using Counters for Counters.Counter;
    address admin;
    address collection;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call");
        _;
    }

    event SobresConfig(uint amount, address paymentToken, uint price, uint limit);
    event SobresBought(address indexed owner, uint _type, uint amount);

    uint64 subscriptionId;              // VRF subscription
    VRFCoordinatorV2Interface COORDINATOR;
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 2000000;
    uint16 requestConfirmations = 3;

    struct SobreConfig {
        uint amount;            // how many figus this sobre contains
        address paymentToken;   // how is it payed
        uint price;             // how much it cost (in payment token)
        uint limit;             // limited qty (use MAX for ilimited)
    }

    struct Request {
        bool fulfilled;
        bool exists;
        address beneficiary;
        uint config;
        uint[] randomWords;
    }

    struct Sobre {
        uint config;
        uint random;
    }

    Counters.Counter private _tokenIdCounter;
    Counters.Counter public _configCounter;

    mapping(uint => SobreConfig) public promotions;
    mapping(uint => Sobre) public sobres;
    mapping(uint => Request) public requests;

    constructor(string memory name, string memory symbol, address _admin, uint64 _subscriptionId) 
    ERC721(name, symbol) 
    VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
    {
        admin = _admin;
        collection = msg.sender;
        subscriptionId = _subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        ); 
    }

    function configSobre(uint amount, uint price, address paymentToken, uint limit) public onlyAdmin() {
        uint configCounter = _configCounter.current();        
        promotions[configCounter] = SobreConfig (
            amount,
            paymentToken,
            price,
            limit   
        );
        _configCounter.increment();
        emit SobresConfig(amount, paymentToken, price, limit);
    } 

    function buyFigus(address beneficiary, uint _config, uint amount, uint fakeRandom) public nonReentrant() {
        SobreConfig storage config = promotions[_config];
        require(config.limit > amount, "Not enough in sale!");
        config.limit -= amount;

        uint totalValue = amount * config.price;
        // TODO: handle balance and fees!
        IERC20(config.paymentToken).transferFrom(msg.sender, address(this), totalValue);
        // requestRandomWords(beneficiary, amount, _config);
        
        // TESTS BYPASS OF VRF      //////////////////////////////////////
        requests[fakeRandom] = Request({
            randomWords: new uint[](0),
            exists: true,
            beneficiary: beneficiary,
            config: _config,
            fulfilled: false
        });
        uint[] memory randomWordsC = new uint[](amount);
        for (uint i = 0; i < amount; i++) {
            randomWordsC[i] = uint256(keccak256(abi.encode(fakeRandom, i)));
        }
        fakeFulfillRandomWords(fakeRandom, randomWordsC);
        ///////////////////////////////////////////////////////////////////

        emit SobresBought(beneficiary, _config, amount);
    }

    function requestRandomWords(address requester, uint amount, uint _config)
        public
        returns (uint256 requestId)
    {
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            uint32(amount)
        );
        requests[requestId] = Request({
            randomWords: new uint[](0),
            exists: true,
            beneficiary: requester,
            config: _config,
            fulfilled: false
        });
        return requestId;
    }
    
    function fakeFulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    )
    internal 
    {
        Request storage request = requests[_requestId];
        require(request.exists, "request not found");
        request.fulfilled = true;        

        for (uint i = 0; i < _randomWords.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            sobres[tokenId] = Sobre (
                request.config,
                _randomWords[i]
            );
            _tokenIdCounter.increment();
            _safeMint(request.beneficiary, tokenId);
        }
    }    

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    )
    internal 
    override {
        Request storage request = requests[_requestId];
        require(request.exists, "request not found");
        request.fulfilled = true;        

        for (uint i = 0; i < _randomWords.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            sobres[tokenId] = Sobre (
                request.config,
                _randomWords[i]
            );
            _tokenIdCounter.increment();
            _safeMint(request.beneficiary, tokenId);
        }
    }    

    function getSobreInformation(uint id) public view returns (uint amount, uint random) {
        Sobre memory sobre = sobres[id];
        return (promotions[sobre.config].amount, sobre.random);
    }

    function withdraw(address token) public {
        // TODO
        // return gains
        // differentiate admin of fees/protocol
    }

}