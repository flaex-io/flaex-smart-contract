// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAddressesProvider} from "./IAddressesProvider.sol";

interface IAC {
    function FLAEX_PROVIDER() external view returns (IAddressesProvider);

    function ISOLATED_ADMIN_ROLE() external view returns (bytes32);

    function CROSS_ADMIN_ROLE() external view returns (bytes32);

    function PAIR_ADMIN_ROLE() external view returns (bytes32);

    function EXECUTOR_ROLE() external view returns (bytes32);

    function LIQUIDATOR_ROLE() external view returns (bytes32);

    function VAULT_ADMIN_ROLE() external view returns (bytes32);

    function CAPITAL_PROVIDER_ROLE() external view returns (bytes32);

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function addIsolatedAdmin(address admin) external;

    function removeIsolatedAdmin(address admin) external;

    function isIsolatedAdmin(address admin) external view returns (bool);

    function addCrossAdmin(address admin) external;

    function removeCrossAdmin(address admin) external;

    function isCrossAdmin(address admin) external view returns (bool);

    function addPairAdmin(address admin) external;

    function removePairAdmin(address admin) external;

    function isPairAdmin(address admin) external view returns (bool);

    function addExecutorAdmin(address executor) external;

    function removeExecutorAdmin(address executor) external;

    function isExecutorAdmin(address executor) external view returns (bool);

    function addLiquidator(address liquidator) external;

    function removeLiquidator(address liquidator) external;

    function isLiquidator(address liquidator) external view returns (bool);

    function addVaultAdmin(address vaultAdmin) external;

    function removeVaultAdmin(address vaultAdmin) external;

    function isVaultAdmin(address vaultAdmin) external view returns (bool);

    function addCapitalProviderAdmin(address capitalProviderAdmin) external;

    function removeCapitalProviderAdmin(address capitalProviderAdmin) external;

    function isCapitalProviderAdmin(address capitalProviderAdmin) external view returns (bool);
}
