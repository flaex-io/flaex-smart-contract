// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../libraries/types/Types.sol";

/**
 * @title Cross Margin Storage
 * @author Flaex
 * @notice Contract used as storage of the CrossMargin contract.
 * @dev It defines the storage layout of the CrossMargin contract.
 */

contract CrossStorage {
    // Map of all trading pairs
    mapping(bytes32 => address) internal _tradingPairs;

    // list of all trading pairs
    mapping(uint16 => bytes32) internal _tradingPairList;

    // Map of trader config
    mapping(address => Types.traderConfigMap) internal _traderConfig;

    // current trading pair counts
    uint16 internal _tradingPairCount;

    // aave referral code
    uint16 internal _aaveReferralCode;
}
