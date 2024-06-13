// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "../dependencies/openzeppelin/upgradability/Initializable.sol";

import {ReentrancyGuard} from "../libraries/utils/ReentrancyGuard.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {IAC} from "../interfaces/IAC.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";
import {VaultStorage} from "../storage/VaultStorage.sol";

import {ICreditDelegationToken} from "@aave/core-v3/contracts/interfaces/ICreditDelegationToken.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {WadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";

/**
 * @title Vault Contract
 * @author flaex
 * @notice Vault holds aToken, debtToken and assets
 * @dev Vault should only define basic functions and leaves logic/validation check to other contracts.
 */

contract Vault is Initializable, VaultStorage, IVault, ReentrancyGuard {
    using WadRayMath for uint256;

    IAddressesProvider public immutable FLAEX_PROVIDER;

    /// @dev only isolated admin can call
    modifier onlyVaultAdmin() {
        _onlyVaultAdmin();
        _;
    }

    function _onlyVaultAdmin() internal view virtual {
        IAC AC = IAC(FLAEX_PROVIDER.getAC());
        require(AC.isVaultAdmin(msg.sender), ErrorList.CALLER_NOT_VAULT_ADMIN);
    }

    /// @dev only Margin can call
    modifier onlyMargin() {
        _onlyMargin();
        _;
    }

    function _onlyMargin() internal view virtual {
        require(
            msg.sender == FLAEX_PROVIDER.getIsolatedMargin() ||
                msg.sender == FLAEX_PROVIDER.getCrossMargin(),
            ErrorList.INVALID_MARGIN
        );
    }

    /// @dev only Margin can call
    modifier onlyCapitalProvider() {
        _onlyCapitalProvider();
        _;
    }

    function _onlyCapitalProvider() internal view virtual {
        require(
            msg.sender == FLAEX_PROVIDER.getCapitalProvider(),
            ErrorList.INVALID_CAPITAL_PROVIDER
        );
    }

    /**
     * @dev Constructor.
     * @param provider The address of the AddressesProvider contract
     * @param stablecoin USDC

     */
    constructor(IAddressesProvider provider, address stablecoin) {
        FLAEX_PROVIDER = provider;
        _eligibleStablecoin = stablecoin;
    }

    /**
     * @notice Initializes.
     * @dev Function is invoked by the proxy contract
     * @param provider The address of the PoolAddressesProvider
     */

    function initialize(
        IAddressesProvider provider
    ) external virtual initializer {
        require(provider == FLAEX_PROVIDER, ErrorList.INVALID_ADDRESS_PROVIDER);
    }

    function getEligibleStablecoin()
        external
        view
        virtual
        override
        returns (address)
    {
        return _eligibleStablecoin;
    }

    function getScaledCommissionFeeCp()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _scaledCom.cp;
    }

    // function decreaseCommissionFeeCp(uint256 amount, address to) external virtual override onlyCapitalProvider {
    //     uint256 currentCp = _scaledCom.cp;
    //     uint256 scaledAmount = amount.rayDiv(
    //         IPool(FLAEX_PROVIDER.getAavePool()).getReserveNormalizedIncome(_eligibleStablecoin)
    //     );
    //     require(scaledAmount <= currentCp, ErrorList.INVALID_AMOUNT);
    //     _scaledCom.cp -= scaledAmount;

    //     _withdraw(_eligibleStablecoin, amount, to);
    // }

    function creditDelegateIsolate(
        address debtToken,
        uint256 amount
    ) external virtual override onlyVaultAdmin {
        ICreditDelegationToken(debtToken).approveDelegation(
            FLAEX_PROVIDER.getIsolatedMargin(),
            amount
        );
    }

    function creditDelegateCross(
        address debtToken,
        uint256 amount
    ) external virtual override onlyVaultAdmin {
        ICreditDelegationToken(debtToken).approveDelegation(
            FLAEX_PROVIDER.getCrossMargin(),
            amount
        );
    }

    function withdrawToMargin(
        address asset,
        uint256 amount,
        address to
    ) external virtual override onlyMargin {
        _withdraw(asset, amount, to);
    }

    function withdrawToCapitalProvider(
        uint256 amount,
        address to
    ) external virtual override onlyCapitalProvider {
        _withdraw(_eligibleStablecoin, amount, to);
    }

    function _withdraw(address asset, uint256 amount, address to) private {
        IPool(FLAEX_PROVIDER.getAavePool()).withdraw(asset, amount, to);
    }

    function increaseCom(
        uint256 commission,
        uint256 pr
    ) external virtual override onlyMargin {
        _scaledCom.cp += (commission - pr);
        _scaledCom.pr += pr;
    }

    function decreaseCommissionFeePr(
        uint256 amount,
        address to
    ) external virtual override onlyMargin {
        uint256 currentPr = _scaledCom.pr;
        uint256 scaledAmount = amount.rayDiv(
            IPool(FLAEX_PROVIDER.getAavePool()).getReserveNormalizedIncome(
                _eligibleStablecoin
            )
        );
        require(scaledAmount <= currentPr, ErrorList.INVALID_AMOUNT);
        _scaledCom.pr -= scaledAmount;

        _withdraw(_eligibleStablecoin, amount, to);
    }

    function increaseLiquidationIncentiveProtocol(
        address asset,
        uint256 scaledIncentive
    ) external virtual override onlyMargin {
        _liquidationIncentiveProtocol[asset] += scaledIncentive;
    }

    function decreaseLiquidationIncentiveProtocol(
        address asset,
        uint256 incentive,
        address to
    ) external virtual override onlyMargin {
        uint256 currentIncentive = _liquidationIncentiveProtocol[asset];
        uint256 scaledIncentive = incentive.rayDiv(
            IPool(FLAEX_PROVIDER.getAavePool()).getReserveNormalizedIncome(
                asset
            )
        );

        require(scaledIncentive <= currentIncentive, ErrorList.INVALID_AMOUNT);
        _liquidationIncentiveProtocol[asset] -= scaledIncentive;

        _withdraw(asset, incentive, to);
    }
}
