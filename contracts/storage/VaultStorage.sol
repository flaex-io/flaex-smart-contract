// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../libraries/types/Types.sol";

/**
 * @title Vault Storage
 * @author Flaex
 * @notice Contract used as storage of the Vault contract.
 * @dev It defines the storage layout of the Vault contract.
 */

contract VaultStorage {
    address internal _eligibleStablecoin;

    Types.commissionFeeData internal _scaledCom;

    mapping(address => uint256) internal _liquidationIncentiveProtocol;
}
