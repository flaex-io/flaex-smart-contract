// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IPermit2} from "../../dependencies/permit2/interfaces/IPermit2.sol";
import {Types} from "../types/Types.sol";
import {ITradePair} from "../../interfaces/ITradePair.sol";
import {ValidatingLogic} from "../logic/ValidatingLogic.sol";
import {ErrorList} from "../helpers/ErrorList.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {TraderConfig} from "../configuration/TraderConfig.sol";

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {WadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import {IPermit2, ISignatureTransfer} from "../../dependencies/permit2/interfaces/IPermit2.sol";
import "hardhat/console.sol";

library DepositLogic {
    using WadRayMath for uint256;
    using TraderConfig for Types.traderConfigMap;

    event DepositFund(uint16 indexed Id, address indexed trader, uint256 amount);

    function executeDepositFund(
        Types.traderConfigMap storage traderConfig,
        Types.executeDepositFundParams memory params
    ) external {
        // validate
        ValidatingLogic.validateDepositFund(params);

        // transfer usdc from user to Isolated Margin
        IPermit2(ITradePair(params.pairAddress).FLAEX_PROVIDER().getPermit2()).permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: ITradePair(params.pairAddress).quoteToken(),
                    amount: params.amountToDeposit
                }),
                nonce: params.nonce,
                deadline: params.deadline
            }),
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: params.amountToDeposit}),
            params.beneficiary,
            params.signature
        );

        IPool(params.aavePool).supply(
            ITradePair(params.pairAddress).quoteToken(),
            params.amountToDeposit,
            params.vault,
            params.aaveReferralCode
        );

        // record data
        uint256 liquidityIndex = IPool(params.aavePool).getReserveNormalizedIncome(
            ITradePair(params.pairAddress).quoteToken()
        );

        bool isFirst = ITradePair(params.pairAddress).updateDepositIsolated(
            params.beneficiary,
            params.amountToDeposit.rayDiv(liquidityIndex)
        );

        if (isFirst) {
            // update trader config bitmap
            traderConfig.setDeposit(params.pairId, true);
        }

        emit DepositFund(params.pairId, params.beneficiary, params.amountToDeposit);
    }

    function executeDepositFundCross(
        Types.traderConfigMap storage traderConfig,
        Types.executeDepositFundParams memory params
    ) external {
        // transfer usdc from user to Isolated Margin
        IPermit2(ITradePair(params.pairAddress).FLAEX_PROVIDER().getPermit2()).permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: ITradePair(params.pairAddress).quoteToken(),
                    amount: params.amountToDeposit
                }),
                nonce: params.nonce,
                deadline: params.deadline
            }),
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: params.amountToDeposit}),
            params.beneficiary,
            params.signature
        );

        IPool(params.aavePool).supply(
            ITradePair(params.pairAddress).quoteToken(),
            params.amountToDeposit,
            params.vault,
            params.aaveReferralCode
        );

        // record data

        bool isFirst = ITradePair(params.pairAddress).updateDepositCross(
            params.beneficiary,
            params.amountToDeposit.rayDiv(
                IPool(params.aavePool).getReserveNormalizedIncome(ITradePair(params.pairAddress).quoteToken())
            )
        );

        if (isFirst) {
            // update trader config bitmap
            traderConfig.setDeposit(0, true);
        }

        emit DepositFund(0, params.beneficiary, params.amountToDeposit);
    }
}
