// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../types/Types.sol";
import {ValidatingLogic} from "../logic/ValidatingLogic.sol";
import {ITradePair} from "../../interfaces/ITradePair.sol";
import {ErrorList} from "../helpers/ErrorList.sol";
import {CrossLogic} from "./CrossLogic.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {TradePairConfig} from "../configuration/TradePairConfig.sol";
import {TraderConfig} from "../configuration/TraderConfig.sol";

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {WadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";

import {Math} from "../../dependencies/openzeppelin/contracts/Math.sol";

import {SafeCast} from "../../dependencies/v3-core/libraries/SafeCast.sol";
import {IUniswapV3Pool} from "../../dependencies/v3-core/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "../../dependencies/v3-core/libraries/TickMath.sol";

library CrossExecutionLogic {
    using Math for uint256;
    using WadRayMath for uint256;
    using SafeCast for uint256;
    using TraderConfig for Types.traderConfigMap;
    using TradePairConfig for Types.tradingPairConfigMap;

    event OpenLong(address indexed trader, uint16 pairId, uint256 baseAmount, uint16 leverage, uint256 quoteAmount);
    event OpenShort(address indexed trader, uint16 pairId, uint256 baseAmount, uint16 leverage, uint256 quoteAmount);
    event CloseLong(address indexed trader, uint16 pairId, uint256 baseAmount, uint256 quoteAmount);
    event CloseShort(address indexed trader, uint16 pairId, uint256 baseAmount, uint256 quoteAmount);
    event Withdraw(uint16 indexed pairId, address indexed trader, uint256 amount);
    event LiquidateLong(address indexed liquidator, uint256 incentive, uint256 incentiveProtocol);
    event LiquidateShort(address indexed liquidator, uint256 incentive, uint256 incentiveProtocol);

    struct temp {
        uint256 baseAOrBaseD;
        uint256 available;
        uint256 marginLevel;
        bool zeroForOne;
        int256 amount0Delta;
        int256 amount1Delta;
        uint256 amountInOrOut;
    }

    function executeOpenLong(
        mapping(uint16 => bytes32) storage tradingPairList,
        mapping(bytes32 => address) storage tradingPairs,
        Types.traderConfigMap storage traderConfig,
        Types.executeOpenLongCrossParams memory params
    ) external {
        // validate
        ValidatingLogic.validateOpenLongCross(traderConfig, params);
        /// @dev if user is Short, close Short first.
        /// @dev if amount to Long is larger than amount Shorted
        /// => close 100% Short, update new amount, new max quote then open long with new params
        /// @dev if amount to Long is less than or equal to amout Shorted => close "long amount" Short and finish

        temp memory tempVars;

        tempVars.baseAOrBaseD = params.userData.sDebtTokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedVariableDebt(params.baseToken)
        );

        Types.executeCloseShortCrossParams memory closeParams;

        if (params.userConfig.isShort(params.pairId)) {
            if (params.baseAmount > tempVars.baseAOrBaseD) {
                closeParams.tradingPairCount = params.tradingPairCount;
                closeParams.aavePool = params.aavePool;
                closeParams.vault = params.vault;
                closeParams.aaveOracle = params.aaveOracle;
                closeParams.uniPool = params.uniPool;
                closeParams.uniFactory = params.uniFactory;
                closeParams.pairId = params.pairId;
                closeParams.pairAddress = params.pairAddress;
                closeParams.baseToken = params.baseToken;
                closeParams.quoteToken = params.quoteToken;
                closeParams.config = params.config;
                closeParams.userData = params.userData;
                closeParams.userConfig = params.userConfig;
                closeParams.trader = params.trader;
                closeParams.baseAmount = type(uint256).max; // close 100% short first
                closeParams.maxQuoteAmount = params.maxQuoteAmount.mulDiv(tempVars.baseAOrBaseD, params.baseAmount);
                closeParams.sqrtPriceLimitX96 = params.sqrtPriceLimitX96;
                closeParams.isLiquidating = false;

                executeCloseShort(tradingPairList, tradingPairs, traderConfig, closeParams);
                // open long with remaining amount

                params.maxQuoteAmount -= params.maxQuoteAmount.mulDiv(tempVars.baseAOrBaseD, params.baseAmount);
                params.baseAmount -= tempVars.baseAOrBaseD;

                (, , , , tempVars.available, tempVars.marginLevel, ) = CrossLogic.executeGetUserData(
                    tradingPairList,
                    tradingPairs,
                    Types.calculatedUserCrossDataParams({
                        pairId: params.pairId,
                        trader: params.trader,
                        aavePool: params.aavePool,
                        aaveOracle: params.aaveOracle,
                        uniFactory: params.uniFactory,
                        tradingPairCount: params.tradingPairCount,
                        userConfig: params.userConfig
                    })
                );

                require(
                    tempVars.marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                    ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
                );

                // tokenIn = usdc, tokenOut = base => Buying base with usdc
                tempVars.zeroForOne = params.quoteToken < params.baseToken;

                (tempVars.amount0Delta, tempVars.amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                    address(this),
                    tempVars.zeroForOne,
                    -params.baseAmount.toInt256(),
                    params.sqrtPriceLimitX96 == 0
                        ? (tempVars.zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                        : params.sqrtPriceLimitX96,
                    abi.encode(abi.encode(params), Types.DIRECTION.OPEN_LONG)
                );

                tempVars.amountInOrOut = tempVars.zeroForOne
                    ? uint256(tempVars.amount0Delta)
                    : uint256(tempVars.amount1Delta);

                // cost = amountToDeposit (amountIn) / leverage
                require(
                    tempVars.available >= tempVars.amountInOrOut / params.leverage,
                    ErrorList.BALANCE_INSUFFICIENT
                );

                require(params.maxQuoteAmount >= tempVars.amountInOrOut, ErrorList.TOO_LITTLE_INPUT);

                // update user config
                if (!traderConfig.isLong(params.pairId)) {
                    traderConfig.setLong(params.pairId, true);
                }

                emit OpenLong(
                    params.trader,
                    params.pairId,
                    params.baseAmount,
                    params.leverage,
                    tempVars.amountInOrOut
                );
            } else {
                closeParams.tradingPairCount = params.tradingPairCount;
                closeParams.aavePool = params.aavePool;
                closeParams.vault = params.vault;
                closeParams.aaveOracle = params.aaveOracle;
                closeParams.uniPool = params.uniPool;
                closeParams.uniFactory = params.uniFactory;
                closeParams.pairId = params.pairId;
                closeParams.pairAddress = params.pairAddress;
                closeParams.baseToken = params.baseToken;
                closeParams.quoteToken = params.quoteToken;
                closeParams.config = params.config;
                closeParams.userData = params.userData;
                closeParams.userConfig = params.userConfig;
                closeParams.trader = params.trader;
                closeParams.baseAmount = params.baseAmount; // close 100% short first
                closeParams.maxQuoteAmount = params.maxQuoteAmount;
                closeParams.sqrtPriceLimitX96 = params.sqrtPriceLimitX96;
                closeParams.isLiquidating = false;

                executeCloseShort(
                    tradingPairList,
                    tradingPairs,
                    traderConfig,
                    closeParams
                    // Types.executeCloseShortCrossParams({
                    //     tradingPairCount: params.tradingPairCount,
                    //     aavePool: params.aavePool,
                    //     vault: params.vault,
                    //     aaveOracle: params.aaveOracle,
                    //     uniPool: params.uniPool,
                    //     uniFactory: params.uniFactory,
                    //     pairId: params.pairId,
                    //     pairAddress: params.pairAddress,
                    //     baseToken: params.baseToken,
                    //     quoteToken: params.quoteToken,
                    //     config: params.config,
                    //     userData: params.userData,
                    //     userConfig: params.userConfig,
                    //     trader: params.trader,
                    //     baseAmount: params.baseAmount, // close base amount
                    //     maxQuoteAmount: params.maxQuoteAmount,
                    //     sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                    //     isLiquidating: false
                    // })
                );
            }
        } else {
            // enforce that cost is less than user's balance
            // cost = amountToDeposit / leverage
            // require();
            (, , , , tempVars.available, tempVars.marginLevel, ) = CrossLogic.executeGetUserData(
                tradingPairList,
                tradingPairs,
                Types.calculatedUserCrossDataParams({
                    pairId: params.pairId,
                    trader: params.trader,
                    aavePool: params.aavePool,
                    aaveOracle: params.aaveOracle,
                    uniFactory: params.uniFactory,
                    tradingPairCount: params.tradingPairCount,
                    userConfig: params.userConfig
                })
            );
            require(
                tempVars.marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
            );

            // tokenIn = usdc, tokenOut = base => Buying base with usdc
            tempVars.zeroForOne = params.quoteToken < params.baseToken;

            (tempVars.amount0Delta, tempVars.amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                address(this),
                tempVars.zeroForOne,
                -params.baseAmount.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (tempVars.zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : params.sqrtPriceLimitX96,
                abi.encode(abi.encode(params), Types.DIRECTION.OPEN_LONG)
            );

            tempVars.amountInOrOut = tempVars.zeroForOne
                ? uint256(tempVars.amount0Delta)
                : uint256(tempVars.amount1Delta);

            // cost = amountToDeposit (amountIn) / leverage
            require(tempVars.available >= tempVars.amountInOrOut / params.leverage, ErrorList.BALANCE_INSUFFICIENT);

            require(params.maxQuoteAmount >= tempVars.amountInOrOut, ErrorList.TOO_LITTLE_INPUT);

            // update user config
            if (!traderConfig.isLong(params.pairId)) {
                traderConfig.setLong(params.pairId, true);
            }

            emit OpenLong(params.trader, params.pairId, params.baseAmount, params.leverage, tempVars.amountInOrOut);
        }
    }

    function executeOpenShort(
        mapping(uint16 => bytes32) storage tradingPairList,
        mapping(bytes32 => address) storage tradingPairs,
        Types.traderConfigMap storage traderConfig,
        Types.executeOpenShortCrossParams memory params
    ) external {
        // validate
        ValidatingLogic.validateOpenShortCross(traderConfig, params);

        /// @dev if user is Long, close Long first.
        /// @dev if amount to Short is larger than amount Longed
        /// => close 100% Long, update new amount, new min quote then open short with new params
        /// @dev if amount to Short is less than or equal to amout Longed => close "short amount" Long and finish

        temp memory tempVars;

        tempVars.baseAOrBaseD = params.userData.sATokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)
        );

        // uint256 baseA = params.userData.sATokenAmount.rayMul(
        //     IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)
        // );

        // uint256 available;
        // uint256 marginLevel;
        // bool zeroForOne;
        // int256 amount0Delta;
        // int256 amount1Delta;
        // uint256 amountOut;

        Types.executeCloseLongCrossParams memory closeParams;

        if (params.userConfig.isLong(params.pairId)) {
            if (params.baseAmount > tempVars.baseAOrBaseD) {
                closeParams.tradingPairCount = params.tradingPairCount;
                closeParams.aavePool = params.aavePool;
                closeParams.vault = params.vault;
                closeParams.aaveOracle = params.aaveOracle;
                closeParams.uniPool = params.uniPool;
                closeParams.uniFactory = params.uniFactory;
                closeParams.pairId = params.pairId;
                closeParams.pairAddress = params.pairAddress;
                closeParams.baseToken = params.baseToken;
                closeParams.quoteToken = params.quoteToken;
                closeParams.config = params.config;
                closeParams.userData = params.userData;
                closeParams.userConfig = params.userConfig;
                closeParams.trader = params.trader;
                closeParams.baseAmount = type(uint256).max;
                closeParams.minQuoteAmount = params.minQuoteAmount.mulDiv(tempVars.baseAOrBaseD, params.baseAmount);
                closeParams.sqrtPriceLimitX96 = params.sqrtPriceLimitX96;
                closeParams.quoteD = 0;
                closeParams.isLiquidating = false;

                executeCloseLong(
                    tradingPairList,
                    tradingPairs,
                    traderConfig,
                    closeParams
                    // Types.executeCloseLongCrossParams({
                    //     tradingPairCount: params.tradingPairCount,
                    //     aavePool: params.aavePool,
                    //     vault: params.vault,
                    //     aaveOracle: params.aaveOracle,
                    //     uniPool: params.uniPool,
                    //     uniFactory: params.uniFactory,
                    //     pairId: params.pairId,
                    //     pairAddress: params.pairAddress,
                    //     baseToken: params.baseToken,
                    //     quoteToken: params.quoteToken,
                    //     config: params.config,
                    //     userData: params.userData,
                    //     userConfig: params.userConfig,
                    //     trader: params.trader,
                    //     baseAmount: type(uint256).max,
                    //     minQuoteAmount: params.minQuoteAmount.mulDiv(tempVars.baseAOrBaseD, params.baseAmount),
                    //     sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                    //     quoteD: 0,
                    //     isLiquidating: false
                    // })
                );

                // open Short with remaining amount
                params.minQuoteAmount -= params.minQuoteAmount.mulDiv(tempVars.baseAOrBaseD, params.baseAmount);
                params.baseAmount -= tempVars.baseAOrBaseD;

                (, , , , tempVars.available, tempVars.marginLevel, ) = CrossLogic.executeGetUserData(
                    tradingPairList,
                    tradingPairs,
                    Types.calculatedUserCrossDataParams({
                        pairId: params.pairId,
                        trader: params.trader,
                        aavePool: params.aavePool,
                        aaveOracle: params.aaveOracle,
                        uniFactory: params.uniFactory,
                        tradingPairCount: params.tradingPairCount,
                        userConfig: params.userConfig
                    })
                );

                require(
                    tempVars.marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                    ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
                );

                // tokenIn = base, tokenOut = usdc => Selling base for USDC
                tempVars.zeroForOne = params.baseToken < params.quoteToken;

                (tempVars.amount0Delta, tempVars.amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                    address(this),
                    tempVars.zeroForOne,
                    params.baseAmount.toInt256(),
                    params.sqrtPriceLimitX96 == 0
                        ? (tempVars.zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                        : params.sqrtPriceLimitX96,
                    abi.encode(abi.encode(params), Types.DIRECTION.OPEN_SHORT)
                );

                tempVars.amountInOrOut = uint256(
                    -(tempVars.zeroForOne ? tempVars.amount1Delta : tempVars.amount0Delta)
                ); // this is the amount of usdc that we flashed

                // cost = amountToDeposit / leverage
                require(
                    tempVars.available >= tempVars.amountInOrOut / params.leverage,
                    ErrorList.BALANCE_INSUFFICIENT
                );

                require(params.minQuoteAmount <= tempVars.amountInOrOut, ErrorList.TOO_MUCH_OUTPUT);

                // update user config
                if (!traderConfig.isShort(params.pairId)) {
                    traderConfig.setShort(params.pairId, true);
                }

                emit OpenShort(
                    params.trader,
                    params.pairId,
                    params.baseAmount,
                    params.leverage,
                    tempVars.amountInOrOut
                );
            } else {
                closeParams.tradingPairCount = params.tradingPairCount;
                closeParams.aavePool = params.aavePool;
                closeParams.vault = params.vault;
                closeParams.aaveOracle = params.aaveOracle;
                closeParams.uniPool = params.uniPool;
                closeParams.uniFactory = params.uniFactory;
                closeParams.pairId = params.pairId;
                closeParams.pairAddress = params.pairAddress;
                closeParams.baseToken = params.baseToken;
                closeParams.quoteToken = params.quoteToken;
                closeParams.config = params.config;
                closeParams.userData = params.userData;
                closeParams.userConfig = params.userConfig;
                closeParams.trader = params.trader;
                closeParams.baseAmount = params.baseAmount;
                closeParams.minQuoteAmount = params.minQuoteAmount;
                closeParams.sqrtPriceLimitX96 = params.sqrtPriceLimitX96;
                closeParams.quoteD = 0;
                closeParams.isLiquidating = false;

                executeCloseLong(
                    tradingPairList,
                    tradingPairs,
                    traderConfig,
                    closeParams
                    // Types.executeCloseLongCrossParams({
                    //     tradingPairCount: params.tradingPairCount,
                    //     aavePool: params.aavePool,
                    //     vault: params.vault,
                    //     aaveOracle: params.aaveOracle,
                    //     uniPool: params.uniPool,
                    //     uniFactory: params.uniFactory,
                    //     pairId: params.pairId,
                    //     pairAddress: params.pairAddress,
                    //     baseToken: params.baseToken,
                    //     quoteToken: params.quoteToken,
                    //     config: params.config,
                    //     userData: params.userData,
                    //     userConfig: params.userConfig,
                    //     trader: params.trader,
                    //     baseAmount: params.baseAmount,
                    //     minQuoteAmount: params.minQuoteAmount,
                    //     sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                    //     quoteD: 0,
                    //     isLiquidating: false
                    // })
                );
            }
        } else {
            // enforce that cost is less than user's balance
            // cost = amountToDeposit / leverage
            (, , , , tempVars.available, tempVars.marginLevel, ) = CrossLogic.executeGetUserData(
                tradingPairList,
                tradingPairs,
                Types.calculatedUserCrossDataParams({
                    pairId: params.pairId,
                    trader: params.trader,
                    aavePool: params.aavePool,
                    aaveOracle: params.aaveOracle,
                    uniFactory: params.uniFactory,
                    tradingPairCount: params.tradingPairCount,
                    userConfig: params.userConfig
                })
            );

            require(
                tempVars.marginLevel > params.config.getLiquidationThreshold().wadDiv(1e2),
                ErrorList.MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD
            );

            // tokenIn = base, tokenOut = usdc => Selling base for USDC
            tempVars.zeroForOne = params.baseToken < params.quoteToken;

            (tempVars.amount0Delta, tempVars.amount1Delta) = IUniswapV3Pool(params.uniPool).swap(
                address(this),
                tempVars.zeroForOne,
                params.baseAmount.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (tempVars.zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : params.sqrtPriceLimitX96,
                abi.encode(abi.encode(params), Types.DIRECTION.OPEN_SHORT)
            );

            tempVars.amountInOrOut = uint256(-(tempVars.zeroForOne ? tempVars.amount1Delta : tempVars.amount0Delta)); // this is the amount of usdc that we flashed

            // cost = amountToDeposit / leverage
            require(tempVars.available >= tempVars.amountInOrOut / params.leverage, ErrorList.BALANCE_INSUFFICIENT);

            require(params.minQuoteAmount <= tempVars.amountInOrOut, ErrorList.TOO_MUCH_OUTPUT);

            // update user config
            if (!traderConfig.isShort(params.pairId)) {
                traderConfig.setShort(params.pairId, true);
            }

            emit OpenShort(params.trader, params.pairId, params.baseAmount, params.leverage, tempVars.amountInOrOut);
        }
    }

    function executeCloseLong(
        mapping(uint16 => bytes32) storage tradingPairList,
        mapping(bytes32 => address) storage tradingPairs,
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseLongCrossParams memory params
    ) public {
        ValidatingLogic.validateCloseLongCross(traderConfig, params);
        uint256 marginLevel;
        uint256 actualBaseAmount;
        bool isValid;

        (actualBaseAmount, , , params.quoteD, , marginLevel, isValid) = CrossLogic.executeGetUserData(
            tradingPairList,
            tradingPairs,
            Types.calculatedUserCrossDataParams({
                pairId: params.pairId,
                trader: params.trader,
                aavePool: params.aavePool,
                aaveOracle: params.aaveOracle,
                uniFactory: params.uniFactory,
                tradingPairCount: params.tradingPairCount,
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
        if (ITradePair(params.pairAddress).getUserCrossPosition(params.trader).sATokenAmount == 0) {
            traderConfig.setLong(params.pairId, false);
        }

        emit CloseLong(params.trader, params.pairId, params.baseAmount, amountOut);
    }

    function executeCloseShort(
        mapping(uint16 => bytes32) storage tradingPairList,
        mapping(bytes32 => address) storage tradingPairs,
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseShortCrossParams memory params
    ) public returns (uint256) {
        ValidatingLogic.validateCloseShortCross(traderConfig, params);

        (, uint256 actualBaseAmount, , , , uint256 marginLevel, bool isValid) = CrossLogic.executeGetUserData(
            tradingPairList,
            tradingPairs,
            Types.calculatedUserCrossDataParams({
                pairId: params.pairId,
                trader: params.trader,
                aavePool: params.aavePool,
                aaveOracle: params.aaveOracle,
                uniFactory: params.uniFactory,
                tradingPairCount: params.tradingPairCount,
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
        if (ITradePair(params.pairAddress).getUserCrossPosition(params.trader).sDebtTokenAmount == 0) {
            traderConfig.setShort(params.pairId, false);
        }

        emit CloseShort(params.trader, params.pairId, params.baseAmount, amountIn);

        return amountIn;
    }

    function executeLiquidateLong(
        mapping(uint16 => bytes32) storage tradingPairList,
        mapping(bytes32 => address) storage tradingPairs,
        address liquidator,
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseLongCrossParams memory params
    ) external {
        // validate
        ValidatingLogic.validateLiquidate(
            params.baseAmount,
            params
                .userData
                .sATokenAmount
                .rayMul(IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken))
                .mulDiv(params.config.getLiquidationFactor(), 1e4)
        );

        // call close Long
        executeCloseLong(tradingPairList, tradingPairs, traderConfig, params);

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
        mapping(uint16 => bytes32) storage tradingPairList,
        mapping(bytes32 => address) storage tradingPairs,
        address liquidator,
        Types.traderConfigMap storage traderConfig,
        Types.executeCloseShortCrossParams memory params
    ) external {
        // validate
        ValidatingLogic.validateLiquidate(
            params.baseAmount,
            params
                .userData
                .sDebtTokenAmount
                .rayMul(IPool(params.aavePool).getReserveNormalizedVariableDebt(params.baseToken))
                .mulDiv(params.config.getLiquidationFactor(), 1e4)
        );

        // call close Short
        uint256 incentive = executeCloseShort(tradingPairList, tradingPairs, traderConfig, params).mulDiv(
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
        mapping(uint16 => bytes32) storage tradingPairList,
        mapping(bytes32 => address) storage tradingPairs,
        uint16 tradingPairCount,
        Types.traderConfigMap storage traderConfig,
        Types.executeCrossWithdrawParams memory params
    ) external {
        (, , , , uint256 available, uint256 marginLevel, ) = CrossLogic.executeGetUserData(
            tradingPairList,
            tradingPairs,
            Types.calculatedUserCrossDataParams({
                pairId: 0,
                trader: params.trader,
                aavePool: params.aavePool,
                aaveOracle: params.aaveOracle,
                uniFactory: params.uniFactory,
                tradingPairCount: tradingPairCount,
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
        bool empty = ITradePair(params.pairAddress).withdrawFundCross(
            params.trader,
            params.amountToWithdraw.rayDiv(IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken))
        );
        // update user config
        if (empty && params.userConfig.isNullAllEx0()) {
            traderConfig.setDeposit(0, false);
        }
        emit Withdraw(0, params.trader, params.amountToWithdraw);
    }
}
