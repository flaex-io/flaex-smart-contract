// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../types/Types.sol";
import {ITradePair} from "../../interfaces/ITradePair.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {Address} from "../../dependencies/openzeppelin/contracts/Address.sol";
import {Math} from "../../dependencies/openzeppelin/contracts/Math.sol";

import {ErrorList} from "../../libraries/helpers/ErrorList.sol";
import {ValidatingLogic} from "./ValidatingLogic.sol";
import {IAddressesProvider} from "../../interfaces/IAddressesProvider.sol";
import {TraderConfig} from "../configuration/TraderConfig.sol";
import {TradePairConfig} from "../configuration/TradePairConfig.sol";
import "hardhat/console.sol";

import {IERC20} from "../../dependencies/openzeppelin/contracts/IERC20.sol";

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {WadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import {IPriceOracleGetter} from "@aave/core-v3/contracts/interfaces/IPriceOracleGetter.sol";
import {OracleLibrary} from "../../dependencies/v3-periphery/libraries/OracleLibrary.sol";

library IsolatedLogic {
    using Math for uint256;
    using WadRayMath for uint256;
    using TraderConfig for Types.traderConfigMap;
    using TradePairConfig for Types.tradingPairConfigMap;

    event GasFeeCollected(uint16 pairId, uint256 gasFee);
    event CommissionFeeCollected(uint256 commissionFee);
    event LiquidationIncentiveCollected(address asset, uint256 incentive);

    function executeRegisterPair(
        mapping(bytes32 => address) storage tradingPairs,
        mapping(uint16 => bytes32) storage tradingPairList,
        Types.executeRegisterPairParams memory params
    ) external returns (bool) {
        require(Address.isContract(params.pairAddress), ErrorList.IS_NOT_CONTRACT);

        require(
            tradingPairs[keccak256(abi.encode(params.baseToken, params.quoteToken))] == address(0),
            ErrorList.PAIR_ALREADY_ADDED
        );

        IERC20(params.baseToken).approve(params.aavePool, type(uint256).max);
        IERC20(params.quoteToken).approve(params.aavePool, type(uint256).max);

        for (uint16 i = 1; i < params.tradingPairCount; i++) {
            if (tradingPairList[i] == bytes32(0)) {
                tradingPairList[i] = keccak256(abi.encode(params.baseToken, params.quoteToken));
                tradingPairs[keccak256(abi.encode(params.baseToken, params.quoteToken))] = params.pairAddress;
                return false;
            }
        }

        tradingPairs[keccak256(abi.encode(params.baseToken, params.quoteToken))] = params.pairAddress;
        tradingPairList[params.tradingPairCount] = keccak256(abi.encode(params.baseToken, params.quoteToken));

        return true;
    }

    function executeDropPair(
        mapping(bytes32 => address) storage tradingPairs,
        mapping(uint16 => bytes32) storage tradingPairList,
        uint16 pairId
    ) external {
        ValidatingLogic.validateDropPair(tradingPairList[pairId], tradingPairs[tradingPairList[pairId]]);

        delete tradingPairs[tradingPairList[pairId]];
        delete tradingPairList[pairId];
    }

    function executeCollectGasFee(
        IAddressesProvider FLAEX_PROVIDER,
        mapping(bytes32 => address) storage tradingPairs,
        mapping(uint16 => bytes32) storage tradingPairList,
        uint16[] calldata pairId,
        address treasury
    ) external {
        for (uint16 i = 0; i < pairId.length; i++) {
            // withdraw
            // update
            address quoteToken = ITradePair(tradingPairs[tradingPairList[pairId[i]]]).quoteToken();
            uint256 scaledGasFee = ITradePair(tradingPairs[tradingPairList[pairId[i]]]).withdrawGasFee();

            IPool AavePool = IPool(FLAEX_PROVIDER.getAavePool());

            uint256 amountToWithdraw = scaledGasFee.rayMul(AavePool.getReserveNormalizedIncome(quoteToken));

            IVault(FLAEX_PROVIDER.getVault()).withdrawToMargin(quoteToken, amountToWithdraw, treasury);

            emit GasFeeCollected(pairId[i], amountToWithdraw);
        }
    }

    function executeCollectCommissionFee(
        IAddressesProvider FLAEX_PROVIDER,
        uint256 amount,
        address treasury
    ) external {
        IVault(FLAEX_PROVIDER.getVault()).decreaseCommissionFeePr(amount, treasury);

        emit CommissionFeeCollected(amount);
    }

    function executeCollectLiquidationIncentive(
        IAddressesProvider FLAEX_PROVIDER,
        address asset,
        uint256 amount,
        address treasury
    ) external {
        IVault(FLAEX_PROVIDER.getVault()).decreaseLiquidationIncentiveProtocol(asset, amount, treasury);

        emit LiquidationIncentiveCollected(asset, amount);
    }

    struct calculatedUserDataVars {
        uint256 baseA;
        uint256 baseD;
        uint256 quoteA;
        uint256 quoteD;
        uint256 baseAInUSD;
        uint256 baseDInUSD;
        uint256 quoteAInUSD;
        uint256 quoteDInUSD;
        uint256 baseAToQuote;
        uint256 baseDToQuote;
        uint256 available;
        uint256 aaveMarginLevel;
        uint256 uniswapMarginLevel;
        uint256 marginLevel;
        bool isValid;
    }

    /**
     * @notice Calculates user data for the pair selected
     * @return baseA Atoken amount
     * @return baseD Dtoken amount
     * @return quoteA Atoken amount
     * @return quoteD Dtoken amount
     * @return available to withdraw
     * @return margin level
     * @return isValid level
     */
    function executeGetUserData(
        Types.calculateUserDataParams memory params
    ) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool) {
        if (params.userConfig.isNull(params.pairId)) {
            return (0, 0, 0, 0, 0, type(uint256).max, true);
        }

        calculatedUserDataVars memory vars;

        vars.quoteA = params.userData.sqATokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
        );

        if (!params.userConfig.isLongOrShort(params.pairId)) {
            // vars.available = params.userData.sqATokenAmount.rayMul(
            //     IPool(params.aavePool).getReserveNormalizedIncome(params.quoteToken)
            // );
            return (0, 0, vars.quoteA, 0, vars.quoteA, type(uint256).max, true);
        }

        vars.baseA = params.userData.sbATokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedIncome(params.baseToken)
        );

        vars.baseD = params.userData.sbDebtTokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedVariableDebt(params.baseToken)
        );
        vars.quoteD = params.userData.sqDebtTokenAmount.rayMul(
            IPool(params.aavePool).getReserveNormalizedVariableDebt(params.quoteToken)
        );

        unchecked {
            vars.baseAInUSD =
                (IPriceOracleGetter(params.aaveOracle).getAssetPrice(params.baseToken) * vars.baseA) /
                (10 ** params.pairConfig.getBaseDecimals());

            vars.baseDInUSD =
                (IPriceOracleGetter(params.aaveOracle).getAssetPrice(params.baseToken) * vars.baseD) /
                (10 ** params.pairConfig.getBaseDecimals());

            vars.quoteAInUSD =
                (IPriceOracleGetter(params.aaveOracle).getAssetPrice(params.quoteToken) * vars.quoteA) /
                (10 ** params.pairConfig.getQuoteDecimals());

            vars.quoteDInUSD =
                (IPriceOracleGetter(params.aaveOracle).getAssetPrice(params.quoteToken) * vars.quoteD) /
                (10 ** params.pairConfig.getQuoteDecimals());
        }
        if (vars.baseDInUSD + vars.quoteDInUSD == 0) {
            vars.aaveMarginLevel = type(uint256).max;
        } else {
            vars.aaveMarginLevel = (vars.baseAInUSD + vars.quoteAInUSD).wadDiv(vars.baseDInUSD + vars.quoteDInUSD);
        }

        vars.baseAToQuote = OracleLibrary.getQuoteAtTick(
            OracleLibrary.consult(params.uniPool, params.pairConfig.getSecondsAgo()),
            uint128(vars.baseA), // is this safe????
            params.baseToken,
            params.quoteToken
        );

        vars.baseDToQuote = OracleLibrary.getQuoteAtTick(
            OracleLibrary.consult(params.uniPool, params.pairConfig.getSecondsAgo()),
            uint128(vars.baseD), // is this safe????
            params.baseToken,
            params.quoteToken
        );

        if (vars.baseDToQuote + vars.quoteD == 0) {
            vars.uniswapMarginLevel = type(uint256).max;
        } else {
            vars.uniswapMarginLevel = (vars.baseAToQuote + vars.quoteA).wadDiv(vars.baseDToQuote + vars.quoteD);
        }

        vars.marginLevel = vars.aaveMarginLevel == type(uint256).max || vars.uniswapMarginLevel == type(uint256).max
            ? type(uint256).max
            : (vars.aaveMarginLevel + vars.uniswapMarginLevel) / 2;

        if (vars.marginLevel == type(uint256).max) {
            vars.available = vars.quoteA;
        } else if (vars.marginLevel <= params.pairConfig.getMarginCallThreshold().wadDiv(1e2)) {
            vars.available = 0;
        } else {
            vars.available = (vars.marginLevel - params.pairConfig.getMarginCallThreshold().wadDiv(1e2)).wadMul(
                vars.baseDToQuote + vars.quoteD
            );
        }

        vars.isValid =
            (vars.uniswapMarginLevel <= vars.aaveMarginLevel) ||
            (vars.uniswapMarginLevel >= vars.aaveMarginLevel.mulDiv(1e4 - params.pairConfig.getDeviation(), 1e4));

        return (
            vars.baseA,
            vars.baseD,
            vars.quoteA,
            vars.quoteD,
            vars.available > vars.quoteA ? vars.quoteA : vars.available,
            vars.marginLevel,
            vars.isValid
        );
    }
}
