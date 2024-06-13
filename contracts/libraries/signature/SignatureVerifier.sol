// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC1271} from "../../dependencies/openzeppelin/contracts/IERC1271.sol";

library SignatureVerifier {
    /// @notice Thrown when the passed in signature is not a valid length
    error InvalidSignatureLength();

    /// @notice Thrown when the recovered signer is equal to the zero address
    error InvalidSignature();

    /// @notice Thrown when the recovered signer does not equal the claimedSigner
    error InvalidSigner();

    /// @notice Thrown when the recovered contract signature is incorrect
    error InvalidContractSignature();

    bytes32 constant UPPER_BIT_MASK = (0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    function verify(bytes memory signature, bytes32 hash, address claimedSigner) internal view returns (bool isValid) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        isValid = true;

        if (claimedSigner.code.length == 0) {
            if (signature.length == 65) {
                (r, s) = abi.decode(signature, (bytes32, bytes32));
                v = uint8(signature[64]);
            } else if (signature.length == 64) {
                // EIP-2098
                bytes32 vs;
                (r, vs) = abi.decode(signature, (bytes32, bytes32));
                s = vs & UPPER_BIT_MASK;
                v = uint8(uint256(vs >> 255)) + 27;
            } else {
                // revert InvalidSignatureLength();
                return false;
            }
            address signer = ecrecover(hash, v, r, s);
            // if (signer == address(0)) revert InvalidSignature();
            if (signer == address(0)) return false;
            // if (signer != claimedSigner) revert InvalidSigner();
            if (signer != claimedSigner) return false;
        } else {
            bytes4 magicValue = IERC1271(claimedSigner).isValidSignature(hash, signature);
            // if (magicValue != IERC1271.isValidSignature.selector) revert InvalidContractSignature();
            if (magicValue != IERC1271.isValidSignature.selector) return false;
        }
    }
}
