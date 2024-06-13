// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ErrorList} from "../helpers/ErrorList.sol";
import {ITradePair} from "../../interfaces/ITradePair.sol";
import {Types} from "../types/Types.sol";
import {TradePairConfig} from "../configuration/TradePairConfig.sol";
import {TraderConfig} from "../configuration/TraderConfig.sol";
import {IsolatedLogic} from "./IsolatedLogic.sol";
import {Math} from "../../dependencies/openzeppelin/contracts/Math.sol";
import "hardhat/console.sol";

library ValidatingLogic {
    using Math for uint256;
    using TradePairConfig for Types.tradingPairConfigMap;
    using TraderConfig for Types.traderConfigMap;

    function validateDropPair(bytes32 hashedPair, address pairAddress) external view {
        require(hashedPair != bytes32(0) && pairAddress != address(0), ErrorList.PAIR_NOT_ADDED);

        (, , , Types.tradingPairConfigMap memory currentConfig) = ITradePair(pairAddress).isolatedTradingPairData();
        require(currentConfig.getIsLive() == false, ErrorList.PAIR_NOT_DEAD);
    }

    function validateDepositFund(Types.executeDepositFundParams memory params) external view {
        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.amountToDeposit != 0, ErrorList.INVALID_AMOUNT);

        (, , , Types.tradingPairConfigMap memory currentConfig) = ITradePair(params.pairAddress)
            .isolatedTradingPairData();
        require(currentConfig.getIsLive() == true, ErrorList.PAIR_IS_DEAD);
    }

    function validateOpenLong(
        Types.traderConfigMap memory traderConfig,
        Types.executeOpenLongParams memory params
    ) external pure {
        require(traderConfig.isDeposit(params.pairId), ErrorList.TRADER_HAS_NOT_DEPOSITED);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(
            params.leverage > 1 && params.leverage <= params.config.getMaximumLeverage(),
            ErrorList.INVALID_LEVERAGE
        );

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateOpenLongCross(
        Types.traderConfigMap memory traderConfig,
        Types.executeOpenLongCrossParams memory params
    ) external pure {
        require(traderConfig.isDeposit(0), ErrorList.TRADER_HAS_NOT_DEPOSITED);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(params.leverage <= params.config.getMaximumLeverage(), ErrorList.INVALID_LEVERAGE);

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateOpenShort(
        Types.traderConfigMap memory traderConfig,
        Types.executeOpenShortParams memory params
    ) external pure {
        require(traderConfig.isDeposit(params.pairId), ErrorList.TRADER_HAS_NOT_DEPOSITED);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(
            params.leverage > 1 && params.leverage <= params.config.getMaximumLeverage(),
            ErrorList.INVALID_LEVERAGE
        );

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateOpenShortCross(
        Types.traderConfigMap memory traderConfig,
        Types.executeOpenShortCrossParams memory params
    ) external pure {
        require(traderConfig.isDeposit(0), ErrorList.TRADER_HAS_NOT_DEPOSITED);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(params.leverage <= params.config.getMaximumLeverage(), ErrorList.INVALID_LEVERAGE);

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateCloseLong(
        Types.traderConfigMap memory traderConfig,
        Types.executeCloseLongParams memory params
    ) external pure {
        require(traderConfig.isLong(params.pairId), ErrorList.TRADER_HAS_NOT_LONG);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateCloseLongCross(
        Types.traderConfigMap memory traderConfig,
        Types.executeCloseLongCrossParams memory params
    ) external pure {
        require(traderConfig.isLong(params.pairId), ErrorList.TRADER_HAS_NOT_LONG);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateCloseShort(
        Types.traderConfigMap memory traderConfig,
        Types.executeCloseShortParams memory params
    ) external pure {
        require(traderConfig.isShort(params.pairId), ErrorList.TRADER_HAS_NOT_SHORT);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateCloseShortCross(
        Types.traderConfigMap memory traderConfig,
        Types.executeCloseShortCrossParams memory params
    ) external pure {
        require(traderConfig.isShort(params.pairId), ErrorList.TRADER_HAS_NOT_SHORT);

        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.baseAmount != 0, ErrorList.INVALID_AMOUNT);

        require(params.config.getIsLive() == true, ErrorList.PAIR_IS_DEAD);

        require(params.uniPool != address(0), ErrorList.ADDRESS_ZERO);
    }

    function validateLiquidate(uint256 baseAmount, uint256 maxLiquidatableAmount) external pure {
        require(baseAmount <= maxLiquidatableAmount, ErrorList.AMOUNT_LIQUIDATED_TOO_LARGE);
    }

    function validateWithdraw(
        Types.traderConfigMap memory traderConfig,
        Types.executeWithdrawParams memory params
    ) external pure {
        require(traderConfig.isDeposit(params.pairId), ErrorList.TRADER_HAS_NOT_DEPOSITED);
        require(params.pairId != 0, ErrorList.PAIR_0_NOT_FOR_TRADING);
        require(params.pairAddress != address(0), ErrorList.ADDRESS_ZERO);
        require(params.amountToWithdraw != 0, ErrorList.INVALID_AMOUNT);
    }
}
