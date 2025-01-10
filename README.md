# Dapp Staking Contract

This repository contains a Solidity smart contract (`Dapp.sol`) for a staking mechanism where users can deposit tokens, earn rewards based on tiered reward rates and lock times, and claim their deposits after the lock period. The contract is designed to be deployed in a Hardhat environment.

## Contract Overview

The `Dapp` contract inherits from a `MyToken` contract (assumed to be an ERC20-compatible token) and uses an external ERC20 token (`dappToken`) for staking and rewards. It implements the following features:

*   **Tiered Rewards:** Users can deposit tokens into different tiers, each with its own reward rate (in basis points) and lock time (in seconds).
*   **Whitelisting:** Only whitelisted users can deposit tokens.
*   **Deposit Cooldown:** A cooldown period between deposits is enforced to prevent abuse.
*   **Claiming:** Users can claim their deposited amount and accumulated rewards after the lock time has elapsed.
*   **Event Logging:** Important contract actions are logged as events for easy tracking.
*   **Error Handling:** Custom errors are used for clear error reporting.

## Contract Details

*   **`Dapp.sol`:** The main contract implementing the staking logic.
*   **`Token.sol`:** (Included by import) The ERC20 token contract used for staking (assumed to be in the same directory).
*   **Dependencies:**
    *   `@openzeppelin/contracts`: For the `IERC20` interface.

## Getting Started

1.  **Prerequisites:**
    *   Node.js and npm (or yarn)
    *   Hardhat: `npm install --save-dev hardhat`
    *   OpenZeppelin Contracts: `npm install @openzeppelin/contracts`

2.  **Installation:**

    ```bash
    git clone <repository_url>
    cd <repository_directory>
    npm install
    ```

3.  **Configuration:**

    *   In your Hardhat configuration file (`hardhat.config.js`), configure your network settings (e.g., local Hardhat network, testnet, mainnet).

4.  **Deployment:**

    *   Compile the contracts:

    ```bash
    npx hardhat compile
    ```

    *   Deploy the `Dapp` contract, providing the address of the `dappToken` contract as a constructor argument:

    ```bash
    npx hardhat run scripts/deploy.js --network <network_name>
    ```

    (Create a `deploy.js` script in the `scripts` directory similar to the example below)

    ```javascript
    const { ethers } = require("hardhat");

    async function main() {
        const Dapp = await ethers.getContractFactory("Dapp");
        const dapp = await Dapp.deploy("<dappToken_address>");

        await dapp.deployed();

        console.log("Dapp deployed to:", dapp.address);
    }

    main().catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
    ```

5.  **Interaction:**

    *   Use Hardhat console or a frontend application to interact with the contract.

## Contract Functions

*   **`constructor(address _token)`:** Initializes the contract with the `dappToken` address and sets up default tiers.
*   **`updateTier(uint8 _tier, uint256 _rewardRate, uint256 _lockTime)`:** Updates the reward rate and lock time for a specific tier (only owner).
*   **`setWhitelist(address _user, bool _status)`:** Whitelists or removes a user (only owner).
*   **`deposit(uint8 _tier, uint256 _amount)`:** Deposits tokens into a specific tier (only whitelisted users).
*   **`claim(uint8 _tier)`:** Claims the deposited amount and rewards (only whitelisted users).
*   **`getDepositDetails(address _user, uint8 _tier)`:** Returns the details of a user's deposit.
*   **`receive()`:** Fallback function to accept Ether.

## Events

*   **`TierUpdated(uint8 indexed tier, uint256 rewardRate, uint256 lockTime)`:** Emitted when a tier is updated.
*   **`Deposited(address indexed user, uint256 amount, uint8 tier, uint256 reward, uint256 unlockTime)`:** Emitted when a user deposits tokens.
*   **`Claimed(address indexed user, uint256 amount)`:** Emitted when a user claims their deposit.
*   **`Whitelisted(address indexed user, bool status)`:** Emitted when a user's whitelist status is changed.

## Security Considerations

*   The contract relies on the security of the underlying ERC20 token (`dappToken`).
*   Proper access control is implemented using modifiers (`onlyOwner`, `onlyWhitelisted`).
*   Reentrancy attacks are mitigated by using safe transfer functions from OpenZeppelin's `IERC20` interface.
*   It's highly recommended to conduct thorough testing and auditing before deploying to a production environment.

## Disclaimer

This contract is provided as-is and without any warranties. Use it at your own risk.
