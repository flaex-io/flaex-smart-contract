// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// openzeppelin
import {Initializable} from "../dependencies/openzeppelin/upgradability/Initializable.sol";
import {UUPSUpgradeable} from "../dependencies/openzeppelin/upgradability/UUPSUpgradeable.sol";

import {ICrossMargin} from "../interfaces/ICrossMargin.sol";
import {ITradePair} from "../interfaces/ITradePair.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {CrossStorage} from "../storage/CrossStorage.sol";
import {CrossLogic} from "../libraries/logic/CrossLogic.sol";
import {DepositLogic} from "../libraries/logic/DepositLogic.sol";
import {CrossExecutionLogic} from "../libraries/logic/CrossExecutionLogic.sol";
import {CrossSwapCallback} from "../libraries/logic/CrossSwapCallback.sol";

// import uniswap
import {IUniswapV3SwapCallback} from "../dependencies/v3-core/interfaces/callback/IUniswapV3SwapCallback.sol";
import {PoolAddress} from "../dependencies/v3-periphery/libraries/PoolAddress.sol";
import {IAC} from "../interfaces/IAC.sol";
import {Types} from "../libraries/types/Types.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";

contract CrossMargin is Initializable, UUPSUpgradeable, CrossStorage, ICrossMargin, IUniswapV3SwapCallback {
    IAddressesProvider public FLAEX_PROVIDER;

    /// @dev only isolated admin can call
    modifier onlyCrossMarginAdmin() {
        _onlyCrossMarginAdmin();
        _;
    }

    function _onlyCrossMarginAdmin() internal view virtual {
        IAC AC = IAC(FLAEX_PROVIDER.getAC());
        require(AC.isCrossAdmin(msg.sender), ErrorList.CALLER_NOT_CROSS_ADMIN);
    }

    /// @dev only executors can call
    modifier onlyExecutor() {
        _onlyExecutor();
        _;
    }

    function _onlyExecutor() internal view virtual {
        require(msg.sender == FLAEX_PROVIDER.getFunctionExecutor(), ErrorList.INVALID_FUNCTION_EXECUTOR);
    }

    /// @dev only liquidators can call
    modifier onlyLiquidator() {
        _onlyLiquidator();
        _;
    }

    function _onlyLiquidator() internal view virtual {
        IAC AC = IAC(FLAEX_PROVIDER.getAC());
        require(AC.isLiquidator(msg.sender), ErrorList.CALLER_NOT_LIQUIDATOR);
    }

    /// @dev only owner can call
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view virtual {
        require(msg.sender == FLAEX_PROVIDER.Owner(), ErrorList.CALLER_NOT_OWNER);
    }

    /**
     * @notice Initializes.
     * @dev Function is invoked by the proxy contract
     * @param provider The address of the PoolAddressesProvider
     */

    function initialize(IAddressesProvider provider) external virtual initializer {
        FLAEX_PROVIDER = provider;
    }

    /**
     * @notice overridden function to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function registerPair(
        address baseToken,
        address quoteToken,
        address pairAddress
    ) external virtual override onlyCrossMarginAdmin {
        if (
            CrossLogic.executeRegisterPair(
                _tradingPairs,
                _tradingPairList,
                Types.executeRegisterPairParams({
                    aavePool: FLAEX_PROVIDER.getAavePool(),
                    baseToken: baseToken,
                    quoteToken: quoteToken,
                    pairAddress: pairAddress,
                    tradingPairCount: _tradingPairCount
                })
            )
        ) {
            _tradingPairCount++;
        }
    }

    function dropPair(uint16 pairId) external virtual override onlyCrossMarginAdmin {
        CrossLogic.executeDropPair(_tradingPairs, _tradingPairList, pairId);
    }

    function setAaveReferralCode(uint16 code) external virtual override onlyCrossMarginAdmin {
        _aaveReferralCode = code;
    }

    /// @inheritdoc ICrossMargin
    function depositFund(
        uint256 amountToDeposit,
        address beneficiary,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external virtual override onlyExecutor {
        DepositLogic.executeDepositFundCross(
            _traderConfig[beneficiary],
            Types.executeDepositFundParams({
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                permit2: FLAEX_PROVIDER.getPermit2(),
                pairId: 0, // the 0 pair
                pairAddress: _tradingPairs[_tradingPairList[0]],
                beneficiary: beneficiary,
                amountToDeposit: amountToDeposit,
                aaveReferralCode: _aaveReferralCode,
                nonce: nonce,
                deadline: deadline,
                signature: signature
            })
        );
    }

    /// @inheritdoc ICrossMargin
    function openLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint16 leverage,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        CrossExecutionLogic.executeOpenLong(
            _tradingPairList,
            _tradingPairs,
            _traderConfig[trader],
            Types.executeOpenLongCrossParams({
                tradingPairCount: _tradingPairCount,
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniPool: PoolAddress.computeAddress(
                    FLAEX_PROVIDER.getUniswapFactory(),
                    PoolAddress.getPoolKey(
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                        uniFee
                    )
                ),
                uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                pairId: pairId,
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getCrossConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserCrossPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                leverage: leverage,
                maxQuoteAmount: maxQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                aaveReferralCode: _aaveReferralCode
            })
        );
    }

    /// @inheritdoc ICrossMargin
    function openShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint16 leverage,
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        CrossExecutionLogic.executeOpenShort(
            _tradingPairList,
            _tradingPairs,
            _traderConfig[trader],
            Types.executeOpenShortCrossParams({
                tradingPairCount: _tradingPairCount,
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniPool: PoolAddress.computeAddress(
                    FLAEX_PROVIDER.getUniswapFactory(),
                    PoolAddress.getPoolKey(
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                        uniFee
                    )
                ),
                pairId: pairId,
                uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getCrossConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserCrossPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                leverage: leverage,
                minQuoteAmount: minQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                aaveReferralCode: _aaveReferralCode
            })
        );
    }

    /// @inheritdoc ICrossMargin
    function closeLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount, // type(uint256).max for 100% close
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        CrossExecutionLogic.executeCloseLong(
            _tradingPairList,
            _tradingPairs,
            _traderConfig[trader],
            Types.executeCloseLongCrossParams({
                tradingPairCount: _tradingPairCount,
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniPool: PoolAddress.computeAddress(
                    FLAEX_PROVIDER.getUniswapFactory(),
                    PoolAddress.getPoolKey(
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                        uniFee
                    )
                ),
                uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                pairId: pairId,
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getCrossConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserCrossPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                minQuoteAmount: minQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                quoteD: 0,
                isLiquidating: false,
                aaveReferralCode: _aaveReferralCode
            })
        );
    }

    /// @inheritdoc ICrossMargin
    function closeShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        CrossExecutionLogic.executeCloseShort(
            _tradingPairList,
            _tradingPairs,
            _traderConfig[trader],
            Types.executeCloseShortCrossParams({
                tradingPairCount: _tradingPairCount,
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniPool: PoolAddress.computeAddress(
                    FLAEX_PROVIDER.getUniswapFactory(),
                    PoolAddress.getPoolKey(
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                        uniFee
                    )
                ),
                uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                pairId: pairId,
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getCrossConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserCrossPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                maxQuoteAmount: maxQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                isLiquidating: false
            })
        );
    }

    /// @inheritdoc ICrossMargin
    function liquidateLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount, // type(uint256).max for 100% close
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyLiquidator {
        CrossExecutionLogic.executeLiquidateLong(
            _tradingPairList,
            _tradingPairs,
            msg.sender,
            _traderConfig[trader],
            Types.executeCloseLongCrossParams({
                tradingPairCount: _tradingPairCount,
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniPool: PoolAddress.computeAddress(
                    FLAEX_PROVIDER.getUniswapFactory(),
                    PoolAddress.getPoolKey(
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                        uniFee
                    )
                ),
                uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                pairId: pairId,
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getCrossConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserCrossPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                minQuoteAmount: minQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                quoteD: 0,
                isLiquidating: true,
                aaveReferralCode: _aaveReferralCode
            })
        );
    }

    /// @inheritdoc ICrossMargin
    function liquidateShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyLiquidator {
        CrossExecutionLogic.executeLiquidateShort(
            _tradingPairList,
            _tradingPairs,
            msg.sender,
            _traderConfig[trader],
            Types.executeCloseShortCrossParams({
                tradingPairCount: _tradingPairCount,
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniPool: PoolAddress.computeAddress(
                    FLAEX_PROVIDER.getUniswapFactory(),
                    PoolAddress.getPoolKey(
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                        uniFee
                    )
                ),
                uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                pairId: pairId,
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getCrossConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserCrossPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                maxQuoteAmount: maxQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                isLiquidating: true
            })
        );
    }

    /// @dev overridden function to be externally called from Uniswap Pool only
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external override {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported

        (bytes memory __data, Types.DIRECTION direction) = abi.decode(_data, (bytes, Types.DIRECTION));

        if (direction == Types.DIRECTION.OPEN_LONG) {
            Types.executeOpenLongCrossParams memory params = abi.decode(__data, (Types.executeOpenLongCrossParams));

            require(msg.sender == params.uniPool);

            CrossSwapCallback.openLongCallback(
                params,
                amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta),
                _tradingPairs[_tradingPairList[0]]
            );
        } else if (direction == Types.DIRECTION.OPEN_SHORT) {
            Types.executeOpenShortCrossParams memory params = abi.decode(__data, (Types.executeOpenShortCrossParams));

            //callback validation
            require(msg.sender == params.uniPool);

            CrossSwapCallback.openShortCallback(
                params,
                amount0Delta > 0 ? uint256(-amount1Delta) : uint256(-amount0Delta),
                _tradingPairs[_tradingPairList[0]]
            );
        } else if (direction == Types.DIRECTION.CLOSE_LONG) {
            Types.executeCloseLongCrossParams memory params = abi.decode(__data, (Types.executeCloseLongCrossParams));

            //callback validation
            require(msg.sender == params.uniPool);

            CrossSwapCallback.closeLongCallback(
                params,
                amount0Delta > 0 ? uint256(-amount1Delta) : uint256(-amount0Delta),
                _tradingPairs[_tradingPairList[0]]
            );
        } else if (direction == Types.DIRECTION.CLOSE_SHORT) {
            Types.executeCloseShortCrossParams memory params = abi.decode(
                __data,
                (Types.executeCloseShortCrossParams)
            );

            //callback validation
            require(msg.sender == params.uniPool);

            CrossSwapCallback.closeShortCallback(
                params,
                amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta),
                _tradingPairs[_tradingPairList[0]]
            );
        }
    }

    /// @inheritdoc ICrossMargin
    function withdrawFund(address trader, uint256 amountToWithdraw) external virtual override {
        if (msg.sender != FLAEX_PROVIDER.getFunctionExecutor()) trader = msg.sender;
        CrossExecutionLogic.executeWithdrawFund(
            _tradingPairList,
            _tradingPairs,
            _tradingPairCount,
            _traderConfig[trader],
            Types.executeCrossWithdrawParams({
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                pairAddress: _tradingPairs[_tradingPairList[0]],
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[0]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[0]]).getCrossConfig(),
                userConfig: _traderConfig[trader],
                trader: trader,
                amountToWithdraw: amountToWithdraw
            })
        );
    }

    function getUserData(
        address user,
        uint16 pairId
    ) external view virtual override returns (uint256, uint256, uint256, uint256, uint256, uint256, bool) {
        return (
            CrossLogic.executeGetUserData(
                _tradingPairList,
                _tradingPairs,
                Types.calculatedUserCrossDataParams({
                    pairId: pairId,
                    trader: user,
                    aavePool: FLAEX_PROVIDER.getAavePool(),
                    aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                    uniFactory: FLAEX_PROVIDER.getUniswapFactory(),
                    tradingPairCount: _tradingPairCount,
                    userConfig: _traderConfig[user]
                })
            )
        );
    }

    function collectGasFee(uint16[] calldata pairId, address treasury) external virtual override onlyCrossMarginAdmin {
        CrossLogic.executeCollectGasFee(FLAEX_PROVIDER, _tradingPairs, _tradingPairList, pairId, treasury);
    }

    function collectCommissionFee(uint256 amount, address treasury) external virtual override onlyCrossMarginAdmin {
        CrossLogic.executeCollectCommissionFee(FLAEX_PROVIDER, amount, treasury);
    }

    function collectLiquidationIncentive(
        address asset,
        uint256 amount,
        address treasury
    ) external virtual override onlyCrossMarginAdmin {
        CrossLogic.executeCollectLiquidationIncentive(FLAEX_PROVIDER, asset, amount, treasury);
    }
}
