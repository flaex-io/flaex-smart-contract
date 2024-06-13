// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../types/Types.sol";
import {ErrorList} from "../helpers/ErrorList.sol";

/**
 * @title trade pair config library
 * @author flaex
 * @notice Implements the bitmap logic
 */

// bit 0-15: commissionFee, 0.05% = 5
// bit 16-31: commisison fee protocol share, 60% = 6000
// bit 32-47: Maximum Leverage, 20 = 20
// bit 48-63: Liq. threshold, 1.1 = 110
// bit 64-79: Liq. factor, 50% = 5000
// bit 80-95: Liq. incentive, 5% = 500
// bit 96-111: Liq. protocol share, 40% = 4000
// bit 112-127: default gas fee, 0.4 usd = 40
// bit 128-143: secondsAgo, used for uniswap pricing, 5 = 5
// bit 144-159: baseToken decimals, 18 = 18
// bit 159-175: quoteToken decimals, 6 = 6
// bit 176-191: margin call threshold, 1.2 = 120
// bit 192-207: standard deviation, 3% = 300
// bit 208: is Live

library TradePairConfig {
    uint256 internal constant COMMISSION_MASK =                         0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; //prettier-ignore
    uint256 internal constant COMMISSION_PROTOCOL_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; //prettier-ignore
    uint256 internal constant MAX_LEVERAGE_MASK_MASK =                  0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; //prettier-ignore
    uint256 internal constant LIQUIDATION_THRESHOLD_MASK =              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant LIQUIDATION_FACTOR_MASK =                 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant LIQUIDATION_INCENTIVE_MASK =              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant LIQUIDATION_INCENTIVE_PROTOCOL_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant DEFAULT_GAS_FEE_MASK =                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant SECONDS_AGO_MASK =                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant BASE_DECIMALS_MASK =                      0xFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant QUOTE_DECIMALS_MASK =                     0xFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant MARGIN_CALL_MASK =                        0xFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant DEVIATION_MASK =                          0xFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant DEFAULT_UNI_FEE_MASK =                    0xFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore
    uint256 internal constant IS_LIVE_MASK =                            0xFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //prettier-ignore

    uint256 internal constant COMMISSION_PROTOCOL_BITPOS = 16;
    uint256 internal constant MAXIMUM_LEVERAGE_BITPOS = 32;
    uint256 internal constant LIQUIDATION_THRESHOLD_BITPOS = 48;
    uint256 internal constant LIQUIDATION_FACTOR_BITPOS = 64;
    uint256 internal constant LIQUIDATION_INCENTIVE_BITPOS = 80;
    uint256 internal constant LIQUIDATION_PROTOCOL_BITPOS = 96;
    uint256 internal constant DEFAULT_GAS_FEE_BITPOS = 112;
    uint256 internal constant SECONDS_AGO_BITPOS = 128;
    uint256 internal constant BASE_DECIMALS_BITPOS = 144;
    uint256 internal constant QUOTE_DECIMALS_BITPOS = 160;
    uint256 internal constant MARGIN_CALL_BITPOS = 176;
    uint256 internal constant DEVIATION_BITPOS = 192;
    uint256 internal constant DEFAULT_UNI_FEE_BITPOS = 208;
    uint256 internal constant IS_LIVE_BITPOS = 224;

    uint256 internal constant MAXIMUM_16_BIT_VALUE = type(uint16).max;

    function setCommissionFee(Types.tradingPairConfigMap memory self, uint256 commissionFee) internal pure {
        require(commissionFee < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & COMMISSION_MASK) | commissionFee;
    }

    function getCommissionFee(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return self.info & ~COMMISSION_MASK;
    }

    function setCommissionFeeProtocol(
        Types.tradingPairConfigMap memory self,
        uint256 commissionFeeProtocol
    ) internal pure {
        require(commissionFeeProtocol < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & COMMISSION_PROTOCOL_MASK) | (commissionFeeProtocol << COMMISSION_PROTOCOL_BITPOS);
    }

    function getCommissionFeeProtocol(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~COMMISSION_PROTOCOL_MASK) >> COMMISSION_PROTOCOL_BITPOS;
    }

    function setMaximumLeverage(Types.tradingPairConfigMap memory self, uint256 maximumLeverage) internal pure {
        require(maximumLeverage < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & MAX_LEVERAGE_MASK_MASK) | (maximumLeverage << MAXIMUM_LEVERAGE_BITPOS);
    }

    function getMaximumLeverage(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~MAX_LEVERAGE_MASK_MASK) >> MAXIMUM_LEVERAGE_BITPOS;
    }

    function setLiquidationThreshold(
        Types.tradingPairConfigMap memory self,
        uint256 liquidationThreshold
    ) internal pure {
        require(liquidationThreshold < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & LIQUIDATION_THRESHOLD_MASK) | (liquidationThreshold << LIQUIDATION_THRESHOLD_BITPOS);
    }

    function getLiquidationThreshold(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_BITPOS;
    }

    function setLiquidationFactor(Types.tradingPairConfigMap memory self, uint256 liquidationFactor) internal pure {
        require(liquidationFactor < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & LIQUIDATION_FACTOR_MASK) | (liquidationFactor << LIQUIDATION_FACTOR_BITPOS);
    }

    function getLiquidationFactor(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~LIQUIDATION_FACTOR_MASK) >> LIQUIDATION_FACTOR_BITPOS;
    }

    function setLiquidationIncentive(
        Types.tradingPairConfigMap memory self,
        uint256 liquidationIncentive
    ) internal pure {
        require(liquidationIncentive < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & LIQUIDATION_INCENTIVE_MASK) | (liquidationIncentive << LIQUIDATION_INCENTIVE_BITPOS);
    }

    function getLiquidationIncentive(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~LIQUIDATION_INCENTIVE_MASK) >> LIQUIDATION_INCENTIVE_BITPOS;
    }

    function setLiquidationProtocol(
        Types.tradingPairConfigMap memory self,
        uint256 liquidationProtocol
    ) internal pure {
        require(liquidationProtocol < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info =
            (self.info & LIQUIDATION_INCENTIVE_PROTOCOL_MASK) |
            (liquidationProtocol << LIQUIDATION_PROTOCOL_BITPOS);
    }

    function getLiquidationProtocol(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~LIQUIDATION_INCENTIVE_PROTOCOL_MASK) >> LIQUIDATION_PROTOCOL_BITPOS;
    }

    function setDefaultGasFee(Types.tradingPairConfigMap memory self, uint256 defaultGasFee) internal pure {
        require(defaultGasFee < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & DEFAULT_GAS_FEE_MASK) | (defaultGasFee << DEFAULT_GAS_FEE_BITPOS);
    }

    function getDefaultGasFee(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~DEFAULT_GAS_FEE_MASK) >> DEFAULT_GAS_FEE_BITPOS;
    }

    function setSecondsAgo(Types.tradingPairConfigMap memory self, uint256 secondsAgo) internal pure {
        require(secondsAgo < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & SECONDS_AGO_MASK) | (secondsAgo << SECONDS_AGO_BITPOS);
    }

    function getSecondsAgo(Types.tradingPairConfigMap memory self) internal pure returns (uint32) {
        return uint32((self.info & ~SECONDS_AGO_MASK) >> SECONDS_AGO_BITPOS);
    }

    function setBaseDecimals(Types.tradingPairConfigMap memory self, uint256 decimals) internal pure {
        require(decimals < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & BASE_DECIMALS_MASK) | (decimals << BASE_DECIMALS_BITPOS);
    }

    function getBaseDecimals(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~BASE_DECIMALS_MASK) >> BASE_DECIMALS_BITPOS;
    }

    function setQuoteDecimals(Types.tradingPairConfigMap memory self, uint256 decimals) internal pure {
        require(decimals < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & QUOTE_DECIMALS_MASK) | (decimals << QUOTE_DECIMALS_BITPOS);
    }

    function getQuoteDecimals(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~QUOTE_DECIMALS_MASK) >> QUOTE_DECIMALS_BITPOS;
    }

    function setMarginCallThreshold(Types.tradingPairConfigMap memory self, uint256 marginCall) internal pure {
        require(marginCall < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & MARGIN_CALL_MASK) | (marginCall << MARGIN_CALL_BITPOS);
    }

    function getMarginCallThreshold(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~MARGIN_CALL_MASK) >> MARGIN_CALL_BITPOS;
    }

    function setDeviation(Types.tradingPairConfigMap memory self, uint256 deviation) internal pure {
        require(deviation < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & DEVIATION_MASK) | (deviation << DEVIATION_BITPOS);
    }

    function getDeviation(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~DEVIATION_MASK) >> DEVIATION_BITPOS;
    }

    function setDefaultUniFee(Types.tradingPairConfigMap memory self, uint256 uniFee) internal pure {
        require(uniFee < MAXIMUM_16_BIT_VALUE, ErrorList.EXCEED_MAXIMUM_VALUE);

        self.info = (self.info & DEFAULT_UNI_FEE_MASK) | (uniFee << DEFAULT_UNI_FEE_BITPOS);
    }

    function getDefaultUniFee(Types.tradingPairConfigMap memory self) internal pure returns (uint256) {
        return (self.info & ~DEFAULT_UNI_FEE_MASK) >> DEFAULT_UNI_FEE_BITPOS;
    }

    function setIsLive(Types.tradingPairConfigMap memory self, bool isLive) internal pure {
        unchecked {
            self.info = (self.info & IS_LIVE_MASK) | (uint256(isLive ? 1 : 0) << IS_LIVE_BITPOS);
        }
    }

    function getIsLive(Types.tradingPairConfigMap memory self) internal pure returns (bool) {
        unchecked {
            return (self.info & ~IS_LIVE_BITPOS) != 0;
        }
    }
}
