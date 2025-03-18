// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    /* 
    Events to test if they are emmited
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    // creating test users to interact with our raffle
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        // dealing the player a starting balance
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    // testing if the Raffle starts as Open
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // testing if the raffle reverts if enough entrance fee isnt paid
    function testRaffleRevertsIfEnoughEntranceFeesIsntPaid() public {
        // Arrange
        vm.prank(PLAYER);
        // Act /Assert
        // we wanna revert with the specific error     error Raffle__sendMoreToEnterRaffle();
        vm.expectRevert(Raffle.Raffle__sendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    // testing if raffle records players when they enter the raffle
    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // ACT
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
    }

    /* 
    testing events
     */

    // testing if entering Raffle emits the corresponding event
    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    // testing if players arent allowed to enter while Raffle is calculating the winner
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        // we call performUpkeep which sets the state of the Raffle to calculating
        raffle.enterRaffle{value: entranceFee}();
        // we have entered the raffle
        // using the vm.warp() to set the block.timestamp
        vm.warp(block.timestamp + interval + 1);
        // setting the block time stamp to (current block.timestamp + 30sec(interval) + 1) , so that its guarenteed that enought time has passed
        vm.roll(block.number + 1); // changes the block number to current block.number + 1
        raffle.performUpkeep(""); // now this should pass and the raffle state should be set to calculating

        // ACT / ASSERT
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector); // we wanna revert with the Raffle__RaffleNotOpen() error
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
}
