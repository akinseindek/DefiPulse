# DefiPulse
A smart contract that manages a decentralized investment fund where users can deposit STX, receive fund tokens representing their share, and participate in governance decisions. The fund automatically rebalances based on predefined strategies and community votes.

---

## Table of Contents

* Introduction
* Features
* Smart Contract Details
    * Constants
    * Fungible Token
    * Data Maps and Variables
    * Private Functions
    * Public Functions
    * Read-Only Functions
* How to Use
* Fees
* Governance
* Errors
* Contributing
* License
* Contact

---

## Introduction

Welcome to **DefiPulse**, a Decentralized Autonomous Investment Fund (DeFi ETF) built on the Stacks blockchain. This smart contract empowers users to participate in a community-governed investment fund by depositing STX tokens, receiving fund tokens representing their share, and actively engaging in crucial governance decisions. The fund's asset allocation is managed through predefined strategies and community-approved proposals, facilitating automated rebalancing and transparent operations.

DefiPulse aims to create a truly decentralized investment vehicle where collective intelligence drives portfolio management and strategic adjustments.

## Features

* **Decentralized Investment:** Deposit STX to acquire fund tokens, representing your proportional ownership in the diversified fund.
* **Community Governance:** Participate in key decisions, including asset rebalancing and fee structure changes, through a transparent voting mechanism.
* **Automated Rebalancing:** The fund can automatically adjust its asset allocations based on predefined strategies and successful governance proposals.
* **Performance Tracking:** Includes logic for tracking fund performance and potentially distributing performance fees.
* **Transparent Operations:** All fund activities, including deposits, withdrawals, and governance votes, are recorded on the blockchain.
* **Management & Performance Fees:** Incorporates mechanisms for calculating and applying management and performance fees to ensure sustainable fund operation.

---

## Smart Contract Details

The DefiPulse smart contract is written in Clarity and defines the core logic for the decentralized investment fund.

### Constants

* `CONTRACT-OWNER`: The deployer of the contract.
* `ERR-OWNER-ONLY` (u100): Returned when an action can only be performed by the contract owner.
* `ERR-NOT-TOKEN-OWNER` (u101): Returned if the sender is not the owner of the fund tokens.
* `ERR-INSUFFICIENT-BALANCE` (u102): Returned for insufficient token balance during withdrawals.
* `ERR-INVALID-AMOUNT` (u103): Returned for invalid deposit amounts or proposal parameters.
* `ERR-FUND-PAUSED` (u104): Returned when attempting operations while the fund is paused.
* `ERR-PROPOSAL-NOT-FOUND` (u105): Returned when a proposal ID does not exist.
* `ERR-ALREADY-VOTED` (u106): Returned if a user tries to vote more than once on a proposal.
* `ERR-VOTING-PERIOD-ENDED` (u107): Returned when trying to vote after the proposal's voting period has ended.
* `ERR-INSUFFICIENT-VOTING-POWER` (u108): Returned when a user has no fund tokens to vote or insufficient votes for quorum/approval.

### Fungible Token

* `fund-token`: The fungible token representing shares in the investment fund.
    * `TOKEN-NAME`: "DeFi ETF Token"
    * `TOKEN-SYMBOL`: "DETF"
    * `TOKEN-DECIMALS`: u6

### Data Maps and Variables

* `fund-paused` (bool): A flag indicating if the fund operations are paused. Defaults to `false`.
* `total-fund-value` (uint): Tracks the total value of assets held by the fund in STX.
* `management-fee-rate` (uint): The annual management fee rate in basis points (e.g., `u200` for 2%).
* `performance-fee-rate` (uint): The performance fee rate in basis points (e.g., `u1000` for 10%).
* `min-deposit` (uint): The minimum amount of STX required for a deposit (e.g., `u1000000` for 1 STX).
* `proposal-counter` (uint): A counter for unique proposal IDs.
* `user-deposits` (map `principal` to `uint`): Stores the total STX deposited by each user.
* `user-last-deposit-block` (map `principal` to `uint`): Records the block height of a user's last deposit.
* `asset-allocations` (map `{ asset: (string-ascii 10) }` to `{ target-percentage: uint, current-amount: uint, last-rebalance-block: uint }`): Stores the target percentage, current amount, and last rebalance block for each asset in the fund.
* `proposals` (map `uint` to `{ proposer: principal, title: (string-ascii 50), description: (string-ascii 200), proposal-type: (string-ascii 20), target-value: uint, votes-for: uint, votes-against: uint, end-block: uint, executed: bool }`): Stores details of all governance proposals.
* `votes` (map `{ proposal-id: uint, voter: principal }` to `bool`): Tracks whether a user has voted on a specific proposal to prevent double voting.

### Private Functions

* `(calculate-management-fee (user-balance uint) (blocks-elapsed uint))`: Calculates the management fee based on the user's balance and the time elapsed.
* `(get-token-price)`: Calculates the current price of one fund token in STX, based on the total fund value and the total supply of fund tokens.
* `(is-valid-proposal (proposal-type (string-ascii 20)) (target-value uint))`: Validates the type and target value of a new proposal.

### Public Functions

* `(initialize-fund)`: Initializes the fund with initial asset allocations (e.g., 60% STX, 40% STABLE). Can only be called by the `CONTRACT-OWNER`.
* `(deposit (amount uint))`: Allows users to deposit STX into the fund and receive `fund-token`s in return.
* `(withdraw (token-amount uint))`: Allows users to burn their `fund-token`s and withdraw the equivalent amount of STX from the fund.
* `(create-proposal (title (string-ascii 50)) (description (string-ascii 200)) (proposal-type (string-ascii 20)) (target-value uint))`: Enables users holding fund tokens to create new governance proposals.
* `(vote (proposal-id uint) (support bool))`: Allows users to vote for or against an active proposal. Their voting power is proportional to their `fund-token` balance.
* `(execute-advanced-rebalancing (proposal-id uint))`: Executes a rebalancing proposal if it has met the quorum and approval thresholds and the voting period has ended. This function includes logic for calculating and distributing performance fees.

### Read-Only Functions

* `(get-fund-info)`: Returns a tuple containing the `total-fund-value`, `token-supply`, `token-price`, `paused` status, `management-fee-rate`, and `performance-fee-rate`.
* `(get-user-balance (user principal))`: Returns the `fund-token` balance of a specific user.
* `(get-proposal (proposal-id uint))`: Retrieves the details of a specific governance proposal by its ID.

---

## How to Use

1.  **Deploy the Contract:** The contract needs to be deployed on the Stacks blockchain by the designated `CONTRACT-OWNER`.
2.  **Initialize the Fund:** The `CONTRACT-OWNER` must call `initialize-fund` to set up the initial asset allocations.
3.  **Deposit STX:** Users can call the `deposit` function with the desired STX amount to receive `DETF` tokens. Ensure your deposit meets the `min-deposit` requirement.
4.  **Participate in Governance:**
    * **Create Proposals:** If you hold `DETF` tokens, you can create proposals using `create-proposal` to suggest changes to asset allocations, fees, or other fund parameters.
    * **Vote on Proposals:** Use the `vote` function to cast your vote on active proposals. Your voting power is determined by your `DETF` token balance.
5.  **Rebalance the Fund:** Once a rebalance proposal passes the voting thresholds and its voting period ends, the `execute-advanced-rebalancing` function can be called to enact the changes.
6.  **Withdraw STX:** Users can call the `withdraw` function to burn their `DETF` tokens and retrieve their proportional share of STX from the fund.

---

## Fees

DefiPulse incorporates two types of fees:

* **Management Fee:** An annual fee (`management-fee-rate`) is calculated based on the time elapsed and a user's balance. This fee helps cover the operational costs of the fund.
* **Performance Fee:** A performance fee (`performance-fee-rate`) is applied if the fund's performance exceeds a certain threshold (currently 10% profit in `execute-advanced-rebalancing`). This incentivizes effective fund management.

---

## Governance

DefiPulse operates as a Decentralized Autonomous Organization (DAO) where `DETF` token holders govern the fund. Key aspects of governance include:

* **Proposal Creation:** Any `DETF` holder can create proposals for fund-related decisions.
* **Voting:** `DETF` holders vote on proposals, with their voting power directly proportional to their token holdings.
* **Quorum and Approval:** Proposals require a minimum `quorum-threshold` (25% of total supply) of votes and an `approval-threshold` (60% of total votes) to pass.
* **Execution:** Passed proposals, particularly rebalancing proposals, are then executed by calling the `execute-advanced-rebalancing` function.

---

## Errors

The contract defines a set of error codes to provide clear feedback on failed transactions. Refer to the **Constants** section for a list of error codes and their meanings.

---

## Contributing

I welcome contributions to DefiPulse! If you have ideas for improvements, bug fixes, or new features, please feel free to:

1.  Fork the repository.
2.  Create a new branch for your changes.
3.  Submit a pull request with a detailed description of your contributions.

Before contributing, please ensure your code adheres to Clarity best practices and includes appropriate tests.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for more details.

---

## Contact

For any inquiries or support, please open an issue in the GitHub repository.
