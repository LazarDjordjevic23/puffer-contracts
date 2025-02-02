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

/**
 * @title PufferVaultV3
 * @dev Implementation of the PufferVault version 3 contract.
 * @notice This contract extends the functionality of PufferVaultV2 with additional features for reward minting and bridging.
 * @custom:security-contact security@puffer.fi
 */
contract PufferVaultV3 is PufferVaultV2, IPufferVaultV3 {
    using Math for uint256;

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
    // Mapping that will holds if addresses can receive grants
    mapping(address => bool) private recipients;

    // Event emitted when the maxGrantAmount is updated
    event MaxGrantAmountUpdated(uint256 indexed newAmount);
    // Event emitted when the grant recipient is added
    event AddRecipient(address indexed recipient);
    // Event emitted when the grant recipient is removed
    event RemoveRecipient(address indexed recipient);

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
     * @notice Returns if address can receive the grants
     * @param  grantRecipient Address that needs to be checked
     */
    function _isRecipient(address grantRecipient) internal returns(bool){
        return recipients[grantRecipient];
    }

    /**
     * @notice Returns if address can receive the grants
     * @param  grantRecipient Address that needs to be checked
     * TODO: possible add specific role to fetch the private info,
        maybe backend specific address that can fetch this
     */
    function isRecipient(address grantRecipient) public restricted returns(bool){
        return _isRecipient(grantRecipient);
    }

    /**
     * @notice Updates who can receive the grant
     * @param  grantRecipient Address that will be eligible for the grant.
     * @dev Only callable by the admin.
     */
    function addRecipient(address grantRecipient) external restricted {
        require(grantRecipient != address(0x0), "Recipient is not valid address");
        if (!_isRecipient(grantRecipient)) {
            recipients[grantRecipient] = true;
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
        if (_isRecipient(grantRecipient)) {
            recipients[grantRecipient] = false;
            emit RemoveRecipient(grantRecipient);
        }
    }
}
