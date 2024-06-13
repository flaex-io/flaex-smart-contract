// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../types/Types.sol";
import {ValidatingLogic} from "../logic/ValidatingLogic.sol";
import {ITradePair} from "../../interfaces/ITradePair.sol";
import {TraderConfig} from "../configuration/TraderConfig.sol";
import {ErrorList} from "../helpers/ErrorList.sol";
import {IsolatedLogic} from "./IsolatedLogic.sol";
import {TradePairConfig} from "../configuration/TradePairConfig.sol";
import {IVault} from "../../interfaces/IVault.sol";

import {IUniswapV3Pool} from "../../dependencies/v3-core/interfaces/IUniswapV3Pool.sol";
import {PoolAddress} from "../../dependencies/v3-periphery/libraries/PoolAddress.sol";
import {TickMath} from "../../dependencies/v3-core/libraries/TickMath.sol";
import {SafeCast} from "../../dependencies/v3-core/libraries/SafeCast.sol";

import "hardhat/console.sol";

import {Math} from "../../dependencies/openzeppelin/contracts/Math.sol";

import {WadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

library ExecutionLogic {
    using Math for uint256;
    using WadRayMath for uint256;
    using SafeCast for uint256;
    using TraderConfig for Types.traderConfigMap;
    using TradePairConfig for Types.tradingPairConfigMap;

    // using TradePairConfig for Types.tradingPairConfigMap;

    event OpenLong(address indexed trader, uint16 pairId, uint256 baseAmount, uint16 leverage, uint256 quoteAmount);
    event OpenShort(address indexed trader, uint16 pairId, uint256 baseAmount, uint16 leverage, uint256 quoteAmount);
    event CloseLong(address indexed trader, uint16 pairId, uint256 baseAmount, uint256 quoteAmount);
    event CloseShort(address indexed trader, uint16 pairId, uint256 baseAmount, uint256 quoteAmount);
    event Withdraw(uint16 indexed pairId, address indexed trader, uint256 amount);
    event LiquidateLong(address indexed liquidator, uint256 incentive, uint256 incentiveProtocol);
    event LiquidateShort(address indexed liquidator, uint256 incentive, uint256 incentiveProtocol);

    function executeOpenLong(
        Types.traderConfigMap storage traderConfig,
        Types.executeOpenLongParams memory params
    ) external {
        // validate
        ValidatingLogic.validateOpenLong(traderConfig, params);

        /// @dev if user is Short, close Short first.
        /// @dev if amount to Long is larger than amount Shorted
        /// => close 100% Short, update new amount, new max quote then open long with new params
        /// @dev if amount to Long is less than or equal to amout Shorted => close "long amount" Short and finish

        uint256 baseD = params.userData.sbDebtTokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedVariableDebt(params.baseToken)
        );
        uint256 available;
        uint256 marginLevel;
        bool zeroForOne;
        int256 amount0Delta;
        int256 amount1Delta;
        uint256 amountIn;

        if (params.userConfig.isShort(params.pairId)) {
            if (params.baseAmount > baseD) {
                executeCloseShort(
                    traderConfig,
                    Types.executeCloseShortParams({
                        aavePool: params.aavePool,
                        vault: params.vault,
                        aaveOracle: params.aaveOracle,
                        uniPool: params.uniPool,
                        pairId: params.pairId,
                        pairAddress: params.pairAddress,
                        baseToken: params.baseToken,
                        quoteToken: params.quoteToken,
                        config: params.config,
                        userData: params.userData,
                        userConfig: params.userConfig,
                        trader: params.trader,
                        baseAmount: type(uint256).max, // close 100% short first
                        maxQuoteAmount: params.maxQuoteAmount.mulDiv(baseD, params.baseAmount),
                        sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                        isLiquidating: false
                    })
                );
                // open long with remaining amount

                params.maxQuoteAmount -= params.maxQuoteAmount.mulDiv(baseD, params.baseAmount);
                params.baseAmount -= baseD;

                (, , , , available, marginLevel, ) = IsolatedLogic.executeGetUserData(
                    Types.calculateUserDataParams({
                        pairId: params.pairId,
                        aavePool: params.aavePool,
                        aaveOracle: params.aaveOracle,
                        uniPool: params.uniPool,
                        baseToken: params.baseToken,
                        quoteToken: params.quoteToken,
                        userData: ITradePair(params.pairAddress).getUserPosition(params.trader),
                        pairConfig: params.config,
                        userConfig: params.userConfig
                    })
                );

                require(
                    marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                    ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
                );

                // tokenIn = usdc, tokenOut = base => Buying base with usdc
                zeroForOne = params.quoteToken < params.baseToken;

                (amount0Delta, amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                    address(this),
                    zeroForOne,
                    -params.baseAmount.toInt256(),
                    params.sqrtPriceLimitX96 == 0
                        ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                        : params.sqrtPriceLimitX96,
                    abi.encode(abi.encode(params), Types.DIRECTION.OPEN_LONG)
                );

                amountIn = zeroForOne ? uint256(amount0Delta) : uint256(amount1Delta);

                // cost = amountToDeposit (amountIn) / leverage
                require(available >= amountIn / params.leverage, ErrorList.BALANCE_INSUFFICIENT);

                require(params.maxQuoteAmount >= amountIn, ErrorList.TOO_LITTLE_INPUT);

                // update user config
                if (!traderConfig.isLong(params.pairId)) {
                    traderConfig.setLong(params.pairId, true);
                }

                emit OpenLong(params.trader, params.pairId, params.baseAmount, params.leverage, amountIn);
            } else {
                executeCloseShort(
                    traderConfig,
                    Types.executeCloseShortParams({
                        aavePool: params.aavePool,
                        vault: params.vault,
                        aaveOracle: params.aaveOracle,
                        uniPool: params.uniPool,
                        pairId: params.pairId,
                        pairAddress: params.pairAddress,
                        baseToken: params.baseToken,
                        quoteToken: params.quoteToken,
                        config: params.config,
                        userData: params.userData,
                        userConfig: params.userConfig,
                        trader: params.trader,
                        baseAmount: params.baseAmount, // close base amount
                        maxQuoteAmount: params.maxQuoteAmount,
                        sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                        isLiquidating: false
                    })
                );
            }
        } else {
            // enforce that cost is less than user's balance
            // cost = amountToDeposit / leverage
            // require();
            (, , , , available, marginLevel, ) = IsolatedLogic.executeGetUserData(
                Types.calculateUserDataParams({
                    pairId: params.pairId,
                    aavePool: params.aavePool,
                    aaveOracle: params.aaveOracle,
                    uniPool: params.uniPool,
                    baseToken: params.baseToken,
                    quoteToken: params.quoteToken,
                    userData: params.userData,
                    pairConfig: params.config,
                    userConfig: params.userConfig
                })
            );

            require(
                marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
            );

            // tokenIn = usdc, tokenOut = base => Buying base with usdc
            zeroForOne = params.quoteToken < params.baseToken;

            (amount0Delta, amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                address(this),
                zeroForOne,
                -params.baseAmount.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : params.sqrtPriceLimitX96,
                abi.encode(abi.encode(params), Types.DIRECTION.OPEN_LONG)
            );

            amountIn = zeroForOne ? uint256(amount0Delta) : uint256(amount1Delta);

            // cost = amountToDeposit (amountIn) / leverage
            require(available >= amountIn / params.leverage, ErrorList.BALANCE_INSUFFICIENT);

            require(params.maxQuoteAmount >= amountIn, ErrorList.TOO_LITTLE_INPUT);

            // update user config
            if (!traderConfig.isLong(params.pairId)) {
                traderConfig.setLong(params.pairId, true);
            }

            emit OpenLong(params.trader, params.pairId, params.baseAmount, params.leverage, amountIn);
        }
    }

    function executeOpenShort(
        Types.traderConfigMap storage traderConfig,
        Types.executeOpenShortParams memory params
    ) external {
        // validate
        ValidatingLogic.validateOpenShort(traderConfig, params);

        /// @dev if user is Long, close Long first.
        /// @dev if amount to Short is larger than amount Longed
        /// => close 100% Long, update new amount, new min quote then open short with new params
        /// @dev if amount to Short is less than or equal to amout Longed => close "short amount" Long and finish

        uint256 baseA = params.userData.sbATokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)
        );
        uint256 available;
        uint256 marginLevel;
        bool zeroForOne;
        int256 amount0Delta;
        int256 amount1Delta;
        uint256 amountOut;

        if (params.userConfig.isLong(params.pairId)) {
            if (params.baseAmount > baseA) {
                executeCloseLong(
                    traderConfig,
                    Types.executeCloseLongParams({
                        aavePool: params.aavePool,
                        vault: params.vault,
                        aaveOracle: params.aaveOracle,
                        uniPool: params.uniPool,
                        pairId: params.pairId,
                        pairAddress: params.pairAddress,
                        baseToken: params.baseToken,
                        quoteToken: params.quoteToken,
                        config: params.config,
                        userData: params.userData,
                        userConfig: params.userConfig,
                        trader: params.trader,
                        baseAmount: type(uint256).max,
                        minQuoteAmount: params.minQuoteAmount.mulDiv(baseA, params.baseAmount),
                        sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                        quoteD: 0,
                        isLiquidating: false
                    })
                );

                // open Short with remaining amount
                params.minQuoteAmount -= params.minQuoteAmount.mulDiv(baseA, params.baseAmount);
                params.baseAmount -= baseA;

                (, , , , available, marginLevel, ) = IsolatedLogic.executeGetUserData(
                    Types.calculateUserDataParams({
                        pairId: params.pairId,
                        aavePool: params.aavePool,
                        aaveOracle: params.aaveOracle,
                        uniPool: params.uniPool,
                        baseToken: params.baseToken,
                        quoteToken: params.quoteToken,
                        userData: ITradePair(params.pairAddress).getUserPosition(params.trader),
                        pairConfig: params.config,
                        userConfig: params.userConfig
                    })
                );

                require(
                    marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                    ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
                );

                // tokenIn = base, tokenOut = usdc => Selling base for USDC
                zeroForOne = params.baseToken < params.quoteToken;

                (amount0Delta, amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                    address(this),
                    zeroForOne,
                    params.baseAmount.toInt256(),
                    params.sqrtPriceLimitX96 == 0
                        ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                        : params.sqrtPriceLimitX96,
                    abi.encode(abi.encode(params), Types.DIRECTION.OPEN_SHORT)
                );

                amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta)); // this is the amount of usdc that we flashed

                // cost = amountToDeposit / leverage
                require(available >= amountOut / params.leverage, ErrorList.BALANCE_INSUFFICIENT);

                require(params.minQuoteAmount <= amountOut, ErrorList.TOO_MUCH_OUTPUT);

                // update user config
                if (!traderConfig.isShort(params.pairId)) {
                    traderConfig.setShort(params.pairId, true);
                }

                emit OpenShort(params.trader, params.pairId, params.baseAmount, params.leverage, amountOut);
            } else {
                executeCloseLong(
                    traderConfig,
                    Types.executeCloseLongParams({
                        aavePool: params.aavePool,
                        vault: params.vault,
                        aaveOracle: params.aaveOracle,
                        uniPool: params.uniPool,
                        pairId: params.pairId,
                        pairAddress: params.pairAddress,
                        baseToken: params.baseToken,
                        quoteToken: params.quoteToken,
                        config: params.config,
                        userData: params.userData,
                        userConfig: params.userConfig,
                        trader: params.trader,
                        baseAmount: params.baseAmount,
                        minQuoteAmount: params.minQuoteAmount,
                        sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                        quoteD: 0,
                        isLiquidating: false
                    })
                );
            }
        } else {
            // enforce that cost is less than user's balance
            // cost = amountToDeposit / leverage
            (, , , , available, marginLevel, ) = IsolatedLogic.executeGetUserData(
                Types.calculateUserDataParams({
                    pairId: params.pairId,
                    aavePool: params.aavePool,
                    aaveOracle: params.aaveOracle,
                    uniPool: params.uniPool,
                    baseToken: params.baseToken,
                    quoteToken: params.quoteToken,
                    userData: params.userData,
                    pairConfig: params.config,
                    userConfig: params.userConfig
                })
            );

            require(
                marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
            );

            // tokenIn = base, tokenOut = usdc => Selling base for USDC
            zeroForOne = params.baseToken < params.quoteToken;

            (amount0Delta, amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                address(this),
                zeroForOne,
                params.baseAmount.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : params.sqrtPriceLimitX96,
                abi.encode(abi.encode(params), Types.DIRECTION.OPEN_SHORT)
            );

            amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta)); // this is the amount of usdc that we flashed

            // cost = amountToDeposit / leverage

            require(available >= amountOut / params.leverage, ErrorList.BALANCE_INSUFFICIENT);

            require(params.minQuoteAmount <= amountOut, ErrorList.TOO_MUCH_OUTPUT);

            // update user config
            if (!traderConfig.isShort(params.pairId)) {
                traderConfig.setShort(params.pairId, true);
            }

            emit OpenShort(params.trader, params.pairId, params.baseAmount, params.leverage, amountOut);
        }
    }

    function executeCloseLong(
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseLongParams memory params
    ) public {
        ValidatingLogic.validateCloseLong(traderConfig, params);
        uint256 marginLevel;
        uint256 actualBaseAmount;
        bool isValid;

        (actualBaseAmount, , , params.quoteD, , marginLevel, isValid) = IsolatedLogic.executeGetUserData(
            Types.calculateUserDataParams({
                pairId: params.pairId,
                aavePool: params.aavePool,
                aaveOracle: params.aaveOracle,
                uniPool: params.uniPool,
                baseToken: params.baseToken,
                quoteToken: params.quoteToken,
                userData: params.userData,
                pairConfig: params.config,
                userConfig: params.userConfig
            })
        );

        if (params.baseAmount == type(uint256).max || params.baseAmount >= actualBaseAmount)
            params.baseAmount = actualBaseAmount;

        // params.baseAmount = params.baseAmount == type(uint256).max ? actualBaseAmount : params.baseAmount;

        if (params.isLiquidating) {
            require(
                marginLevel <= params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.TRADER_IS_NOT_LIQUIDATABLE
            );
            require(isValid, ErrorList.MARGIN_LEVEL_NOT_LIQUIDATABLE);
        } else {
            require(
                marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
            );
        }
        // tokenIn = base, tokenOut = usdc => Selling base for USDC
        bool zeroForOne = params.baseToken < params.quoteToken;

        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
            address(this),
            zeroForOne,
            params.baseAmount.toInt256(),
            params.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : params.sqrtPriceLimitX96,
            abi.encode(abi.encode(params), Types.DIRECTION.CLOSE_LONG)
        );

        uint256 amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta)); // this is the amount of usdc that we flashed

        require(params.minQuoteAmount <= amountOut, ErrorList.TOO_MUCH_OUTPUT);

        // update user config
        if (ITradePair(params.pairAddress).getUserPosition(params.trader).sbATokenAmount == 0) {
            traderConfig.setLong(params.pairId, false);
        }

        emit CloseLong(params.trader, params.pairId, params.baseAmount, amountOut);
    }

    function executeCloseShort(
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseShortParams memory params
    ) public returns (uint256) {
        ValidatingLogic.validateCloseShort(traderConfig, params);

        (, uint256 actualBaseAmount, , , , uint256 marginLevel, bool isValid) = IsolatedLogic.executeGetUserData(
            Types.calculateUserDataParams({
                pairId: params.pairId,
                aavePool: params.aavePool,
                aaveOracle: params.aaveOracle,
                uniPool: params.uniPool,
                baseToken: params.baseToken,
                quoteToken: params.quoteToken,
                userData: params.userData,
                pairConfig: params.config,
                userConfig: params.userConfig
            })
        );

        if (params.isLiquidating) {
            require(
                marginLevel <= params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.TRADER_IS_NOT_LIQUIDATABLE
            );
            require(isValid, ErrorList.MARGIN_LEVEL_NOT_LIQUIDATABLE);
        } else {
            require(
                marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
            );
        }

        if (params.baseAmount == type(uint256).max || params.baseAmount >= actualBaseAmount)
            params.baseAmount = actualBaseAmount;

        // params.baseAmount = params.baseAmount == type(uint256).max ? actualBaseAmount : params.baseAmount;

        // tokenIn = usdc, tokenOut = base => Buying base with usdc
        bool zeroForOne = params.quoteToken < params.baseToken;

        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
            address(this),
            zeroForOne,
            -params.baseAmount.toInt256(),
            params.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : params.sqrtPriceLimitX96,
            abi.encode(abi.encode(params), Types.DIRECTION.CLOSE_SHORT)
        );

        uint256 amountIn = zeroForOne ? uint256(amount0Delta) : uint256(amount1Delta); // amountIn = amount usdc

        require(params.maxQuoteAmount >= amountIn, ErrorList.TOO_LITTLE_INPUT);

        // update user config
        if (ITradePair(params.pairAddress).getUserPosition(params.trader).sbDebtTokenAmount == 0) {
            traderConfig.setShort(params.pairId, false);
        }

        emit CloseShort(params.trader, params.pairId, params.baseAmount, amountIn);

        return amountIn;
    }

    function executeLiquidateLong(
        address liquidator,
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseLongParams memory params
    ) external {
        // validate
        ValidatingLogic.validateLiquidate(
            params.baseAmount,
            params
                .userData
                .sbATokenAmount
                .rayMul(IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken))
                .mulDiv(params.config.getLiquidationFactor(), 1e4)
        );

        // call close Long
        executeCloseLong(traderConfig, params);

        // withdraw extra collateral to liquidator
        uint256 incentive = params.baseAmount.mulDiv(params.config.getLiquidationIncentive(), 1e4);
        uint256 incentiveLiquidator = incentive - incentive.mulDiv(params.config.getLiquidationProtocol(), 1e4);
        uint256 incentiveProtocol = incentive.mulDiv(params.config.getLiquidationProtocol(), 1e4);
        IVault(params.vault).withdrawToMargin(params.baseToken, incentiveLiquidator, liquidator);

        // increase liquidation incentive to protocol
        IVault(params.vault).increaseLiquidationIncentiveProtocol(
            params.baseToken,
            incentive.mulDiv(params.config.getLiquidationProtocol(), 1e4).rayDiv(
                IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)
            )
        );
        emit LiquidateLong(liquidator, incentive, incentiveProtocol);
    }

    function executeLiquidateShort(
        address liquidator,
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseShortParams memory params
    ) external {
        // validate
        ValidatingLogic.validateLiquidate(
            params.baseAmount,
            params
                .userData
                .sbDebtTokenAmount
                .rayMul(IPool(params.aavePool).getReserveNormalizedVariableDebt(params.baseToken))
                .mulDiv(params.config.getLiquidationFactor(), 1e4)
        );

        // call close Short
        uint256 incentive = executeCloseShort(traderConfig, params).mulDiv(
            params.config.getLiquidationIncentive(),
            1e4
        );
        uint256 incentiveLiquidator = incentive - incentive.mulDiv(params.config.getLiquidationProtocol(), 1e4);
        uint256 incentiveProtocol = incentive.mulDiv(params.config.getLiquidationProtocol(), 1e4);

        // withdraw extra collateral to liquidator
        IVault(params.vault).withdrawToMargin(params.quoteToken, incentiveLiquidator, liquidator);

        // increase liquidation incentive to protocol
        IVault(params.vault).increaseLiquidationIncentiveProtocol(
            params.quoteToken,
            incentive.mulDiv(params.config.getLiquidationProtocol(), 1e4).rayDiv(
                IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
            )
        );

        emit LiquidateShort(liquidator, incentive, incentiveProtocol);
    }

    function executeWithdrawFund(
        Types.traderConfigMap storage traderConfig,
        Types.executeWithdrawParams memory params
    ) external {
        (, , , , uint256 available, uint256 marginLevel, ) = IsolatedLogic.executeGetUserData(
            Types.calculateUserDataParams({
                pairId: params.pairId,
                aavePool: params.aavePool,
                aaveOracle: params.aaveOracle,
                uniPool: params.uniPool,
                baseToken: params.baseToken,
                quoteToken: params.quoteToken,
                userData: params.userData,
                pairConfig: params.config,
                userConfig: params.userConfig
            })
        );

        require(
            marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
            ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
        );

        if (params.amountToWithdraw == type(uint256).max) {
            params.amountToWithdraw = available;
        } else {
            require(params.amountToWithdraw <= available, ErrorList.INVALID_AMOUNT);
        }

        // withdraw
        IVault(params.vault).withdrawToMargin(params.quoteToken, params.amountToWithdraw, params.trader);

        // update position
        bool empty = ITradePair(params.pairAddress).withdrawFundIsolated(
            params.trader,
            params.amountToWithdraw.rayDiv(IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken))
        );

        // update user config
        if (empty && !params.userConfig.isLongOrShort(params.pairId)) {
            traderConfig.setDeposit(params.pairId, false);
        }

        emit Withdraw(params.pairId, params.trader, params.amountToWithdraw);
    }
}
