# Token Vesting Vault

## Project Overview

Token Vesting Vault is a Solidity smart contract that manages the gradual distribution of ERC-20 tokens to beneficiaries.

The project allows the contract owner to create vesting schedules for team members, investors, or advisors. Instead of receiving all tokens immediately, beneficiaries receive them gradually according to a predefined schedule.

The contract supports cliff periods, linear vesting, token releases, schedule revocation, and beneficiary transfers.

## Technologies Used

- Solidity ^0.8.20
- OpenZeppelin Contracts
- Remix IDE
- Solidity Unit Testing
- ERC-20 tokens

## Main Features

**1. Create Vesting Schedules**

The contract owner can create schedules with a beneficiary address, token amount, start time, cliff period, duration, and revocation setting.

**2. Linear Token Vesting**

Tokens become available gradually over time. Before the cliff ends, no tokens can be released. After the vesting duration ends, the full allocation becomes available.

**3. Token Release**

The `release()` function transfers available tokens to the beneficiary. It prevents the same tokens from being released twice.

**4. Schedule Revocation**

The owner can revoke schedules marked as revocable. Unvested tokens return to the owner, while already vested tokens remain available to the beneficiary.

**5. Withdraw Unallocated Tokens**

The owner can withdraw tokens that are not reserved for existing vesting schedules.

**6. Transfer Vesting Schedule**

A beneficiary can transfer their schedule to another address.

**7. View Beneficiary Schedules**

The `schedulesOf()` function returns the schedule IDs associated with a beneficiary.

## Security Model

The contract includes several security mechanisms:

- **Access control:** OpenZeppelin `Ownable` restricts administrative functions to the owner.
- **Reentrancy protection:** OpenZeppelin `ReentrancyGuard` protects token transfers in `release()`, `revoke()`, and `withdrawUnallocated()`.
- **Safe token transfers:** OpenZeppelin `SafeERC20` is used for ERC-20 token transfers.
- **Balance validation:** The contract checks that sufficient unallocated tokens are available before creating a schedule.
- **Input validation:** Zero addresses, zero token amounts, invalid durations, and cliff periods longer than the duration are rejected.
- **Accounting:** `totalAllocated` tracks tokens reserved for beneficiaries.
- **Revocation protection:** Already vested tokens remain available to beneficiaries after revocation.

The contract assumes a standard ERC-20 token with predictable transfer behavior. Fee-on-transfer and rebasing tokens are not specifically supported.

The contract has not undergone an independent security audit and is intended for educational use.

## Project Structure

```text
src/
├── VestingVault.sol
├── MockToken.sol
├── UnauthorizedCaller.sol
└── tests/
    └── VestingVault_test.sol

README.md
```

- `VestingVault.sol` — main smart contract.
- `MockToken.sol` — ERC-20 token used during testing.
- `UnauthorizedCaller.sol` — helper contract for testing access restrictions.
- `VestingVault_test.sol` — automated Solidity unit tests.

## Testing

The project was tested using the Solidity Unit Testing plugin in Remix IDE.

**Latest test results:**

- Tests passed: 26
- Tests failed: 0
- Testing environment: Remix IDE

The tests cover schedule creation, token balances, vesting calculations, token releases, repeated releases, revocation, access restrictions, invalid inputs, unallocated withdrawals, beneficiary schedule listings, and schedule transfers.

The test suite also checks multiple fixed token amounts. These are deterministic tests, not randomized fuzz tests.

## How to Run the Project

1. Open [Remix IDE](https://remix.ethereum.org/).
2. Create a new workspace or import the project files.
3. Open `src/VestingVault.sol`.
4. Compile the contract using Solidity Compiler with a compatible Solidity 0.8.x version.
5. Deploy `MockToken.sol` using Deploy & Run Transactions.
6. Deploy `VestingVault.sol`, passing the deployed token contract address to its constructor.
7. Transfer test tokens to the deployed VestingVault address.
8. Use `createSchedule()` to create a vesting schedule.
9. Use `vestedAmount()`, `releasable()`, `release()`, and `revoke()` to interact with the schedule.

## Running Automated Tests

1. Enable the **Solidity Unit Testing** plugin in Remix.
2. Set the test directory to `src/tests`.
3. Select `VestingVault_test.sol`.
4. Click **Run**.
5. Review the test results.

## Limitations

- The contract uses block timestamps for vesting calculations.
- The owner has administrative control over schedule creation and revocation.
- Only schedules marked as revocable can be revoked.
- The current test suite does not provide randomized fuzz-testing coverage.
- The project is an educational prototype and should not be used with real funds without further security review.

## Conclusion

This project demonstrates how Solidity and OpenZeppelin can be used to build a token vesting system with gradual token distribution, access control, schedule revocation, and automated testing.
