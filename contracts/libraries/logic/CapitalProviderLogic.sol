// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {WadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";

import {Types} from "../types/Types.sol";
import {IFlToken} from "../../interfaces/IFlToken.sol";
import {ErrorList} from "../../libraries/helpers/ErrorList.sol";
import {IVault} from "../../interfaces/IVault.sol";

import {IPermit2, ISignatureTransfer} from "../../dependencies/permit2/interfaces/IPermit2.sol";

import {Math} from "../../dependencies/openzeppelin/contracts/Math.sol";
import "hardhat/console.sol";

library CapitalProviderLogic {
    using WadRayMath for uint256;
    using Math for uint256;
    event Supply(address user, uint256 amount, uint256 flAmount);
    event Withdraw(address user, uint256 amount, uint256 flAmount);

    function executeSupply(Types.executeCPSupplyParams memory params) external returns (uint256, uint256) {
        // enforce supply cap
        require(
            IFlToken(params.flToken).totalSupply().rayMul(
                IPool(params.aavePool).getReserveNormalizedIncome(params.eligibleStableCoin)
            ) <= params.supplyCap,
            ErrorList.SUPPLY_CAP_EXCEEDED
        );

        // transfer from user
        // transfer usdc from user to Isolated Margin
        IPermit2(params.permit2).permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: params.eligibleStableCoin,
                    amount: params.amount
                }),
                nonce: params.nonce,
                deadline: params.deadline
            }),
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: params.amount}),
            msg.sender,
            params.signature
        );

        // supply on behalf of Vault
        IPool(params.aavePool).supply(params.eligibleStableCoin, params.amount, params.vault, params.aaveReferralCode);

        // calculate amount to mint and params.yieldIndex
        // yield index = current index if balance = 0
        // amount to mint = amount + any yield (if balance > 0)
        uint256 amountToMint;

        if (IFlToken(params.flToken).totalSupply() == 0) {
            params.yieldIndex += 0;
        } else {
            params.yieldIndex += (params.currentCom - params.lastUpdatedCom).rayDiv(
                IFlToken(params.flToken).totalSupply()
            );
        }

        (uint256 currentBalance, uint256 currentYieldIndex) = IFlToken(params.flToken)._balanceOf(msg.sender);

        if (currentBalance > 0) {
            // amountMintExtra = yield = balance * (params.yieldIndex - userYield)
            amountToMint += currentBalance.rayMul(params.yieldIndex - currentYieldIndex);
        }

        amountToMint += params.amount.rayDiv(
            IPool(params.aavePool).getReserveNormalizedIncome(params.eligibleStableCoin)
        );

        // mint
        IFlToken(params.flToken).mint(msg.sender, amountToMint, params.yieldIndex);

        emit Supply(msg.sender, params.amount, amountToMint);
        return (params.yieldIndex, params.currentCom);
    }

    function executeWithdraw(Types.executeCPWithdrawParams memory params) external returns (uint256, uint256) {
        // first, we mint extra yield
        (uint256 currentBalance, uint256 currentYieldIndex) = IFlToken(params.flToken)._balanceOf(msg.sender);

        params.yieldIndex += (params.currentCom - params.lastUpdatedCom).rayDiv(
            IFlToken(params.flToken).totalSupply()
        );

        uint256 amountToMint = currentBalance.rayMul(params.yieldIndex - currentYieldIndex);

        IFlToken(params.flToken).mint(msg.sender, amountToMint, params.yieldIndex);

        if (params.amount == type(uint256).max)
            params.amount = IFlToken(params.flToken).balanceOf(msg.sender).rayMul(
                IPool(params.aavePool).getReserveNormalizedIncome(params.eligibleStableCoin)
            );

        require(
            params.amount <=
                IFlToken(params.flToken).balanceOf(msg.sender).rayMul(
                    IPool(params.aavePool).getReserveNormalizedIncome(params.eligibleStableCoin)
                ),
            ErrorList.INVALID_AMOUNT
        );

        // withdraw
        IVault(params.vault).withdrawToCapitalProvider(params.amount, msg.sender);

        uint256 amountToBurn = params.amount.rayDiv(
            IPool(params.aavePool).getReserveNormalizedIncome(params.eligibleStableCoin)
        );

        // burn token
        IFlToken(params.flToken).burn(msg.sender, amountToBurn);

        emit Withdraw(msg.sender, params.amount, amountToBurn);
        return (params.yieldIndex, params.currentCom);
    }

    function executeGetCapitalProviderInfo(
        Types.executeGetCapitalProviderInfo memory params
    ) external view returns (uint256) {
        (uint256 currentBalance, uint256 currentYieldIndex) = IFlToken(params.flToken)._balanceOf(params.user);

        if (currentBalance == 0) return 0;

        params.yieldIndex += (params.currentCom - params.lastUpdatedCom).rayDiv(
            IFlToken(params.flToken).totalSupply()
        );

        currentBalance += currentBalance.rayMul(params.yieldIndex - currentYieldIndex);

        return currentBalance.rayMul(IPool(params.aavePool).getReserveNormalizedIncome(params.eligibleStableCoin));
    }
}
