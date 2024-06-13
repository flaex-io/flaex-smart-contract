// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IVault {
    function getEligibleStablecoin() external view returns (address);

    function getScaledCommissionFeeCp() external view returns (uint256);

    // function decreaseCommissionFeeCp(uint256 amount, address to) external;

    function creditDelegateIsolate(address debtToken, uint256 amount) external;

    function creditDelegateCross(address debtToken, uint256 amount) external;

    function withdrawToMargin(address asset, uint256 amount, address to) external;

    function withdrawToCapitalProvider(uint256 amount, address to) external;

    function increaseCom(uint256 commission, uint256 pr) external;

    function increaseLiquidationIncentiveProtocol(address asset, uint256 scaledIncentive) external;

    function decreaseCommissionFeePr(uint256 amount, address to) external;

    function decreaseLiquidationIncentiveProtocol(address asset, uint256 incentive, address to) external;
}
