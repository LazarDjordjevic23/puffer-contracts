# PufferVaultV3 Contract

## Overview

The `PufferVaultV3` contract is an upgrade to the `PufferVaultV2` contract, adding new functionality related to grant management, reward minting, and additional improvements. This contract extends the PufferVaultV2 system with the ability to manage grant recipients and handle grant payments in both ETH and WETH. The system ensures that only eligible recipients can receive grants, and it is equipped with proper access controls, sufficient fund checks, and non-reentrancy protection.

## Features

### 1. Grant Management
- **Grant recipients:** The contract allows for the addition and removal of eligible grant recipients.
- **Grant payments:** Grants can be paid in ETH or WETH to eligible recipients, subject to a maximum grant amount.
- **Grant validation:** The contract checks if recipients are eligible and ensures sufficient funds are available before making a payment.

### 2. Reward Minting and Bridging
- **Minting rewards:** The contract allows for the minting of `pufETH` rewards based on certain criteria.
- **Reward deposits:** Rewards can be deposited into the vault, contributing to the total assets.

### 3. Security
- **Non-reentrancy:** The contract is protected by the `ReentrancyGuardUpgradeable` to prevent reentrancy attacks.
- **Sufficient funds check:** Ensures the contract has enough ETH or WETH to process grants before making any payouts.
- **Initializable contract:** Ensures that the contract can only be initialized once during the upgrade process.

## Contract Components

### 1. Constructor & Initialization
- The constructor initializes the contract with addresses for various tokens, strategies, and managers.
- `initializeV3`: A special function that can only be called once during the upgrade process to initialize state variables and ensure proper contract setup.

### 2. Grant System
- **Grant Payments:**
  - `payGrant`: Allows the payment of grants to recipients in either ETH or WETH.
  - Validates the recipient, checks if the contract has sufficient funds, and ensures that the grant amount does not exceed the maximum allowed.
  
- **Grant Recipients Management:**
  - `addRecipient`: Adds a new recipient to the list of eligible recipients.
  - `removeRecipient`: Removes a recipient from the list of eligible recipients.
  
- **Grant Amount Configuration:**
  - `setMaxGrantAmount`: Sets the maximum allowed grant amount.
  - `getIsRecipient`: Checks if an address is eligible to receive grants.
  - `getRecipients`: Retrieves a list of eligible grant recipients in a specified range.
  
### 3. Security Features
- **Non-reentrancy:** Uses `nonReentrant` modifier to prevent reentrancy attacks during the grant payment process.
- **Sufficient Funds Check:** The contract checks if enough ETH/WETH is available to cover the grant payments, considering reserved funds.
- **Wrap/Unwrap WETH:** Internal functions to convert WETH to ETH and vice versa as needed when making grant payments.

## Events
The following events are emitted to track important changes:
- `MaxGrantAmountUpdated`: Emitted when the maximum grant amount is updated.
- `AddRecipient`: Emitted when a new recipient is added.
- `RemoveRecipient`: Emitted when a recipient is removed.
- `GrantPaid`: Emitted when a grant is successfully paid to a recipient.

## Functions

### 1. Grant System

#### `payGrant(address grantRecipient, uint256 amount, bool asWETH)`
- Pays a grant to a recipient in either ETH or WETH.
- Ensures the recipient is eligible and the contract has sufficient funds.

#### `addRecipient(address grantRecipient)`
- Adds a recipient to the grant system.
- Only callable by the admin.

#### `removeRecipient(address grantRecipient)`
- Removes a recipient from the grant system.
- Only callable by the admin.

#### `setMaxGrantAmount(uint256 newMaxGrantAmount)`
- Updates the maximum allowed grant amount.
- Only callable by the admin.

### 2. Utility Functions

#### `getIsRecipient(address grantRecipient)`
- Checks if an address is eligible to receive grants.

#### `getRecipients(uint256 start, uint256 end)`
- Retrieves a list of eligible recipients in the specified range.

#### `getNofRecipients()`
- Returns the total number of eligible grant recipients.

### 3. Internal Functions

#### `_hasSufficientFunds(uint256 amount)`
- Checks if the contract has enough ETH/WETH available to cover the requested grant amount.

#### `_unwrapETH(uint256 assets)`
- Converts WETH to ETH if needed.

#### `_wrapETH(uint256 amount)`
- Converts ETH to WETH if needed.

## Security Considerations

- The contract uses `ReentrancyGuardUpgradeable` to prevent reentrancy attacks.
- The `restricted` modifier ensures that only authorized addresses (e.g., admins) can perform certain actions, such as adding/removing recipients and updating the maximum grant amount.
- Proper checks are in place to ensure that the contract has sufficient funds for any transactions, and reverts if there are insufficient balances.

## Upgrade Process

- **Initialization:** The contract requires an initialization step (`initializeV3`) when upgrading from `PufferVaultV2` to `PufferVaultV3`. This step ensures that the contract's state variables and security mechanisms are properly initialized.
- **Upgrade Authorization:** The upgrade process is authorized through the `_authorizeUpgrade` function, which is restricted and can only be executed by authorized entities.

## License

This contract is licensed under the GPL-3.0 License.

