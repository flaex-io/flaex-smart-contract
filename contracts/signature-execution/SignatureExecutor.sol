// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EIP712} from "../signature-execution/EIP712.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {IAC} from "../interfaces/IAC.sol";
import {ISignatureExecutor} from "../interfaces/ISignatureExecutor.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";
import {SignatureExecutorTypes} from "../libraries/types/SignatureExecutorTypes.sol";
import {SignatureHash} from "../libraries/signature/SignatureHash.sol";
import {SignatureVerifier} from "../libraries/signature/SignatureVerifier.sol";
import {Types} from "../libraries/types/Types.sol";
import "hardhat/console.sol";

/**
 * @title Signature-based Executor
 * @author Flaex
 * @dev Also the executors of open, close functions inside Margin Contracts
 */

contract SignatureExecutor is EIP712, ISignatureExecutor {
    using SignatureVerifier for bytes;

    IAddressesProvider public immutable FLAEX_PROVIDER;

    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    modifier onlyExecutorAdmin() {
        _onlyExecutorAdmin();
        _;
    }

    function _onlyExecutorAdmin() internal view virtual {
        IAC AC = IAC(FLAEX_PROVIDER.getAC());
        require(AC.isExecutorAdmin(msg.sender), ErrorList.CALLER_NOT_EXECUTOR_ADMIN);
    }

    constructor(IAddressesProvider provider) {
        FLAEX_PROVIDER = provider;
    }

    function batchDepositFund(
        SignatureExecutorTypes.SigDepositFundParams[] calldata params
    ) external virtual override onlyExecutorAdmin {
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = FLAEX_PROVIDER.getIsolatedMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._DEPOSIT_TYPEHASH_SELECTOR,
                    params[i].pairId,
                    params[i].amountToDeposit,
                    params[i].beneficiary,
                    params[i].nonce,
                    params[i].deadline,
                    params[i].signature
                )
            );
            if (!isSuccess) {
                emit DepositNotSuccess(i, returnedData);
            }
        }
    }

    function batchDepositFundCross(
        SignatureExecutorTypes.SigDepositFundCrossParams[] calldata params
    ) external virtual override onlyExecutorAdmin {
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = FLAEX_PROVIDER.getCrossMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._DEPOSIT_CROSS_TYPEHASH_SELECTOR,
                    params[i].amountToDeposit,
                    params[i].beneficiary,
                    params[i].nonce,
                    params[i].deadline,
                    params[i].signature
                )
            );
            if (!isSuccess) {
                emit DepositNotSuccess(i, returnedData);
            }
        }
    }

    function batchOpenLong(
        SignatureExecutorTypes.SigOpenLongParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _openLong(params[i], signature[i]);

            // string memory errorr;

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit OpenLongNotSuccess(i, returnedData);
                // assembly {
                //     errorr := add(returnedData, 68)
                // }
            }
        }
    }

    function _openLong(
        SignatureExecutorTypes.SigOpenLongParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getIsolatedMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._OPEN_LONG_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.maxQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchOpenShort(
        SignatureExecutorTypes.SigOpenShortParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _openShort(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit OpenShortNotSuccess(i, returnedData);
            }
        }
    }

    function _openShort(
        SignatureExecutorTypes.SigOpenShortParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getIsolatedMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._OPEN_SHORT_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.minQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function _closeLong(
        SignatureExecutorTypes.SigCloseLongParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getIsolatedMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._CLOSE_LONG_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.minQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchCloseLong(
        SignatureExecutorTypes.SigCloseLongParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _closeLong(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit CloseLongNotSuccess(i, returnedData);
            }
        }
    }

    function _closeShort(
        SignatureExecutorTypes.SigCloseShortParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getIsolatedMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._CLOSE_SHORT_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.maxQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchCloseShort(
        SignatureExecutorTypes.SigCloseShortParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _closeShort(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit CloseShortNotSuccess(i, returnedData);
            }
        }
    }

    function batchOpenLongCross(
        SignatureExecutorTypes.SigOpenLongCrossParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _openLongCross(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit OpenLongNotSuccess(i, returnedData);
            }
        }
    }

    function _openLongCross(
        SignatureExecutorTypes.SigOpenLongCrossParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getCrossMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._OPEN_LONG_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.maxQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchOpenShortCross(
        SignatureExecutorTypes.SigOpenShortCrossParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _openShortCross(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit OpenShortNotSuccess(i, returnedData);
            }
        }
    }

    function _openShortCross(
        SignatureExecutorTypes.SigOpenShortCrossParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);
        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getCrossMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._OPEN_SHORT_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.leverage,
                    params.minQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function _closeLongCross(
        SignatureExecutorTypes.SigCloseLongCrossParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getCrossMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._CLOSE_LONG_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.minQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchCloseLongCross(
        SignatureExecutorTypes.SigCloseLongCrossParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _closeLongCross(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit CloseLongNotSuccess(i, returnedData);
            }
        }
    }

    function _closeShortCross(
        SignatureExecutorTypes.SigCloseShortCrossParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getCrossMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._CLOSE_SHORT_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.baseAmount,
                    params.maxQuoteAmount, // this will be used for limit orders
                    params.sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
                    params.uniFee
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchCloseShortCross(
        SignatureExecutorTypes.SigCloseShortCrossParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _closeShortCross(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit CloseShortNotSuccess(i, returnedData);
            }
        }
    }

    function _withdrawFund(
        SignatureExecutorTypes.SigWithdrawFundParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getIsolatedMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._WITHDRAW_FUND_FUNCTION_SELECTOR,
                    params.pairId,
                    params.trader,
                    params.amountToWithdraw
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchWithdrawFund(
        SignatureExecutorTypes.SigWithdrawFundParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _withdrawFund(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit WithdrawFundNotSuccess(i, returnedData);
            }
        }
    }

    function _withdrawFundCross(
        SignatureExecutorTypes.SigWithdrawFundCrossParams memory params,
        bytes memory signature
    ) private returns (bool isSuccess, bytes memory returnedData) {
        require(block.timestamp < params.deadline, ErrorList.DEADLINE_EXPIRED);

        _checkValidNonce(params.trader, params.nonce);

        bool isValid = signature.verify(_hashTypedData(SignatureHash.hash(params)), params.trader);

        if (isValid) {
            (isSuccess, returnedData) = FLAEX_PROVIDER.getCrossMargin().call(
                abi.encodeWithSelector(
                    SignatureHash._WITHDRAW_FUND_FUNCTION_SELECTOR,
                    params.trader,
                    params.amountToWithdraw
                )
            );
        } else {
            isSuccess = false;
            returnedData = abi.encode("INVALID_SIGNATURE");
        }
    }

    function batchWithdrawFundCross(
        SignatureExecutorTypes.SigWithdrawFundCrossParams[] memory params,
        bytes[] memory signature
    ) external virtual override onlyExecutorAdmin {
        require(params.length == signature.length, ErrorList.LENGTH_MISMATCHED);
        for (uint256 i = 0; i < params.length; i++) {
            (bool isSuccess, bytes memory returnedData) = _withdrawFundCross(params[i], signature[i]);

            if (isSuccess) {
                _useUnorderedNonce(params[i].trader, params[i].nonce);
            } else {
                emit WithdrawFundNotSuccess(i, returnedData);
            }
        }
    }

    function batch(bytes[] calldata data) external virtual override onlyExecutorAdmin {
        for (uint256 i = 0; i < data.length; i++) {
            (Types.DIRECTION direction, bytes memory encodedData) = abi.decode(data[i], (Types.DIRECTION, bytes));

            if (direction == Types.DIRECTION.OPEN_LONG) {
                (SignatureExecutorTypes.SigOpenLongParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigOpenLongParams, bytes)
                );

                (bool isSuccess, bytes memory returnedData) = _openLong(params, signature);

                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit OpenLongNotSuccess(i, returnedData);
                }
            } else if (direction == Types.DIRECTION.OPEN_SHORT) {
                (SignatureExecutorTypes.SigOpenShortParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigOpenShortParams, bytes)
                );
                (bool isSuccess, bytes memory returnedData) = _openShort(params, signature);
                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit OpenShortNotSuccess(i, returnedData);
                }
            } else if (direction == Types.DIRECTION.CLOSE_LONG) {
                (SignatureExecutorTypes.SigCloseLongParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigCloseLongParams, bytes)
                );
                (bool isSuccess, bytes memory returnedData) = _closeLong(params, signature);
                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit CloseLongNotSuccess(i, returnedData);
                }
            } else if (direction == Types.DIRECTION.CLOSE_SHORT) {
                (SignatureExecutorTypes.SigCloseShortParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigCloseShortParams, bytes)
                );
                (bool isSuccess, bytes memory returnedData) = _closeShort(params, signature);
                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit CloseShortNotSuccess(i, returnedData);
                }
            }
        }
    }

    function batchCross(bytes[] calldata data) external virtual override onlyExecutorAdmin {
        for (uint256 i = 0; i < data.length; i++) {
            (Types.DIRECTION direction, bytes memory encodedData) = abi.decode(data[i], (Types.DIRECTION, bytes));

            if (direction == Types.DIRECTION.OPEN_LONG) {
                (SignatureExecutorTypes.SigOpenLongCrossParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigOpenLongCrossParams, bytes)
                );

                (bool isSuccess, bytes memory returnedData) = _openLongCross(params, signature);

                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit OpenLongNotSuccess(i, returnedData);
                }
            } else if (direction == Types.DIRECTION.OPEN_SHORT) {
                (SignatureExecutorTypes.SigOpenShortCrossParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigOpenShortCrossParams, bytes)
                );
                (bool isSuccess, bytes memory returnedData) = _openShortCross(params, signature);
                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit OpenShortNotSuccess(i, returnedData);
                }
            } else if (direction == Types.DIRECTION.CLOSE_LONG) {
                (SignatureExecutorTypes.SigCloseLongCrossParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigCloseLongCrossParams, bytes)
                );
                (bool isSuccess, bytes memory returnedData) = _closeLongCross(params, signature);
                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit CloseLongNotSuccess(i, returnedData);
                }
            } else if (direction == Types.DIRECTION.CLOSE_SHORT) {
                (SignatureExecutorTypes.SigCloseShortCrossParams memory params, bytes memory signature) = abi.decode(
                    encodedData,
                    (SignatureExecutorTypes.SigCloseShortCrossParams, bytes)
                );
                (bool isSuccess, bytes memory returnedData) = _closeShortCross(params, signature);
                if (isSuccess) {
                    _useUnorderedNonce(params.trader, params.nonce);
                } else {
                    emit CloseShortNotSuccess(i, returnedData);
                }
            }
        }
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces
    /// @param nonce The nonce to get the associated word and bit positions
    /// @return wordPos The word position or index into the nonceBitmap
    /// @return bitPos The bit position
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap
    /// @dev The last 8 bits of the nonce value is the position of the bit in the bitmap
    function bitmapPositions(uint256 nonce) private pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce);
    }

    /// @notice check if nonce is still valid because this uses a contract call, if we set the bit to use the nonce
    /// and the call returns unsuccessful then the nonce is invalid
    function _checkValidNonce(address from, uint256 nonce) internal view {
        (uint256 wordPos, uint256 bitPos) = bitmapPositions(nonce);
        uint256 bit = 1 << bitPos;
        uint256 flipped = nonceBitmap[from][wordPos] ^ bit;

        if (flipped & bit == 0) revert InvalidNonce();
    }

    /// @notice Checks whether a nonce is taken and sets the bit at the bit position in the bitmap at the word position
    /// @param from The address to use the nonce at
    /// @param nonce The nonce to spend
    function _useUnorderedNonce(address from, uint256 nonce) internal {
        (uint256 wordPos, uint256 bitPos) = bitmapPositions(nonce);
        uint256 bit = 1 << bitPos;
        uint256 flipped = nonceBitmap[from][wordPos] ^= bit;

        if (flipped & bit == 0) revert InvalidNonce();
    }
}
