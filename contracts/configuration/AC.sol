// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessControl} from "../dependencies/openzeppelin/contracts/AccessControl.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {IAC} from "../interfaces/IAC.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";

contract AC is AccessControl, IAC {
    bytes32 public constant override ISOLATED_ADMIN_ROLE = keccak256("ISOLATED_ADMIN");
    bytes32 public constant override CROSS_ADMIN_ROLE = keccak256("CROSS_ADMIN");
    bytes32 public constant override PAIR_ADMIN_ROLE = keccak256("PAIR_ADMIN");
    bytes32 public constant override EXECUTOR_ROLE = keccak256("EXECUTOR");
    bytes32 public constant override LIQUIDATOR_ROLE = keccak256("LIQUIDATOR");
    bytes32 public constant override VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN");
    bytes32 public constant override CAPITAL_PROVIDER_ROLE = keccak256("CAPITAL_PROVIDER");

    IAddressesProvider public immutable FLAEX_PROVIDER;

    /**
     * @dev Constructor
     * @param provider The address of the PoolAddressesProvider
     */
    constructor(IAddressesProvider provider) {
        FLAEX_PROVIDER = provider;
        address ACAdmin = provider.getSuperAdmin();
        require(ACAdmin != address(0), ErrorList.SUPER_ADMIN_CANNOT_BE_ZERO);
        _grantRole(DEFAULT_ADMIN_ROLE, ACAdmin);
    }

    /// @inheritdoc IAC
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    /// @inheritdoc IAC
    function addIsolatedAdmin(address admin) external override {
        grantRole(ISOLATED_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function removeIsolatedAdmin(address admin) external override {
        revokeRole(ISOLATED_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function isIsolatedAdmin(address admin) external view override returns (bool) {
        return hasRole(ISOLATED_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function addCrossAdmin(address admin) external override {
        grantRole(CROSS_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function removeCrossAdmin(address admin) external override {
        revokeRole(CROSS_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function isCrossAdmin(address admin) external view override returns (bool) {
        return hasRole(CROSS_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function addPairAdmin(address admin) external override {
        grantRole(PAIR_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function removePairAdmin(address admin) external override {
        revokeRole(PAIR_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function isPairAdmin(address admin) external view override returns (bool) {
        return hasRole(PAIR_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IAC
    function addExecutorAdmin(address executor) external override {
        grantRole(EXECUTOR_ROLE, executor);
    }

    /// @inheritdoc IAC
    function removeExecutorAdmin(address executor) external override {
        revokeRole(EXECUTOR_ROLE, executor);
    }

    /// @inheritdoc IAC
    function isExecutorAdmin(address executor) external view override returns (bool) {
        return hasRole(EXECUTOR_ROLE, executor);
    }

    /// @inheritdoc IAC
    function addLiquidator(address liquidator) external override {
        grantRole(LIQUIDATOR_ROLE, liquidator);
    }

    /// @inheritdoc IAC
    function removeLiquidator(address liquidator) external override {
        revokeRole(LIQUIDATOR_ROLE, liquidator);
    }

    /// @inheritdoc IAC
    function isLiquidator(address liquidator) external view override returns (bool) {
        return hasRole(LIQUIDATOR_ROLE, liquidator);
    }

    /// @inheritdoc IAC
    function addVaultAdmin(address vaultAdmin) external override {
        grantRole(VAULT_ADMIN_ROLE, vaultAdmin);
    }

    /// @inheritdoc IAC
    function removeVaultAdmin(address vaultAdmin) external override {
        revokeRole(VAULT_ADMIN_ROLE, vaultAdmin);
    }

    /// @inheritdoc IAC
    function isVaultAdmin(address vaultAdmin) external view override returns (bool) {
        return hasRole(VAULT_ADMIN_ROLE, vaultAdmin);
    }

    /// @inheritdoc IAC
    function addCapitalProviderAdmin(address capitalProviderAdmin) external override {
        grantRole(CAPITAL_PROVIDER_ROLE, capitalProviderAdmin);
    }

    /// @inheritdoc IAC
    function removeCapitalProviderAdmin(address capitalProviderAdmin) external override {
        revokeRole(CAPITAL_PROVIDER_ROLE, capitalProviderAdmin);
    }

    /// @inheritdoc IAC
    function isCapitalProviderAdmin(address capitalProviderAdmin) external view override returns (bool) {
        return hasRole(CAPITAL_PROVIDER_ROLE, capitalProviderAdmin);
    }
}
