// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../types/Types.sol";
import {IERC20} from "../../dependencies/openzeppelin/contracts/IERC20.sol";
import {GPv2SafeERC20} from "../../dependencies/gnosis/GPv2SafeERC20.sol";
import {Math} from "../../dependencies/openzeppelin/contracts/Math.sol";
import {ITradePair} from "../../interfaces/ITradePair.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {TradePairConfig} from "../configuration/TradePairConfig.sol";
import {IsolatedLogic} from "./IsolatedLogic.sol";
import {ErrorList} from "../helpers/ErrorList.sol";

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {WadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import "hardhat/console.sol";

import {PoolAddress} from "../../dependencies/v3-periphery/libraries/PoolAddress.sol";

/**
 * @title swap callback library
 * @author flaex
 * @notice implements logic for uniswap v3 callback
 */

library SwapCallback {
    using Math for uint256;
    using WadRayMath for uint256;
    using GPv2SafeERC20 for IERC20;
    using TradePairConfig for Types.tradingPairConfigMap;

    function openLongCallback(Types.executeOpenLongParams memory params, uint256 amountToPay) external {
        // calculate the amount needed to withdraw and to borrow (exlcuding commission fee and gas fee)
        uint256 amountToWithdraw = amountToPay / params.leverage;

        // call supply
        IPool(params.aavePool).supply(params.baseToken, params.baseAmount, params.vault, params.aaveReferralCode);
        // call borrow on the amountToBorrow = amountToPay - amountToWithdraw;
        IPool(params.aavePool).borrow(
            params.quoteToken,
            (amountToPay - amountToWithdraw),
            2, // we assume it's always variable borrow
            params.aaveReferralCode,
            params.vault
        );

        // withdraw funds directly to uniswap pool to save steps
        IVault(params.vault).withdrawToMargin(params.quoteToken, amountToWithdraw, msg.sender);

        // repay flash:
        IERC20(params.quoteToken).safeTransfer(msg.sender, amountToPay - amountToWithdraw);

        // calculate commission fee
        uint256 commission = amountToPay.mulDiv(params.config.getCommissionFee(), 1e4, Math.Rounding.Ceil).rayDiv(
            IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
        );
        // uint256 gasFee = params.config.getDefaultGasFee() * 1e4;

        // // transfer commission fee, transfer gas fee, which technically is just a write to protocol storage
        // IVault Vault = IVault(params.vault);

        IVault(params.vault).increaseCom(
            commission,
            commission.mulDiv(params.config.getCommissionFeeProtocol(), 1e4, Math.Rounding.Ceil)
        );

        // update position, update gas fee (under the form of scaled balance)
        ITradePair(params.pairAddress).openLongPositionIsolated(
            params.trader,
            params.baseAmount.rayDiv(IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)),
            (amountToWithdraw).rayDiv(IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)),
            (amountToPay - amountToWithdraw).rayDiv(
                IPool(params.aavePool).getReserveNormalizedVariableDebt(params.quoteToken)
            ),
            commission,
            (params.config.getDefaultGasFee() * 1e4).rayDiv(
                IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
            )
        );
    }

    function openShortCallback(Types.executeOpenShortParams memory params, uint256 amountToDeposit) external {
        // call supply usdc
        IPool(params.aavePool).supply(params.quoteToken, amountToDeposit, params.vault, params.aaveReferralCode);

        // borrow base amount
        IPool(params.aavePool).borrow(
            params.baseToken,
            params.baseAmount,
            2, // we assume it's always variable borrow
            params.aaveReferralCode,
            params.vault
        );

        // repay flash
        IERC20(params.baseToken).safeTransfer(msg.sender, params.baseAmount);

        // increase commission
        uint256 commission = amountToDeposit.mulDiv(params.config.getCommissionFee(), 1e4, Math.Rounding.Ceil).rayDiv(
            IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
        );

        IVault(params.vault).increaseCom(
            commission,
            commission.mulDiv(params.config.getCommissionFeeProtocol(), 1e4, Math.Rounding.Ceil)
        );

        // update position, update gas fee (under the form of scaled balance)
        ITradePair(params.pairAddress).openShortPositionIsolated(
            params.trader,
            params.baseAmount.rayDiv(IPool(params.aavePool).getReserveNormalizedVariableDebt(params.baseToken)),
            (amountToDeposit).rayDiv(IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)),
            commission,
            (params.config.getDefaultGasFee() * 1e4).rayDiv(
                IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
            )
        );
    }

    function closeLongCallback(Types.executeCloseLongParams memory params, uint256 amountFlashed) external {
        // repay
        /// @dev amountFlashed might be bigger than user's debt
        if (amountFlashed != 0 && params.quoteD != 0) {
            IPool(params.aavePool).repay(
                params.quoteToken,
                amountFlashed > params.quoteD ? params.quoteD : amountFlashed,
                2,
                params.vault
            );
        }
        /// @dev if so, supply the remaining amountFlashed - quoteD back to Aave
        if (amountFlashed > params.quoteD) {
            IPool(params.aavePool).supply(params.quoteToken, amountFlashed - params.quoteD, params.vault, 0);
        }

        // withdraw base directly to uniswap pool to save steps, also as repay flash
        IVault(params.vault).withdrawToMargin(params.baseToken, params.baseAmount, msg.sender);

        // increase commission
        uint256 commission = params.isLiquidating
            ? 0
            : amountFlashed.mulDiv(params.config.getCommissionFee(), 1e4, Math.Rounding.Ceil).rayDiv(
                IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
            );

        IVault(params.vault).increaseCom(
            commission,
            commission.mulDiv(params.config.getCommissionFeeProtocol(), 1e4, Math.Rounding.Ceil)
        );

        // update position, update gas fee (under the form of scaled balance)
        ITradePair(params.pairAddress).closeLongPositionIsolated(
            params.trader,
            params.isLiquidating
                ? (params.baseAmount + params.baseAmount.mulDiv(params.config.getLiquidationIncentive(), 1e4)).rayDiv(
                    IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)
                )
                : params.baseAmount.rayDiv(IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)),
            amountFlashed > params.quoteD
                ? (amountFlashed - params.quoteD).rayDiv(
                    IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
                )
                : 0,
            amountFlashed > params.quoteD
                ? params.quoteD.rayDiv(IPool(params.aavePool).getReserveNormalizedVariableDebt(params.quoteToken))
                : amountFlashed.rayDiv(IPool(params.aavePool).getReserveNormalizedVariableDebt(params.quoteToken)),
            commission,
            params.isLiquidating
                ? 0
                : (params.config.getDefaultGasFee() * 1e4).rayDiv(
                    IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
                )
        );
    }

    function closeShortCallback(Types.executeCloseShortParams memory params, uint256 amountToWithdraw) external {
        // repay
        IPool(params.aavePool).repay(params.baseToken, params.baseAmount, 2, params.vault);

        // withdraw usdc directly to uniswap pool to save steps, also to repay flash
        IVault(params.vault).withdrawToMargin(params.quoteToken, amountToWithdraw, msg.sender);

        // increase commission
        uint256 commission = params.isLiquidating
            ? 0
            : amountToWithdraw.mulDiv(params.config.getCommissionFee(), 1e4, Math.Rounding.Ceil).rayDiv(
                IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
            );

        IVault(params.vault).increaseCom(
            commission,
            commission.mulDiv(params.config.getCommissionFeeProtocol(), 1e4, Math.Rounding.Ceil)
        );

        // update position, update gas fee (under the form of scaled balance)
        ITradePair(params.pairAddress).closeShortPositionIsolated(
            params.trader,
            params.baseAmount.rayDiv(IPool(params.aavePool).getReserveNormalizedVariableDebt(params.baseToken)),
            params.isLiquidating
                ? (amountToWithdraw + amountToWithdraw.mulDiv(params.config.getLiquidationIncentive(), 1e4)).rayDiv(
                    IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
                )
                : amountToWithdraw.rayDiv(IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)),
            commission,
            params.isLiquidating
                ? 0
                : (params.config.getDefaultGasFee() * 1e4).rayDiv(
                    IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
                )
        );
    }
}
