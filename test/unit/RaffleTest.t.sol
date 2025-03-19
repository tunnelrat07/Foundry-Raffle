// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
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

    // skipping the test (by returning from the function) if we are one a fork-url (not local)
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
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

    /* 
    
    CheckUpkeep 
    
    */
    // testing if the checkUpkeep returns false if there is no balance in the contract
    function testIfCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // changes the block number to current

        // we are not gonna enter raffle , hence the contract will have no balace and return false
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upKeepNeeded); // upKeedNeeded should be false coz there is no balance in the contract
    }

    // testing if the checkUpkeep returns false if the raffle is not open
    function testIfCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
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
        /* Now the state of the raffle should be calculating */
        // now the checkUpkeep function should return false
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upKeepNeeded); // upKeedNeeded should be false coz the state of the contract is not open
    }

    /* Challanges */
    // testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        // we enter the raffle so that the Raffle has balance
        // Also the Raffle state defualts to open
        // Raffle has players

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Not updating the blockTimestamp (immediately calling the checkUpkeep function) // it should return false
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upKeepNeeded);
    }

    // testCheckUpkeepReturnsTrueWhenParametersAreGood
    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        // entering the raffle -> raffle has balance , has players, raffle state defaults to Open
        raffle.enterRaffle{value: entranceFee}();
        // we have entered the raffle
        // using the vm.warp() to set the block.timestamp
        vm.warp(block.timestamp + interval + 1);
        // setting the block time stamp to (current block.timestamp + 30sec(interval) + 1) , so that its guarenteed that enought time has passed
        vm.roll(block.number + 1); // changes the block number to current block.number + 1

        // Now all the conditions are met and the upKeepNeeded should be true
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upKeepNeeded);
    }

    /* 
    performUpkeep 
     */

    // testing if performUpkeep can only run if checkUpkeep is true
    function testIfPerformUpKeepRunsIfCheckUpKeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Now all the conditions are met and the checkUpkeep should be true
        // Act / Assert
        raffle.performUpkeep("");
    }

    // testing if performUpkeep reverts if checkUpkeep is false
    function testIfPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numberOfPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        // Act / Assert
        /* we expect this to revert with a custom error, but our error     error Raffle_upKeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
        );
        has parameters */

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_upKeepNotNeeded.selector,
                currentBalance,
                numberOfPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    // What if we need data from emitted events into our tests ?
    // testing if PerformUpkeep updates raffle state and emits request Id
    function testIfPerformUpKeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        // instead using the modifier
        // Arrange
        /* vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); */
        // the checkupkeep is now true and the performUpkeep does not revert

        // Act
        vm.recordLogs(); // records whatever events (logs) emiited by the next transaction
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0); // checking if we get requestId
        assert(uint256(raffleState) == 1); // and that the state is calculating
    }

    /* 
    fullfillRandomWords
     */

    // testing if fullfillRandomWords can only be called after performUpkeep is called
    function testfulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(
        uint256 randomRequestId
    ) public raffleEntered skipFork {
        // Ararnge / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    // testing if fullFillrandomWords picks winner, resets the whole array and sends money
    function testFullFillRandomWordsPicksWinnerResetsAndSendsMoney()
        public
        raffleEntered
        skipFork
    {
        // Arrange
        // first person to enter the raffle is the player
        // we've set it up using the modifier raffleEntered
        uint256 additionalEntrants = 3; // 4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether); // sets up a prank from an address that has some ether
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs(); // records whatever events (logs) emiited by the next transaction
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState rafflestate = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(rafflestate) == 0); // the contract should now be opened
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
