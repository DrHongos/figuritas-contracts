// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/utils/CountersUpgradeable.sol";
import { Initializable } from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { VRFConsumerBaseV2Upgradeable } from "./VRFConsumerBaseV2Upgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

/* 
    Add withdraw mechanism
    Add fee for LINK payment
        - min fee (necessary)    
*/

contract Pocket is
    Initializable,
    ERC721Upgradeable, 
    ERC721BurnableUpgradeable, 
    OwnableUpgradeable, 
    VRFConsumerBaseV2Upgradeable, 
    ReentrancyGuard 
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call");
        _;
    }

    event SobresConfig(uint amount, address paymentToken, uint price, uint limit);
    event SobresBought(address indexed owner, uint _type, uint amount);

    uint64 _subscriptionId;              // VRF subscription
    VRFCoordinatorV2Interface _COORDINATOR;
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 _keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 _callbackGasLimit = 2000000;
    uint16 _requestConfirmations = 3;

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

    CountersUpgradeable.Counter private _tokenIdCounter;
    CountersUpgradeable.Counter public configCounter;

    mapping(uint => SobreConfig) public promotions;
    mapping(uint => Sobre) public sobres;
    mapping(uint => Request) public requests;

    function initialize(
        address _admin,
        uint64 subscriptionId
    ) initializer public {
        __ERC721_init("SOBRE", "SFIGU");
        __ERC721Burnable_init();
        __Ownable_init();
        admin = _admin;
        _subscriptionId = subscriptionId;
        __VRFConsumerBaseV2Upgradeable_init(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        _COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        ); 
    }

/* 
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
 */
    function configSobre(uint amount, uint price, address paymentToken, uint limit) public onlyAdmin() {
        uint _configCounter = configCounter.current();        
        promotions[_configCounter] = SobreConfig (
            amount,
            paymentToken,
            price,
            limit   
        );
        configCounter.increment();
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
        _fakeFulfillRandomWords(fakeRandom, randomWordsC);
        ///////////////////////////////////////////////////////////////////

        emit SobresBought(beneficiary, _config, amount);
    }

    function requestRandomWords(address requester, uint amount, uint _config)
        public
        returns (uint256 requestId)
    {
        requestId = _COORDINATOR.requestRandomWords(
            _keyHash,
            _subscriptionId,
            _requestConfirmations,
            _callbackGasLimit,
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
    
    function _fakeFulfillRandomWords(
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