# Raffle Smart Contract

## Overview

This project implements a decentralized raffle smart contract using Solidity, Chainlink Automation, and Chainlink VRF v2.5. It allows users to enter a raffle by paying an entry fee, with a winner being selected automatically at regular intervals using Chainlink VRF. The contract is deployed and tested using Foundry and incorporates best practices such as the CEI (Checks-Effects-Interactions) pattern for security and efficiency.

## Features

- **Automated Winner Selection**: Uses Chainlink Automation to trigger winner selection at predefined intervals.
- **Randomness with Chainlink VRF**: Ensures a fair winner selection process using verifiable randomness.
- **Gas-Efficient Implementation**: Uses Foundry for testing and development, along with optimized Solidity practices.
- **Security Best Practices**: Implements custom errors, event emissions, and state management techniques to enhance security.

## Technologies Used

- **Solidity**: Smart contract programming language.
- **Chainlink VRF v2.5**: Secure randomness provider.
- **Chainlink Automation**: Used for automating winner selection.
- **Foundry**: Development, testing, and deployment framework.
- **Solmate**: Lightweight and gas-efficient token contracts.

## Installation

### Prerequisites
Ensure you have [Foundry](https://github.com/foundry-rs/foundry) installed:
```sh
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Clone the repository:
```sh
git clone https://github.com/tunnelrat07/Foundry-Raffle.git
cd raffle-contract
```

### Install Dependencies

Install the required dependencies using Foundry:
```sh
forge install smartcontractkit/chainlink --no-commit
forge install Cyfrin/foundry-devops --no-commit
forge install transmissions11/solmate --no-commit
```

## Deployment

Update the `.env` file with the required parameters such as:
- **Chainlink VRF Coordinator Address**
- **Key Hash**
- **Subscription ID**
- **Automation Configuration**

Compile the smart contract:
```sh
forge build
```

Deploy the contract:
```sh
forge create --rpc-url <NETWORK_RPC_URL> --private-key <YOUR_PRIVATE_KEY> src/Raffle.sol:Raffle --constructor-args <entranceFee> <interval> <vrfCoordinator> <gasLane> <subscriptionId> <callbackGasLimit>
```

## Running Tests

To run the tests using Foundry:
```sh
forge test
```

For more detailed debugging output:
```sh
forge test -vvv
```

## Usage

### Entering the Raffle
Users can enter the raffle by sending the required entrance fee via a transaction to the contract:
```sh
cast send <CONTRACT_ADDRESS> "enterRaffle()" --value <ENTRANCE_FEE> --rpc-url <NETWORK_RPC_URL> --private-key <YOUR_PRIVATE_KEY>
```

### Checking Raffle Status
Query the current raffle state:
```sh
cast call <CONTRACT_ADDRESS> "getRaffleState()" --rpc-url <NETWORK_RPC_URL>
```

### Fetching the Recent Winner
```sh
cast call <CONTRACT_ADDRESS> "getRecentWinner()" --rpc-url <NETWORK_RPC_URL>
```

## Security Considerations
- The contract follows best security practices, including the CEI pattern.
- Custom errors improve gas efficiency and debugging.
- Randomness is secured through Chainlink VRF, preventing manipulation.
- The contract ensures fair participation and automated execution.

## License

This project is licensed under the MIT License.

## Acknowledgments

- [Chainlink](https://chain.link/) for VRF and Automation services.
- [Foundry](https://github.com/foundry-rs/foundry) for Solidity development tools.
- [Solmate](https://github.com/transmissions11/solmate) for lightweight token contracts.
- [Cyfrin Foundry DevOps](https://github.com/Cyfrin/foundry-devops) for smart contract automation tooling.
