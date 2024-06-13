// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SignatureExecutorTypes} from "../../libraries/types/SignatureExecutorTypes.sol";
import "hardhat/console.sol";

library SignatureHash {
    bytes4 public constant _DEPOSIT_TYPEHASH_SELECTOR =
        bytes4(keccak256("depositFund(uint16,uint256,address,uint256,uint256,bytes)"));

    bytes4 public constant _DEPOSIT_CROSS_TYPEHASH_SELECTOR =
        bytes4(keccak256("depositFund(uint256,address,uint256,uint256,bytes)"));

    bytes32 public constant _OPEN_LONG_TYPEHASH =
        keccak256(
            "SigOpenLongParams(uint16 pairId,address trader,uint256 baseAmount,uint16 leverage,uint256 maxQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _OPEN_SHORT_TYPEHASH =
        keccak256(
            "SigOpenShortParams(uint16 pairId,address trader,uint256 baseAmount,uint16 leverage,uint256 minQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _CLOSE_LONG_TYPEHASH =
        keccak256(
            "SigCloseLongParams(uint16 pairId,address trader,uint256 baseAmount,uint256 minQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _CLOSE_SHORT_TYPEHASH =
        keccak256(
            "SigCloseShortParams(uint16 pairId,address trader,uint256 baseAmount,uint256 maxQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _WITHDRAW_FUND_TYPEHASH =
        keccak256(
            "SigWithdrawFundParams(uint16 pairId,address trader,uint256 amountToWithdraw,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _WITHDRAW_FUND_CROSS_TYPEHASH =
        keccak256(
            "SigWithdrawFundCrossParams(address trader,uint256 amountToWithdraw,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _OPEN_LONG_CROSS_TYPEHASH =
        keccak256(
            "SigOpenLongCrossParams(uint16 pairId,address trader,uint256 baseAmount,uint16 leverage,uint256 maxQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _OPEN_SHORT_CROSS_TYPEHASH =
        keccak256(
            "SigOpenShortCrossParams(uint16 pairId,address trader,uint256 baseAmount,uint16 leverage,uint256 minQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _CLOSE_LONG_CROSS_TYPEHASH =
        keccak256(
            "SigCloseLongCrossParams(uint16 pairId,address trader,uint256 baseAmount,uint256 minQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public constant _CLOSE_SHORT_CROSS_TYPEHASH =
        keccak256(
            "SigCloseShortCrossParams(uint16 pairId,address trader,uint256 baseAmount,uint256 maxQuoteAmount,uint160 sqrtPriceLimitX96,uint24 uniFee,uint256 nonce,uint256 deadline)"
        );

    bytes4 public constant _OPEN_LONG_FUNCTION_SELECTOR =
        bytes4(keccak256("openLong(uint16,address,uint256,uint16,uint256,uint160,uint24)"));

    bytes4 public constant _OPEN_SHORT_FUNCTION_SELECTOR =
        bytes4(keccak256("openShort(uint16,address,uint256,uint16,uint256,uint160,uint24)"));

    bytes4 public constant _CLOSE_LONG_FUNCTION_SELECTOR =
        bytes4(keccak256("closeLong(uint16,address,uint256,uint256,uint160,uint24)"));

    bytes4 public constant _CLOSE_SHORT_FUNCTION_SELECTOR =
        bytes4(keccak256("closeShort(uint16,address,uint256,uint256,uint160,uint24)"));

    bytes4 public constant _WITHDRAW_FUND_FUNCTION_SELECTOR =
        bytes4(keccak256("withdrawFund(uint16,address,uint256)"));

    bytes4 public constant _WITHDRAW_FUND_CROSS_FUNCTION_SELECTOR = bytes4(keccak256("withdrawFund(address,uint256)"));

    function hash(SignatureExecutorTypes.SigOpenLongParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _OPEN_LONG_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.maxQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigOpenShortParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _OPEN_SHORT_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.minQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigCloseLongParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _CLOSE_LONG_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.minQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigCloseShortParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _CLOSE_SHORT_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.maxQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigWithdrawFundParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _WITHDRAW_FUND_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.amountToWithdraw,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigWithdrawFundCrossParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _WITHDRAW_FUND_CROSS_TYPEHASH,
                    params.trader,
                    params.amountToWithdraw,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigOpenLongCrossParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _OPEN_LONG_CROSS_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.maxQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigOpenShortCrossParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _OPEN_SHORT_CROSS_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.minQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigCloseLongCrossParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _CLOSE_LONG_CROSS_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.minQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }

    function hash(SignatureExecutorTypes.SigCloseShortCrossParams memory params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _CLOSE_SHORT_CROSS_TYPEHASH,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.maxQuoteAmount,
                    params.sqrtPriceLimitX96,
                    params.uniFee,
                    params.nonce,
                    params.deadline
                )
            );
    }
}
