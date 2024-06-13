// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {SignatureExecutorTypes} from "../libraries/types/SignatureExecutorTypes.sol";

interface IIsolatedMargin {
    function registerPair(address baseToken, address quoteToken, address pairAddress) external;

    function dropPair(uint16 pairId) external;

    function setAaveReferralCode(uint16 code) external;

    /// @dev deposit is free of gas always
    function depositFund(
        uint16 pairId,
        uint256 amountToDeposit,
        address beneficiary,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external;

    function openLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint16 leverage,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external;

    function openShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint16 leverage,
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external;

    function closeLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external;

    function closeShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external;

    function liquidateLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount, // type(uint256).max for 100% close
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external;

    function liquidateShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external;

    function withdrawFund(uint16 pairId, address trader, uint256 amountToWithdraw) external;

    function collectGasFee(uint16[] calldata pairId, address treasury) external;

    function collectCommissionFee(uint256 amount, address treasury) external;

    function collectLiquidationIncentive(address asset, uint256 amount, address treasury) external;

    function getUserData(
        address user,
        uint16 pairId
    ) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool);
}
