// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.3.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title Raffle contract
 * @author Tunnel Rat
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv.25
 */

contract Raffle {
    /* 
    ===========Errors==========
    */
    error Raffle__sendMoreToEnterRaffle();
    error Raffle__notEnoughTimeHasPassed();
    /* 
    State Variables
     */
    // immutable variable - gas wise cheap , cannot be changed, defined in constructor
    uint256 private immutable i_entranceFee;
    /**  @dev Duration of the lottery in seconds  */
    uint256 private immutable i_interval;
    // since one of the addresses is going to be the winner and get paid , making the address array payable
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    /* 
    =========Events=============
     */

    // a rule of thumb - always emit an event whenenver we update a storage variable
    // Working with evens
    // 1. Makes migration easier
    // 2. Makes front end "indexing" easier
    // indexed keyword in events is used to make event parameters searchable using logs
    // Here, indexed is applied to the player parameter. This means:
    // The player address will be stored in a log topic, making it easier to search for in the blockchain.
    // Without indexed, event parameters are stored in transaction logs, but they are not filterable.
    // A maximum of 3 parameters in an event can be indexed.
    event RaffleEntered(address indexed player);

    /* 
    ==========Modifiers==========
     */

    /* 
    ===========Functions===========
     */

    /* Constructor */
    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    /* External functions */

    // lets users enter the raffle by paying some fees
    function enterRaffle() external payable {
        // reverting with string errors - not gas efficient
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        // Hence using custom errors
        if (msg.value < i_entranceFee) {
            revert Raffle__sendMoreToEnterRaffle();
        }
        // These custom errors can also be sent using require - but less gas efficient than using an if() statement
        // require(msg.value >= i_entranceFee , sendMoreToEnterRaffle());
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // picks winner at random
    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Needs to be automatically called
    function pickWinner() external {
        // check if enough time has passed
        // block.timestamp (gives current block timestamp / current approx time according to the blockchain)
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle__notEnoughTimeHasPassed();
        }

        // If enough time has passed
        // Get our random Number ChainlinkVRF2.5
        // 1. Request RNG
        // 2. Get RNG
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    /* View and pure */
    /* 
    Getter Functions 
    for private variables
    visibility set to external - contract can already access the private variables
    and external functions are gas wise cheaper than public functions
    */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
