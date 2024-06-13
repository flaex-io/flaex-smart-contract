// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title Errors library
 * @author flaex
 * @notice Defines the error messages emitted
 */
library ErrorList {
    string public constant INVALID_SUPER_ADMIN = "1";
    string public constant INVALID_ISOLATED_MARGIN = "2";
    string public constant INVALID_CROSS_MARGIN = "3";
    string public constant INVALID_MARGIN = "4";
    string public constant INVALID_ADDRESS_PROVIDER = "5";
    string public constant IS_NOT_CONTRACT = "6";
    string public constant PAIR_ALREADY_ADDED = "7";
    string public constant PAIR_NOT_ADDED = "8";
    string public constant PAIR_NOT_DEAD = "9";
    string public constant SUPER_ADMIN_CANNOT_BE_ZERO = "10";
    string public constant CALLER_NOT_ISOLATED_ADMIN = "11";
    string public constant CALLER_NOT_CROSS_ADMIN = "12";
    string public constant CALLER_NOT_PAIR_ADMIN = "13";
    string public constant CALLER_NOT_LIQUIDATOR = "14";
    string public constant CALLER_NOT_EXECUTOR_ADMIN = "15";
    string public constant ADDRESS_ZERO = "16";
    string public constant INVALID_AMOUNT = "17";
    string public constant PAIR_IS_DEAD = "18";
    string public constant PAIR_0_NOT_FOR_TRADING = "19";
    string public constant INVALID_FUNCTION_EXECUTOR = "20";
    string public constant INVALID_LEVERAGE = "21";
    string public constant EXCEED_MAXIMUM_VALUE = "22";
    string public constant TRADER_HAS_NOT_DEPOSITED = "23";
    string public constant BALANCE_INSUFFICIENT = "24";
    string public constant CALLER_NOT_VAULT_ADMIN = "25";
    string public constant TOO_LITTLE_INPUT = "26";
    string public constant DEADLINE_EXPIRED = "27";
    string public constant LENGTH_MISMATCHED = "28";
    string public constant GAS_FEE_EXCEEDED_BALANCE = "29";
    string public constant CALLER_NOT_OWNER = "30";
    string public constant TOO_MUCH_OUTPUT = "31";
    string public constant MARGIN_LEVEL_LOWER_THAN_LIQ_THRESHOLD = "32";
    string public constant TRADER_HAS_NOT_LONG = "33";
    string public constant TRADER_HAS_NOT_SHORT = "34";
    string public constant TRADER_IS_NOT_LIQUIDATABLE = "35";
    string public constant MARGIN_LEVEL_NOT_LIQUIDATABLE = "36";
    string public constant AMOUNT_LIQUIDATED_TOO_LARGE = "37";
    string public constant INVALID_CAPITAL_PROVIDER = "38";
    string public constant CALLER_NOT_CAPITAL_PROVIDER_ADMIN = "39";
    string public constant SUPPLY_CAP_EXCEEDED = "40";
}
