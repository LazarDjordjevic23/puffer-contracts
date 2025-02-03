// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { PufferVaultV2 } from "./PufferVaultV2.sol";
import { IStETH } from "./interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "./interface/Lido/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "./interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "./interface/EigenLayer/IStrategy.sol";
import { IDelegationManager } from "./interface/EigenLayer/IDelegationManager.sol";
import { IWETH } from "./interface/Other/IWETH.sol";
import { IPufferVaultV3 } from "./interface/IPufferVaultV3.sol";
import { IPufferOracle } from "./interface/IPufferOracle.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";


/**
 * @title PufferVaultV3
 * @dev Implementation of the PufferVault version 3 contract.
 * @notice This contract extends the functionality of PufferVaultV2 with additional features for reward minting and bridging.
 * @custom:security-contact security@puffer.fi
 */
contract PufferVaultV3 is PufferVaultV2, IPufferVaultV3, ReentrancyGuardUpgradeable {
    using Math for uint256;

    /**
     * @dev Storage gap to allow for future upgrades without storage collisions.
     */
    uint256[50] private __gap;

    /**
     * @notice Initializes the PufferVaultV3 contract.
     * @param stETH Address of the stETH token contract.
     * @param weth Address of the WETH token contract.
     * @param lidoWithdrawalQueue Address of the Lido withdrawal queue contract.
     * @param stETHStrategy Address of the stETH strategy contract.
     * @param eigenStrategyManager Address of the EigenLayer strategy manager contract.
     * @param oracle Address of the PufferOracle contract.
     * @param delegationManager Address of the delegation manager contract.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(
        IStETH stETH,
        IWETH weth,
        ILidoWithdrawalQueue lidoWithdrawalQueue,
        IStrategy stETHStrategy,
        IEigenLayer eigenStrategyManager,
        IPufferOracle oracle,
        IDelegationManager delegationManager
    ) PufferVaultV2(stETH, weth, lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager, oracle, delegationManager) {
        _disableInitializers();
    }

    /**
     * @notice Initializes the PufferVaultV3 contract.
     * @dev This function should be called during the upgrade process.
     * It reinitializes the contract and sets up any new state variables.
     */
    function initializeV3() external reinitializer(3) {
        __ReentrancyGuard_init();
    }

//    /**
//     * @notice Function is initializing the state of the contract
//     */
//    function initialize() external initializer {
//        __ReentrancyGuard_init();
//    }

    /**
     * @notice Returns the total assets held by the vault.
     * @dev Returns the total assets held by the vault, including ETH held in the eigenpods as a result of receiving rewards.
     * See {PufferVaultV2-totalAssets}. for more information.
     * @return The total assets held by the vault.
     */
    function totalAssets() public view virtual override returns (uint256) {
        return (super.totalAssets() + getTotalRewardMintAmount() - getTotalRewardDepositAmount());
    }

    /**
     * @inheritdoc IPufferVaultV3
     */
    function getTotalRewardMintAmount() public view returns (uint256) {
        VaultStorage storage $ = _getPufferVaultStorage();
        return $.totalRewardMintAmount;
    }

    /**
     * @inheritdoc IPufferVaultV3
     */
    function getTotalRewardDepositAmount() public view returns (uint256) {
        VaultStorage storage $ = _getPufferVaultStorage();
        return $.totalRewardDepositAmount;
    }

    /**
     * @notice Mints pufETH rewards for the L1RewardManager contract and returns the exchange rate.
     * @dev Restricted to L1RewardManager
     */
    function mintRewards(uint256 rewardsAmount)
        external
        restricted
        returns (uint256 ethToPufETHRate, uint256 pufETHAmount)
    {
        ethToPufETHRate = convertToShares(1 ether);
        // calculate the shares using this formula since calling convertToShares again is costly
        pufETHAmount = ethToPufETHRate.mulDiv(rewardsAmount, 1 ether, Math.Rounding.Floor);

        VaultStorage storage $ = _getPufferVaultStorage();

        uint256 previousRewardsAmount = $.totalRewardMintAmount;
        uint256 newTotalRewardsAmount = previousRewardsAmount + rewardsAmount;
        $.totalRewardMintAmount = newTotalRewardsAmount;

        emit UpdatedTotalRewardsAmount(previousRewardsAmount, newTotalRewardsAmount, 0);

        // msg.sender is the L1RewardManager contract
        _mint(msg.sender, pufETHAmount);

        return (ethToPufETHRate, pufETHAmount);
    }

    /**
     * @notice Deposits the rewards amount to the vault and updates the total reward deposit amount.
     * @dev Restricted to PufferModuleManager
     */
    function depositRewards() external payable restricted {
        VaultStorage storage $ = _getPufferVaultStorage();
        uint256 previousRewardsAmount = $.totalRewardDepositAmount;
        uint256 newTotalRewardsAmount = previousRewardsAmount + msg.value;
        $.totalRewardDepositAmount = newTotalRewardsAmount;

        emit UpdatedTotalRewardsAmount(previousRewardsAmount, newTotalRewardsAmount, msg.value);
    }

    /**
     * @notice Reverts the `mintRewards` action.
     * @dev Restricted to L1RewardManager
     */
    function revertMintRewards(uint256 pufETHAmount, uint256 ethAmount) external restricted {
        VaultStorage storage $ = _getPufferVaultStorage();

        uint256 previousMintAmount = $.totalRewardMintAmount;
        // nosemgrep basic-arithmetic-underflow
        uint256 newMintAmount = previousMintAmount - ethAmount;
        $.totalRewardMintAmount = newMintAmount;

        emit UpdatedTotalRewardsAmount(previousMintAmount, newMintAmount, 0);

        // msg.sender is the L1RewardManager contract
        _burn(msg.sender, pufETHAmount);
    }

    //////////////////// NEWLY ADDED FUNCTIONALITY ///////////////////

    // Maximum grant amount
    uint256 public maxGrantAmount;
    // Array that holds all the recipients
    address[] private recipients;
    // Id of every recipient in the recipients array
    mapping(address => uint256) public idOfRecipient;
    // Mapping that will holds if addresses can receive grants
    mapping(address => bool) private isRecipient;

    // Event emitted when the maxGrantAmount is updated
    event MaxGrantAmountUpdated(uint256 indexed newAmount);
    // Event emitted when the grant recipient is added
    event AddRecipient(address indexed recipient);
    // Event emitted when the grant recipient is removed
    event RemoveRecipient(address indexed recipient);
    // Events for grants
    event GrantPaid(address indexed recipient, uint256 indexed amount, bool indexed asWETH);

    /**
     * @notice Returns if address can receive the grants
     * @param  grantRecipient Address that needs to be checked
     * TODO: possible add specific role to fetch the private info,
        maybe backend specific address that can fetch this
     */
    function getIsRecipient(address grantRecipient) public restricted returns(bool){
        return isRecipient[grantRecipient];
    }

    /**
     * @notice Returns addresses that are recipients
     * @param start - beginning index of array
     * @param end - ending index of array
     * TODO: possible add specific role to fetch the private info,
        maybe backend specific address that can fetch this
     */
    function getRecipients(uint256 start, uint256 end) public restricted returns(address[] memory){
        uint256 nofRecipients = getNofRecipients();
        address[] memory batchRecipients;

        if (nofRecipients > 0){
            require(start < end, "Start is bigger than end index");
            require(end <= nofRecipients, "End index is bigger than actual array");

            batchRecipients = new address[](end - start);

            for (uint256 i = start; i < end; i++) {
                batchRecipients[i - start] = recipients[i];
            }
        }

        return batchRecipients;
    }

    /**
     * @notice Returns the number of recipients
     */
    function getNofRecipients() public returns(uint256){ return recipients.length; }

    function _hasSufficientFunds(uint256 amount, bool asWETH) internal view returns (bool) {
        if (asWETH) {
            // Check if there is enough WETH after accounting for reserved WETH
            uint256 wethBalance = _WETH.balanceOf(address(this));
            uint256 reservedWETH = _calculateReservedWETH();
            return wethBalance >= (amount + reservedWETH);
        } else {
            // Check if there is enough ETH after accounting for reserved ETH
            uint256 ethBalance = address(this).balance;
            uint256 reservedETH = _calculateReservedETH();
            return ethBalance >= (amount + reservedETH);
        }
    }

//    function _calculateReservedFunds() internal view returns (uint256) {
//        // 1. Pending Lido ETH Withdrawals
//        uint256 pendingLidoETH = getPendingLidoETHAmount();
//
//        // 2. EigenLayer Backing ETH
//        uint256 eigenLayerBackingETH = getELBackingEthAmount();
//
//        // 3. Locked ETH in PufferOracle
//        uint256 lockedEthInPufferOracle = PUFFER_ORACLE.getLockedEthAmount();
//
//        // 4. ETH and WETH Reserved for Withdrawals
//        uint256 ethBalanceReservedForWithdrawals = address(this).balance;
//        uint256 wethBalanceReservedForWithdrawals = _WETH.balanceOf(address(this));
//
//        // Total Reserved Funds
//        uint256 totalReservedFunds = pendingLidoETH
//        + eigenLayerBackingETH
//        + lockedEthInPufferOracle
//        + ethBalanceReservedForWithdrawals
//        + wethBalanceReservedForWithdrawals;
//
//        return totalReservedFunds;
//    }

    function _calculateReservedWETH() internal view returns (uint256) {
        // 1. WETH Reserved for Withdrawals
        uint256 wethBalanceReservedForWithdrawals = _WETH.balanceOf(address(this));

        // Total Reserved WETH
        return wethBalanceReservedForWithdrawals;
    }

    function _calculateReservedETH() internal view returns (uint256) {
        // 1. Pending Lido ETH Withdrawals
        uint256 pendingLidoETH = getPendingLidoETHAmount();

        // 2. EigenLayer Backing ETH
        uint256 eigenLayerBackingETH = getELBackingEthAmount();

        // 3. Locked ETH in PufferOracle
        uint256 lockedEthInPufferOracle = PUFFER_ORACLE.getLockedEthAmount();

        // 4. ETH Reserved for Withdrawals
        uint256 ethBalanceReservedForWithdrawals = address(this).balance;

        // Total Reserved ETH
        uint256 totalReservedETH = pendingLidoETH
        + eigenLayerBackingETH
        + lockedEthInPufferOracle
        + ethBalanceReservedForWithdrawals;

        return totalReservedETH;
    }

    /**
     * @notice Function is Paying out the grants
     * @param
     * @param
     */
    function payGrant(
        address grantRecipient,
        uint256 amount,
        bool asWETH
    ) external restricted nonReentrant {
        require(amount > 0 && amount <= maxGrantAmount, "Invalid grant amount");
        require(isRecipient[grantRecipient], "Recipient not allowed");
        require(_hasSufficientFunds(amount), "Insufficient funds for grant");

        if (asWETH) {
            // Transfer WETH
            require(_WETH.transfer(recipient, amount), "WETH transfer failed");
        } else {
            // Transfer ETH
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        }

        emit GrantPaid(recipient, amount, asWETH);
    }

    /**
     * @notice Updates the maximum grant amount.
     * @param newMaxGrantAmount The new max grant amount to set.
     * @dev Only callable by the admin.
     */
    function setMaxGrantAmount(uint256 newMaxGrantAmount) external restricted {
        maxGrantAmount = newMaxGrantAmount;
        emit MaxGrantAmountUpdated(maxGrantAmount);
    }

    /**
     * @notice Updates who can receive the grant
     * @param  grantRecipient Address that will be eligible for the grant.
     * @dev Only callable by the admin.
     */
    function addRecipient(address grantRecipient) external restricted {
        require(grantRecipient != address(0x0), "Recipient is not valid address");
        if (!isRecipient[grantRecipient]) {
            // Add recipient to the system
            idOfRecipient[grantRecipient] = getNofRecipients();
            recipients.push(grantRecipient);
            isRecipient[grantRecipient] = true;

            emit AddRecipient(grantRecipient);
        }
    }

    /**
     * @notice Removing the recipient from grants
     * @param  grantRecipient Address that will be eligible for the grant.
     * @dev Only callable by the admin.
     */
    function removeRecipient(address grantRecipient) external restricted {
        require(grantRecipient != address(0x0), "Recipient is not valid address");

        uint256 nofRecipients = getNofRecipients();
        if (nofRecipients > 0){
            if (isRecipient[grantRecipient]) {

                uint256 userIndex = idOfRecipient[grantRecipient];
                uint256 lastIndex = nofRecipients - 1;

                // Swap if not the last user
                if (userIndex != lastIndex) {
                    address lastUser = recipients[lastIndex];
                    recipients[userIndex] = lastUser;
                    idOfRecipient[lastUser] = userIndex;
                }

                // Remove the participant
                recipients.pop();
                delete idOfRecipient[grantRecipient];
                isRecipient[grantRecipient] = false;

                emit RemoveRecipient(grantRecipient);
            }
        }
    }
}
