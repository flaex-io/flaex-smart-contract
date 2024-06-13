// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

interface IAddressesProvider {
    event SuperAdminUpdated(address indexed oldAddress, address indexed newAddress);
    event ACUpdated(address indexed oldAddress, address indexed newAddress);
    event IsolatedMarginUpdated(address indexed oldAddress, address indexed newAddress);
    event CrossMarginUpdated(address indexed oldAddress, address indexed newAddress);
    event FunctionExecutorUpdated(address indexed oldAddress, address indexed newAddress);
    event VaultUpdated(address indexed oldAddress, address indexed newAddress);
    event CapitalProviderUpdated(address indexed oldAddress, address indexed newAddress);
    event FlTokenUpdated(address indexed oldAddress, address indexed newAddress);
    event Permit2Updated(address indexed oldAddress, address indexed newAddress);
    event AaveProviderUpdated(address indexed oldAddress, address indexed newAddress);
    event UniswapFactoryUpdated(address indexed oldAddress, address indexed newAddress);

    function Owner() external view returns (address);

    function getAdd(bytes32 id) external view returns (address);

    function getAC() external view returns (address);

    function setAC(address newAC) external;

    function getSuperAdmin() external view returns (address);

    function setSuperAdmin(address newSuperAdmin) external;

    function getIsolatedMargin() external view returns (address);

    function setIsolatedMargin(address newIsolatedMargin) external;

    function getCrossMargin() external view returns (address);

    function setCrossMargin(address newCrossMargin) external;

    function getFunctionExecutor() external view returns (address);

    function setFunctionExecutor(address newFunctionExecutor) external;

    function getVault() external view returns (address);

    function setVault(address newVault) external;

    function getCapitalProvider() external view returns (address);

    function setCapitalProvider(address newCapitalProvider) external;

    function getFlToken() external view returns (address);

    function setFlToken(address newFlToken) external;

    function getPermit2() external view returns (address);

    function setPermit2(address newPermit2) external;

    // function getAaveProvider() external view returns (IPoolAddressesProvider);

    function setAaveProvider(address newAaveProvider) external;

    function getAavePool() external view returns (address);

    function getAaveOracle() external view returns (address);

    function getUniswapFactory() external view returns (address);

    function setUniswapFactory(address newUniswapFactory) external;
}
