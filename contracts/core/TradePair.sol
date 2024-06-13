// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// openzeppelin
import {Initializable} from "../dependencies/openzeppelin/upgradability/Initializable.sol";
import {UUPSUpgradeable} from "../dependencies/openzeppelin/upgradability/UUPSUpgradeable.sol";

import {Types} from "../libraries/types/Types.sol";
import {ITradePair} from "../interfaces/ITradePair.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";
import {IIsolatedMargin} from "../interfaces/IIsolatedMargin.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {ITradePair} from "../interfaces/ITradePair.sol";
import {IAC} from "../interfaces/IAC.sol";
import {TradePairConfig} from "../libraries/configuration/TradePairConfig.sol";

/**
 * @title Trading Pair Data
 * @author Flaex
 * @notice Contract that stores user's position data.
 */

contract TradePair is Initializable, UUPSUpgradeable, ITradePair {
    using TradePairConfig for Types.tradingPairConfigMap;

    IAddressesProvider public override FLAEX_PROVIDER;

    address public override baseToken;
    address public override quoteToken;

    Types.tradingPairData public override isolatedTradingPairData;

    Types.tradingPairData public override crossTradingPairData;

    // mapping of Isolated position
    mapping(address => Types.positionData) public override isolatedPosition;
    // mapping of Cross position
    mapping(address => Types.crossPositionData) public override crossPosition;

    /// @dev only pair admin can call
    modifier onlyPairAdmin() {
        _onlyPairAdmin();
        _;
    }

    function _onlyPairAdmin() internal view virtual {
        IAC AC = IAC(FLAEX_PROVIDER.getAC());
        require(AC.isPairAdmin(msg.sender), ErrorList.CALLER_NOT_PAIR_ADMIN);
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

    /// @dev only owner can call
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view virtual {
        require(
            msg.sender == FLAEX_PROVIDER.Owner(),
            ErrorList.CALLER_NOT_OWNER
        );
    }

    function initialize(
        IAddressesProvider provider,
        address _baseToken,
        address _quoteToken
    ) external virtual initializer {
        FLAEX_PROVIDER = provider;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        __UUPSUpgradeable_init();
    }

    /**
     * @notice overridden function to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getIsolatedConfig()
        external
        view
        returns (Types.tradingPairConfigMap memory)
    {
        return isolatedTradingPairData.config;
    }

    function getCrossConfig()
        external
        view
        returns (Types.tradingPairConfigMap memory)
    {
        return crossTradingPairData.config;
    }

    function initIsolatedPair(
        pairSettings memory settings
    ) external virtual override onlyPairAdmin {
        isolatedTradingPairData.baseToken = baseToken;
        isolatedTradingPairData.quoteToken = quoteToken;
        Types.tradingPairConfigMap memory vars;

        vars.setCommissionFee(settings.commissionFee);
        vars.setCommissionFeeProtocol(settings.commissionFeeProtocol);
        vars.setMaximumLeverage(settings.maxLeverage);
        vars.setLiquidationThreshold(settings.liquidationThreshold);
        vars.setLiquidationFactor(settings.liquidationFactor);
        vars.setLiquidationIncentive(settings.liquidationIncentive);
        vars.setLiquidationProtocol(settings.liquidataionProtocol);
        vars.setDefaultGasFee(settings.defaultGasFee);
        vars.setSecondsAgo(settings.secondsAgo);
        vars.setBaseDecimals(settings.baseDecimals);
        vars.setQuoteDecimals(settings.quoteDecimals);
        vars.setMarginCallThreshold(settings.marginCallThreshold);
        vars.setDeviation(settings.deviation);
        vars.setDefaultUniFee(settings.defaultUniFee);
        vars.setIsLive(true);

        isolatedTradingPairData.config = vars;

        // emit IsolatedPairInitiated(
        //     settings.commissionFee,
        //     settings.commissionFeeProtocol,
        //     settings.maxLeverage,
        //     settings.liquidationThreshold,
        //     settings.liquidationFactor,
        //     settings.liquidationIncentive,
        //     settings.liquidataionProtocol,
        //     settings.secondsAgo,
        //     settings.defaultGasFee,
        //     settings.baseDecimals,
        //     settings.quoteDecimals,
        //     settings.marginCallThreshold,
        //     settings.deviation,
        //     settings.defaultUniFee,
        //     true
        // );
    }

    function updateIsolatedPair(
        pairSettings memory settings
    ) external virtual override onlyPairAdmin {
        Types.tradingPairConfigMap memory vars;
        vars.setCommissionFee(settings.commissionFee);
        vars.setCommissionFeeProtocol(settings.commissionFeeProtocol);
        vars.setMaximumLeverage(settings.maxLeverage);
        vars.setLiquidationThreshold(settings.liquidationThreshold);
        vars.setLiquidationFactor(settings.liquidationFactor);
        vars.setLiquidationIncentive(settings.liquidationIncentive);
        vars.setLiquidationProtocol(settings.liquidataionProtocol);
        vars.setDefaultGasFee(settings.defaultGasFee);
        vars.setSecondsAgo(settings.secondsAgo);
        vars.setBaseDecimals(settings.baseDecimals);
        vars.setQuoteDecimals(settings.quoteDecimals);
        vars.setMarginCallThreshold(settings.marginCallThreshold);
        vars.setDeviation(settings.deviation);
        vars.setDefaultUniFee(settings.defaultUniFee);
        vars.setIsLive(settings.isLive);

        isolatedTradingPairData.config = vars;

        // emit IsolatedPairUpdated(
        //     settings.commissionFee,
        //     settings.commissionFeeProtocol,
        //     settings.maxLeverage,
        //     settings.liquidationThreshold,
        //     settings.liquidationFactor,
        //     settings.liquidationIncentive,
        //     settings.liquidataionProtocol,
        //     settings.secondsAgo,
        //     settings.defaultGasFee,
        //     settings.baseDecimals,
        //     settings.quoteDecimals,
        //     settings.marginCallThreshold,
        //     settings.deviation,
        //     settings.defaultUniFee,
        //     settings.isLive
        // );
    }

    function initCrossPair(
        pairSettings memory settings
    ) external virtual override onlyPairAdmin {
        crossTradingPairData.baseToken = baseToken;
        crossTradingPairData.quoteToken = quoteToken;

        Types.tradingPairConfigMap memory vars;

        vars.setCommissionFee(settings.commissionFee);
        vars.setCommissionFeeProtocol(settings.commissionFeeProtocol);
        vars.setMaximumLeverage(settings.maxLeverage);
        vars.setLiquidationThreshold(settings.liquidationThreshold);
        vars.setLiquidationFactor(settings.liquidationFactor);
        vars.setLiquidationIncentive(settings.liquidationIncentive);
        vars.setLiquidationProtocol(settings.liquidataionProtocol);
        vars.setDefaultGasFee(settings.defaultGasFee);
        vars.setSecondsAgo(settings.secondsAgo);
        vars.setBaseDecimals(settings.baseDecimals);
        vars.setQuoteDecimals(settings.quoteDecimals);
        vars.setMarginCallThreshold(settings.marginCallThreshold);
        vars.setDeviation(settings.deviation);
        vars.setDefaultUniFee(settings.defaultUniFee);
        vars.setIsLive(true);

        crossTradingPairData.config = vars;

        // emit CrossPairInitiated(
        //     settings.commissionFee,
        //     settings.commissionFeeProtocol,
        //     settings.maxLeverage,
        //     settings.liquidationThreshold,
        //     settings.liquidationFactor,
        //     settings.liquidationIncentive,
        //     settings.liquidataionProtocol,
        //     settings.secondsAgo,
        //     settings.defaultGasFee,
        //     settings.baseDecimals,
        //     settings.quoteDecimals,
        //     settings.marginCallThreshold,
        //     settings.deviation,
        //     settings.defaultUniFee,
        //     true
        // );
    }

    function updateCrossPair(
        pairSettings memory settings
    ) external virtual override onlyPairAdmin {
        Types.tradingPairConfigMap memory vars;

        vars.setCommissionFee(settings.commissionFee);
        vars.setCommissionFeeProtocol(settings.commissionFeeProtocol);
        vars.setMaximumLeverage(settings.maxLeverage);
        vars.setLiquidationThreshold(settings.liquidationThreshold);
        vars.setLiquidationFactor(settings.liquidationFactor);
        vars.setLiquidationIncentive(settings.liquidationIncentive);
        vars.setLiquidationProtocol(settings.liquidataionProtocol);
        vars.setDefaultGasFee(settings.defaultGasFee);
        vars.setSecondsAgo(settings.secondsAgo);
        vars.setBaseDecimals(settings.baseDecimals);
        vars.setQuoteDecimals(settings.quoteDecimals);
        vars.setMarginCallThreshold(settings.marginCallThreshold);
        vars.setDeviation(settings.deviation);
        vars.setDefaultUniFee(settings.defaultUniFee);
        vars.setIsLive(settings.isLive);

        crossTradingPairData.config = vars;

        // emit CrossPairUpdated(
        //     settings.commissionFee,
        //     settings.commissionFeeProtocol,
        //     settings.maxLeverage,
        //     settings.liquidationThreshold,
        //     settings.liquidationFactor,
        //     settings.liquidationIncentive,
        //     settings.liquidataionProtocol,
        //     settings.secondsAgo,
        //     settings.defaultGasFee,
        //     settings.baseDecimals,
        //     settings.quoteDecimals,
        //     settings.marginCallThreshold,
        //     settings.deviation,
        //     settings.defaultUniFee,
        //     settings.isLive
        // );
    }

    function updateDepositIsolated(
        address trader,
        uint256 sqATokenAmount
    ) external virtual override onlyMargin returns (bool) {
        uint256 sqATokenBalance = isolatedPosition[trader].sqATokenAmount;

        isolatedPosition[trader].sqATokenAmount += sqATokenAmount;

        return sqATokenBalance == 0;
    }

    function updateDepositCross(
        address trader,
        uint256 sATokenAmount
    ) external virtual override onlyMargin returns (bool) {
        uint256 sqATokenBalance = crossPosition[trader].sATokenAmount;

        crossPosition[trader].sATokenAmount += sATokenAmount;

        return sqATokenBalance == 0;
    }

    function withdrawFundIsolated(
        address trader,
        uint256 sqATokenAmount
    ) external virtual override onlyMargin returns (bool) {
        uint256 sqATokenBalance = isolatedPosition[trader].sqATokenAmount;
        require(
            sqATokenAmount <= sqATokenBalance,
            ErrorList.BALANCE_INSUFFICIENT
        );

        isolatedPosition[trader].sqATokenAmount -= sqATokenAmount;

        return sqATokenAmount == sqATokenBalance;
    }

    function withdrawFundCross(
        address trader,
        uint256 sATokenAmount
    ) external virtual override onlyMargin returns (bool) {
        uint256 sATokenBalance = crossPosition[trader].sATokenAmount;
        require(
            sATokenAmount <= sATokenBalance,
            ErrorList.BALANCE_INSUFFICIENT
        );

        crossPosition[trader].sATokenAmount -= sATokenAmount;

        return sATokenAmount == sATokenBalance;
    }

    function openLongPositionIsolated(
        address trader,
        uint256 sbATokenAmount,
        uint256 sqATokenAmount,
        uint256 sqDebtTokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external virtual override onlyMargin {
        require(
            isolatedPosition[trader].sqATokenAmount >= sqATokenAmount,
            ErrorList.BALANCE_INSUFFICIENT
        );

        isolatedPosition[trader].sbATokenAmount += sbATokenAmount;
        isolatedPosition[trader].sqATokenAmount -= sqATokenAmount;
        isolatedPosition[trader].sqDebtTokenAmount += sqDebtTokenAmount;

        _recordCommssionFee(trader, scaledCommissionFee);

        _accumulateGasFee(trader, scaledGasFee);
    }

    function openShortPositionIsolated(
        address trader,
        uint256 sbDebtTokenAmount,
        uint256 sqATokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external virtual override onlyMargin {
        isolatedPosition[trader].sbDebtTokenAmount += sbDebtTokenAmount;
        isolatedPosition[trader].sqATokenAmount += sqATokenAmount;

        _recordCommssionFee(trader, scaledCommissionFee);
        _accumulateGasFee(trader, scaledGasFee);
    }

    function closeLongPositionIsolated(
        address trader,
        uint256 sbATokenAmount,
        uint256 sqATokenAmount,
        uint256 sqDebtTokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external virtual override onlyMargin {
        isolatedPosition[trader].sbATokenAmount -= sbATokenAmount;
        isolatedPosition[trader].sqATokenAmount += sqATokenAmount;
        isolatedPosition[trader].sqDebtTokenAmount -= sqDebtTokenAmount;

        _recordCommssionFee(trader, scaledCommissionFee);
        _accumulateGasFee(trader, scaledGasFee);
    }

    function closeShortPositionIsolated(
        address trader,
        uint256 sbDebtTokenAmount,
        uint256 sqATokenAmount,
        uint256 scaledCommissionFee,
        uint256 scaledGasFee
    ) external virtual override onlyMargin {
        isolatedPosition[trader].sbDebtTokenAmount -= sbDebtTokenAmount;
        isolatedPosition[trader].sqATokenAmount -= sqATokenAmount;

        _recordCommssionFee(trader, scaledCommissionFee);
        _accumulateGasFee(trader, scaledGasFee);
    }

    //              aETH    dETH    aUSDC   dUSDC
    // openLong       +               -       +
    // openShort              +       +
    // closeLong      -               +       -
    // closeShort             -       -

    function increaseSAToken(
        address trader,
        uint256 sATokenAmount
    ) external virtual override onlyMargin {
        crossPosition[trader].sATokenAmount += sATokenAmount;
    }

    function decreaseSAToken(
        address trader,
        uint256 sATokenAmount
    ) external virtual override onlyMargin {
        crossPosition[trader].sATokenAmount -= sATokenAmount;
    }

    function increaseSDebtToken(
        address trader,
        uint256 sDebtTokenAmount
    ) external virtual override onlyMargin {
        crossPosition[trader].sDebtTokenAmount += sDebtTokenAmount;
    }

    function decreaseSDebtToken(
        address trader,
        uint256 sDebtTokenAmount
    ) external virtual override onlyMargin {
        crossPosition[trader].sDebtTokenAmount -= sDebtTokenAmount;
    }

    function accumulateGasFee(
        uint256 scaledGasFee
    ) external virtual override onlyMargin {
        crossTradingPairData.gasFeeAccumulated += scaledGasFee;
    }

    function _accumulateGasFee(address trader, uint256 scaledGasFee) private {
        require(
            isolatedPosition[trader].sqATokenAmount >= scaledGasFee,
            ErrorList.BALANCE_INSUFFICIENT
        );
        isolatedTradingPairData.gasFeeAccumulated += scaledGasFee;
        isolatedPosition[trader].sqATokenAmount -= scaledGasFee;
    }

    function _recordCommssionFee(
        address trader,
        uint256 scaledCommissionFee
    ) private {
        require(
            isolatedPosition[trader].sqATokenAmount >= scaledCommissionFee,
            ErrorList.BALANCE_INSUFFICIENT
        );
        isolatedPosition[trader].sqATokenAmount -= scaledCommissionFee;
    }

    function withdrawGasFee()
        external
        virtual
        override
        onlyMargin
        returns (uint256 scaledGasFeeWithdrawn)
    {
        scaledGasFeeWithdrawn = isolatedTradingPairData.gasFeeAccumulated;
        isolatedTradingPairData.gasFeeAccumulated = 0;
    }

    function getUserPosition(
        address user
    ) external view virtual override returns (Types.positionData memory) {
        return isolatedPosition[user];
    }

    function getUserCrossPosition(
        address user
    ) external view virtual override returns (Types.crossPositionData memory) {
        return crossPosition[user];
    }
}
