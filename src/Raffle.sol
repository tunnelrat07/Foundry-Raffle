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

// CEI : Checks Effects Interactions pattern -> while conding functions
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {VRFConsumerBaseV2Plus} from "../lib/chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title Raffle contract
 * @author Tunnel Rat
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv.25
 */

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* 
    ===========Errors==========
    */
    error Raffle__sendMoreToEnterRaffle();
    error Raffle__notEnoughTimeHasPassed();
    error Raffle__transferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle_upKeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );
    /* 
    ===========Type Declarations==========
    */
    enum RaffleState {
        // can be converted to integers
        OPEN, // 0
        CALCULATING // 1
    }
    /* 
    ===========State Variables==========
     */
    // immutable variable - gas wise cheap , cannot be changed, defined in constructor
    uint256 private immutable i_entranceFee;
    /**  @dev Duration of the lottery in seconds  */
    uint256 private immutable i_interval;
    // since one of the addresses is going to be the winner and get paid , making the address array payable
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    bytes32 private immutable i_keyHash; // determines the maximum gas price for VRF requests
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    RaffleState private s_raffleState; // should start as open
    // keeping a track of the lottery's current state
    // but we create an enum instead of a bool , incase our lottery has many different states that we wanna keep track of
    /* bool private s_calculatingWinner = false;  */
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
    event WinnerPicked(address indexed winner);

    /* 
    ==========Modifiers==========
     */

    /* 
    ===========Functions===========
     */

    /* Constructor */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // we can also do RaffleState(0)
    }

    /* External functions */

    // lets users enter the raffle by paying some fees
    function enterRaffle() external payable {
        /* 
        Checks -> Check if requirements are met (requires, conditionals)
         */
        // reverting with string errors - not gas efficient
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        // Hence using custom errors
        if (msg.value < i_entranceFee) {
            revert Raffle__sendMoreToEnterRaffle();
        }
        // These custom errors can also be sent using require - but less gas efficient than using an if() statement
        // require(msg.value >= i_entranceFee , sendMoreToEnterRaffle());

        // user should only be allowed to enter if the winner is not being currently calculated (i.e the Raffle is in "OPEN" state and not in "CALCULATING")
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        /* 
        Effects -> Internal contract state
         */
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);

        /* 
        Interactions -> (External contract interactions)
         */
    }

    // When should the winner be picked  ?
    /**
     * @dev This is the function that the chainlink nodes will call to check if the lottery is ready to have a winner picked
     * The following should be true for the upKeepNeeded to be true
     * 1. The time interval has passed between raffle runs
     * 2 .The lottery is open
     * 3. The contract has balance
     * 4. Implicityly,your subscription has LINK
     * @param - ignored
     * @return upKeepNeeded - true if its time to pickWinner , reward them and then restart the lottery
     * @return
     */
    // commenting out the checkData -> it is not being used anywhere in the function
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upKeepNeeded, bytes memory /* performData */)
    {
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        // if all the above conditions are met then, the upKeepNeeded is true
        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upKeepNeeded, "");
    }

    // picks winner at random -> the pickwinner function
    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Needs to be automatically called
    function performUpkeep(bytes calldata /* performData */) external override {
        // check if enough time has passed
        // block.timestamp (gives current block timestamp / current approx time according to the blockchain)
        /*         if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle__notEnoughTimeHasPassed();
        } */

        // Now when we automate this contract , we wanna make sure that the chainlink Nodes can only call this when its time to pickWinner (i.e when the upKeepNeeded is true)
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle_upKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        // If enough time has passed
        // Get our random Number ChainlinkVRF2.5
        // 1. Request RNG
        // 2. Get RNG
        /* uint256 requestId = */ s_vrfCoordinator.requestRandomWords(request);
    }

    // randomwords[] is an array with a single element -> the random word that is generated
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal override {
        // if we are in the middle of calculating the winner, we should restrict people to enter the Raffle
        // we can keep track of Lottery's current state
        // to get an appropriate index in the valid range (0 , noOfPlayers) we take remainder
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        // now that we have picked the winner setting the state of the Raffle back to OPEN
        s_raffleState = RaffleState.OPEN;
        // we also need to reset the players array for the new lottery round
        s_players = new address payable[](0); // new address payable array of size 0
        // updating the lastTimeStamp to the current time stamp to keep track of time, so that our clock restarts
        s_lastTimeStamp = block.timestamp;
        // now we wanna pay the winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__transferFailed();
        }
        emit WinnerPicked(s_recentWinner);
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

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
