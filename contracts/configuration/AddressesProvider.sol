// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "../libraries/utils/Ownable.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

contract AddressesProvider is Ownable, IAddressesProvider {
    // Map of registered addresses (identifier => registeredAddress)
    mapping(bytes32 => address) private _Add;

    // Main identifiers
    //Flaex:
    bytes32 private constant AC = "AC";
    bytes32 private constant SUPER_ADMIN = "SUPER_ADMIN";
    bytes32 private constant ISOLATED_MARGIN = "ISOLATED_MARGIN";
    bytes32 private constant CROSS_MARGIN = "CROSS_MARGIN";
    bytes32 private constant VAULT = "VAULT";
    bytes32 private constant CAPITAL_PROVIDER = "CAPITAL_PROVIDER";
    bytes32 private constant FL_TOKEN = "FL_TOKEN";

    bytes32 private constant FUNCTION_EXECUTOR = "FUNCTION_EXECUTOR";

    //AAVE:
    bytes32 private constant AAVE_ADDRESS_PROVIDER = "AAVE_ADDRESS_PROVIDER";

    //Uniswap:
    bytes32 private constant UNISWAP_FACTORY = "UNISWAP_FACTORY";
    bytes32 private constant UNISWAP_PERMIT2 = "UNISWAP_PERMIT2";

    constructor(address _owner) {
        transferOwnership(_owner);
    }

    function Owner() external view virtual override returns (address) {
        return owner();
    }

    /// @inheritdoc IAddressesProvider
    function getAdd(bytes32 id) public view override returns (address) {
        return _Add[id];
    }

    function _setAdd(bytes32 id, address newAddress) internal {
        _Add[id] = newAddress;
    }

    /// @inheritdoc IAddressesProvider
    function getAC() external view override returns (address) {
        return _Add[AC];
    }

    /// @inheritdoc IAddressesProvider
    function setAC(address newAC) external onlyOwner {
        address oldAC = _Add[AC];
        _setAdd(AC, newAC);
        emit ACUpdated(oldAC, newAC);
    }

    /// @inheritdoc IAddressesProvider
    function getSuperAdmin() external view override returns (address) {
        return _Add[SUPER_ADMIN];
    }

    /// @inheritdoc IAddressesProvider
    function setSuperAdmin(address newSuperAdmin) external onlyOwner {
        address oldSuperAdmin = _Add[SUPER_ADMIN];
        _setAdd(SUPER_ADMIN, newSuperAdmin);
        emit SuperAdminUpdated(oldSuperAdmin, newSuperAdmin);
    }

    /// @inheritdoc IAddressesProvider
    function getIsolatedMargin() external view override returns (address) {
        return _Add[ISOLATED_MARGIN];
    }

    /// @inheritdoc IAddressesProvider
    function setIsolatedMargin(address newIsolatedMargin) external onlyOwner {
        address oldIsolatedMargin = _Add[ISOLATED_MARGIN];
        _setAdd(ISOLATED_MARGIN, newIsolatedMargin);
        emit IsolatedMarginUpdated(oldIsolatedMargin, newIsolatedMargin);
    }

    /// @inheritdoc IAddressesProvider
    function getCrossMargin() external view override returns (address) {
        return _Add[CROSS_MARGIN];
    }

    /// @inheritdoc IAddressesProvider
    function setCrossMargin(address newCrossMargin) external onlyOwner {
        address oldCrossMargin = _Add[CROSS_MARGIN];
        _setAdd(CROSS_MARGIN, newCrossMargin);
        emit CrossMarginUpdated(oldCrossMargin, newCrossMargin);
    }

    /// @inheritdoc IAddressesProvider
    function getFunctionExecutor() external view override returns (address) {
        return _Add[FUNCTION_EXECUTOR];
    }

    /// @inheritdoc IAddressesProvider
    function setFunctionExecutor(address newFunctionExecutor) external onlyOwner {
        address oldFunctionExecutor = _Add[FUNCTION_EXECUTOR];
        _setAdd(FUNCTION_EXECUTOR, newFunctionExecutor);
        emit FunctionExecutorUpdated(oldFunctionExecutor, newFunctionExecutor);
    }

    /// @inheritdoc IAddressesProvider
    function getPermit2() external view override returns (address) {
        return _Add[UNISWAP_PERMIT2];
    }

    /// @inheritdoc IAddressesProvider
    function setPermit2(address newPermit2) external onlyOwner {
        address oldPermit2 = _Add[UNISWAP_PERMIT2];
        _setAdd(UNISWAP_PERMIT2, newPermit2);
        emit Permit2Updated(oldPermit2, newPermit2);
    }

    /// @inheritdoc IAddressesProvider
    function getVault() external view override returns (address) {
        return _Add[VAULT];
    }

    /// @inheritdoc IAddressesProvider
    function setVault(address newVault) external onlyOwner {
        address oldVault = _Add[VAULT];
        _setAdd(VAULT, newVault);
        emit VaultUpdated(oldVault, newVault);
    }

    /// @inheritdoc IAddressesProvider
    function getCapitalProvider() external view override returns (address) {
        return _Add[CAPITAL_PROVIDER];
    }

    /// @inheritdoc IAddressesProvider
    function setCapitalProvider(address newCapitalProvider) external onlyOwner {
        address capitalProvider = _Add[CAPITAL_PROVIDER];
        _setAdd(CAPITAL_PROVIDER, newCapitalProvider);
        emit CapitalProviderUpdated(capitalProvider, newCapitalProvider);
    }

    /// @inheritdoc IAddressesProvider
    function getFlToken() external view override returns (address) {
        return _Add[FL_TOKEN];
    }

    /// @inheritdoc IAddressesProvider
    function setFlToken(address newFlToken) external onlyOwner {
        address flToken = _Add[FL_TOKEN];
        _setAdd(FL_TOKEN, newFlToken);
        emit FlTokenUpdated(flToken, newFlToken);
    }

    /// @inheritdoc IAddressesProvider
    // function getAaveProvider() external view override returns (IPoolAddressesProvider) {
    //     return IPoolAddressesProvider(_Add[AAVE_ADDRESS_PROVIDER]);
    // }

    /// @inheritdoc IAddressesProvider
    function setAaveProvider(address newAaveProvider) external onlyOwner {
        address oldAaveProvider = _Add[AAVE_ADDRESS_PROVIDER];
        _setAdd(AAVE_ADDRESS_PROVIDER, newAaveProvider);
        emit AaveProviderUpdated(oldAaveProvider, newAaveProvider);
    }

    /// @inheritdoc IAddressesProvider
    function getAavePool() external view override returns (address) {
        return IPoolAddressesProvider(_Add[AAVE_ADDRESS_PROVIDER]).getPool();
    }

    /// @inheritdoc IAddressesProvider
    function getAaveOracle() external view override returns (address) {
        return IPoolAddressesProvider(_Add[AAVE_ADDRESS_PROVIDER]).getPriceOracle();
    }

    /// @inheritdoc IAddressesProvider
    function getUniswapFactory() external view override returns (address) {
        return _Add[UNISWAP_FACTORY];
    }

    /// @inheritdoc IAddressesProvider
    function setUniswapFactory(address newUniswapFactory) external onlyOwner {
        address oldUniswapFactory = _Add[UNISWAP_FACTORY];
        _setAdd(UNISWAP_FACTORY, newUniswapFactory);
        emit UniswapFactoryUpdated(oldUniswapFactory, newUniswapFactory);
    }
}
