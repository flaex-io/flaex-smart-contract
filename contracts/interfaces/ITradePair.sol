// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../libraries/types/Types.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";

interface ITradePair {
    // event IsolatedPairInitiated(
    //     uint256 commissionFee,
    //     uint256 commissionFeeProtocol,
    //     uint256 maxLeverage,
    //     uint256 liquidationThreshold,
    //     uint256 liquidationFactor,
    //     uint256 liquidationIncentive,
    //     uint256 liquidataionProtocol,
    //     uint256 defaultGasFee,
    //     uint256 secondsAgo,
    //     uint256 baseDecimals,
    //     uint256 quoteDecimals,
    //     uint256 marginCallThreshold,
    //     uint256 deviation,
    //     uint256 defaultUniFee,
    //     bool isLive
    // );

    // event CrossPairInitiated(
    //     uint256 commissionFee,
    //     uint256 commissionFeeProtocol,
    //     uint256 maxLeverage,
    //     uint256 liquidationThreshold,
    //     uint256 liquidationFactor,
    //     uint256 liquidationIncentive,
    //     uint256 liquidataionProtocol,
    //     uint256 defaultGasFee,
    //     uint256 secondsAgo,
    //     uint256 baseDecimals,
    //     uint256 quoteDecimals,
    //     uint256 marginCallThreshold,
    //     uint256 deviation,
    //     uint256 defaultUniFee,
    //     bool isLive
    // );

    // event IsolatedPairUpdated(
    //     uint256 newCommissionFee,
    //     uint256 newCommissionFeeProtocol,
    //     uint256 newMaxLeverage,
    //     uint256 newLiquidationThreshold,
    //     uint256 newLiquidationFactor,
    //     uint256 newLiquidationIncentive,
    //     uint256 newLiquidataionProtocol,
    //     uint256 newDefaultGasFee,
    //     uint256 newSecondsAgo,
    //     uint256 newBaseDecimals,
    //     uint256 newQuoteDecimals,
    //     uint256 newMarginCallThreshold,
    //     uint256 newDeviation,
    //     uint256 mewDefaultUniFee,
    //     bool newStatus
    // );

    // event CrossPairUpdated(
    //     uint256 newCommissionFee,
    //     uint256 newCommissionFeeProtocol,
    //     uint256 newMaxLeverage,
    //     uint256 newLiquidationThreshold,
    //     uint256 newLiquidationFactor,
    //     uint256 newLiquidationIncentive,
    //     uint256 newLiquidataionProtocol,
    //     uint256 newDefaultGasFee,
    //     uint256 newSecondsAgo,
    //     uint256 newBaseDecimals,
    //     uint256 newQuoteDecimals,
    //     uint256 newMarginCallThreshold,
    //     uint256 newDeviation,
    //     uint256 mewDefaultUniFee,
    //     bool newStatus
    // );

    struct pairSettings {
        uint256 commissionFee;
        uint256 commissionFeeProtocol;
        uint256 maxLeverage;
        uint256 liquidationThreshold;
        uint256 liquidationFactor;
        uint256 liquidationIncentive;
        uint256 liquidataionProtocol;
        uint256 defaultGasFee;
        uint256 secondsAgo;
        uint256 baseDecimals;
        uint256 quoteDecimals;
        uint256 marginCallThreshold;
        uint256 defaultUniFee;
        uint256 deviation;
        bool isLive;
    }

    function FLAEX_PROVIDER() external view returns (IAddressesProvider);

    function baseToken() external view returns (address);

    function quoteToken() external view returns (address);

    function getIsolatedConfig() external view returns (Types.tradingPairConfigMap memory);

    function getCrossConfig() external view returns (Types.tradingPairConfigMap memory);

    function isolatedTradingPairData()
        external
        view
        returns (
            address baseToken,
            address quoteToken,
            uint256 gasFeeAccumulated,
            Types.tradingPairConfigMap memory config
        );

    function crossTradingPairData()
        external
        view
        returns (
            address baseToken,
            address quoteToken,
            uint256 gasFeeAccumulated,
            Types.tradingPairConfigMap memory config
        );

    function isolatedPosition(
        address user
    )
        external
        view
        returns (
            uint256 scaledBaseATokenAmount,
            uint256 scaledBaseDebtTokenAmount,
            uint256 scaledQuoteATokenAmount,
            uint256 scaledQuoteDebtTokenAmount
        );

    function crossPosition(
        address user
    ) external view returns (uint256 scaledATokenAmount, uint256 scaledDebtTokenAmount);

    function initIsolatedPair(pairSettings memory settings) external;

    function updateIsolatedPair(pairSettings memory settings) external;

    function initCrossPair(pairSettings memory settings) external;

    function updateCrossPair(pairSettings memory settings) external;

    function updateDepositIsolated(address _trader, uint256 _sqATokenAmount) external returns (bool);

    function withdrawFundCross(address trader, uint256 sATokenAmount) external returns (bool);

    function withdrawFundIsolated(address trader, uint256 sqATokenAmount) external returns (bool);

    function updateDepositCross(address _trader, uint256 _sqATokenAmount) external returns (bool);

    function openLongPositionIsolated(
        address trader,
        uint256 sbATokenAmount,
        uint256 sqATokenAmount,
        uint256 sqDebtTokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external;

    function openShortPositionIsolated(
        address trader,
        uint256 sbDebtTokenAmount,
        uint256 sqATokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external;

    function closeLongPositionIsolated(
        address trader,
        uint256 sbATokenAmount,
        uint256 sqATokenAmount,
        uint256 sqDebtTokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external;

    function closeShortPositionIsolated(
        address trader,
        uint256 sbDebtTokenAmount,
        uint256 sqATokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external;

    function increaseSAToken(address trader, uint256 sATokenAmount) external;

    function decreaseSAToken(address trader, uint256 sATokenAmount) external;

    function increaseSDebtToken(address trader, uint256 sDebtTokenAmount) external;

    function decreaseSDebtToken(address trader, uint256 sDebtTokenAmount) external;

    function accumulateGasFee(uint256 scaledGasFee) external;

    function withdrawGasFee() external returns (uint256 scaledGasFeeWithdrawn);

    function getUserPosition(address user) external view returns (Types.positionData memory);

    function getUserCrossPosition(address user) external view returns (Types.crossPositionData memory);
}
