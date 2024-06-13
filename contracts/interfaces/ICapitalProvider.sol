// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ICapitalProvider {
    function supplyCap() external view returns (uint256);

    function supply(uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) external;

    function withdraw(uint256 amount) external;

    function setSupplyCap(uint256 cap) external;

    function getCapitalProviderInfo(address user) external view returns (uint256);

    function initCP() external;
}
