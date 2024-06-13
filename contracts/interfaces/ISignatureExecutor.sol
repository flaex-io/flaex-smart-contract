// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SignatureExecutorTypes} from "../libraries/types/SignatureExecutorTypes.sol";

interface ISignatureExecutor {
    /// @notice Thrown when validating that the inputted nonce has not been used
    error InvalidNonce();

    event DepositNotSuccess(uint256 id, bytes returnedData);
    event OpenLongNotSuccess(uint256 id, bytes returnedData);
    event OpenShortNotSuccess(uint256 id, bytes returnedData);
    event CloseLongNotSuccess(uint256 id, bytes returnedData);
    event CloseShortNotSuccess(uint256 id, bytes returnedData);
    event WithdrawFundNotSuccess(uint256 id, bytes returnedData);

    function batchDepositFund(SignatureExecutorTypes.SigDepositFundParams[] calldata params) external;

    function batchDepositFundCross(SignatureExecutorTypes.SigDepositFundCrossParams[] calldata params) external;

    function batchOpenLong(
        SignatureExecutorTypes.SigOpenLongParams[] calldata params,
        bytes[] calldata signature
    ) external;

    function batchOpenShort(
        SignatureExecutorTypes.SigOpenShortParams[] calldata params,
        bytes[] calldata signature
    ) external;

    function batchCloseLong(
        SignatureExecutorTypes.SigCloseLongParams[] memory params,
        bytes[] memory signature
    ) external;

    function batchCloseShort(
        SignatureExecutorTypes.SigCloseShortParams[] memory params,
        bytes[] memory signature
    ) external;

    function batchOpenLongCross(
        SignatureExecutorTypes.SigOpenLongCrossParams[] memory params,
        bytes[] memory signature
    ) external;

    function batchOpenShortCross(
        SignatureExecutorTypes.SigOpenShortCrossParams[] calldata params,
        bytes[] calldata signature
    ) external;

    function batchCloseLongCross(
        SignatureExecutorTypes.SigCloseLongCrossParams[] memory params,
        bytes[] memory signature
    ) external;

    function batchCloseShortCross(
        SignatureExecutorTypes.SigCloseShortCrossParams[] memory params,
        bytes[] memory signature
    ) external;

    function batchWithdrawFund(
        SignatureExecutorTypes.SigWithdrawFundParams[] memory params,
        bytes[] memory signature
    ) external;

    function batchWithdrawFundCross(
        SignatureExecutorTypes.SigWithdrawFundCrossParams[] memory params,
        bytes[] memory signature
    ) external;

    function batch(bytes[] calldata data) external;

    function batchCross(bytes[] calldata data) external;
}
