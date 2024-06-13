// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library SignatureExecutorTypes {
    struct SigDepositFundParams {
        uint16 pairId;
        uint256 amountToDeposit;
        address beneficiary;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    struct SigDepositFundCrossParams {
        uint256 amountToDeposit;
        address beneficiary;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    struct SigOpenLongParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 maxQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigOpenShortParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 minQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigCloseLongParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount; // type(uint256).max for 100% close
        uint256 minQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigCloseShortParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount;
        uint256 maxQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigWithdrawFundParams {
        uint16 pairId;
        address trader;
        uint256 amountToWithdraw;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigWithdrawFundCrossParams {
        address trader;
        uint256 amountToWithdraw;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigOpenLongCrossParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 maxQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigOpenShortCrossParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 minQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigCloseLongCrossParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount; // type(uint256).max for 100% close
        uint256 minQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SigCloseShortCrossParams {
        uint16 pairId;
        address trader;
        uint256 baseAmount;
        uint256 maxQuoteAmount; // this will be used for limit orders
        uint160 sqrtPriceLimitX96; // to ensure the swap doesn't slip too far away
        uint24 uniFee;
        uint256 nonce;
        uint256 deadline;
    }
}
