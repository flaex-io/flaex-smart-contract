// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IFlToken {
    event Transfer(address indexed from, address indexed to, uint256 amount);

    struct CPInfo {
        uint256 balance;
        uint256 yieldIndex;
    }

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function underlying() external view returns (address);

    function _balanceOf(address owner) external view returns (uint256, uint256);

    function balanceOf(address owner) external view returns (uint256);

    function mint(address to, uint256 amount, uint256 newIndex) external;

    function burn(address from, uint256 amount) external;
}
