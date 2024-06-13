// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// openzeppelin
import {Initializable} from "../dependencies/openzeppelin/upgradability/Initializable.sol";
import {UUPSUpgradeable} from "../dependencies/openzeppelin/upgradability/UUPSUpgradeable.sol";

// import flaex
import {IIsolatedMargin} from "../interfaces/IIsolatedMargin.sol";
import {IsolatedStorage} from "../storage/IsolatedStorage.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";
import {DepositLogic} from "../libraries/logic/DepositLogic.sol";
import {ExecutionLogic} from "../libraries/logic/ExecutionLogic.sol";
import {SwapCallback} from "../libraries/logic/SwapCallback.sol";
import {ITradePair} from "../interfaces/ITradePair.sol";
import {Types} from "../libraries/types/Types.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {IsolatedLogic} from "../libraries/logic/IsolatedLogic.sol";
import {IAC} from "../interfaces/IAC.sol";
import {TradePairConfig} from "../libraries/configuration/TradePairConfig.sol";

// import uniswap
import {IUniswapV3SwapCallback} from "../dependencies/v3-core/interfaces/callback/IUniswapV3SwapCallback.sol";
import {PoolAddress} from "../dependencies/v3-periphery/libraries/PoolAddress.sol";

/**  
  * @title User's Interaction Point To Isolated Margin Trade
  * @author Flaex
  * @notice User can:
    - Deposit Funds into each separate trading pair
    - Withdraw Funds
    - Open/Close Long/Short
    - Liquidate others
 */

contract IsolatedMargin is Initializable, UUPSUpgradeable, IsolatedStorage, IIsolatedMargin, IUniswapV3SwapCallback {
    using TradePairConfig for Types.tradingPairConfigMap;

    IAddressesProvider public FLAEX_PROVIDER;

    /// @dev only isolated admin can call
    modifier onlyIsolatedAdmin() {
        _onlyIsolatedAdmin();
        _;
    }

    function _onlyIsolatedAdmin() internal view virtual {
        IAC AC = IAC(FLAEX_PROVIDER.getAC());
        require(AC.isIsolatedAdmin(msg.sender), ErrorList.CALLER_NOT_ISOLATED_ADMIN);
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
        __UUPSUpgradeable_init();
    }

    /**
     * @notice overridden function to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @inheritdoc IIsolatedMargin
    function registerPair(
        address baseToken,
        address quoteToken,
        address pairAddress
    ) external virtual override onlyIsolatedAdmin {
        if (
            IsolatedLogic.executeRegisterPair(
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

    /// @inheritdoc IIsolatedMargin
    function dropPair(uint16 pairId) external virtual override onlyIsolatedAdmin {
        IsolatedLogic.executeDropPair(_tradingPairs, _tradingPairList, pairId);
    }

    /// @inheritdoc IIsolatedMargin
    function setAaveReferralCode(uint16 code) external virtual override onlyIsolatedAdmin {
        _aaveReferralCode = code;
    }

    /// @inheritdoc IIsolatedMargin
    function depositFund(
        uint16 pairId,
        uint256 amountToDeposit,
        address beneficiary,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external virtual override onlyExecutor {
        DepositLogic.executeDepositFund(
            _traderConfig[beneficiary],
            Types.executeDepositFundParams({
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                permit2: FLAEX_PROVIDER.getPermit2(),
                pairId: pairId,
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                beneficiary: beneficiary,
                amountToDeposit: amountToDeposit,
                aaveReferralCode: _aaveReferralCode,
                nonce: nonce,
                deadline: deadline,
                signature: signature
            })
        );
    }

    /// @inheritdoc IIsolatedMargin
    function openLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint16 leverage,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        ExecutionLogic.executeOpenLong(
            _traderConfig[trader],
            Types.executeOpenLongParams({
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
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(trader),
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

    /// @inheritdoc IIsolatedMargin
    function openShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint16 leverage,
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        ExecutionLogic.executeOpenShort(
            _traderConfig[trader],
            Types.executeOpenShortParams({
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
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(trader),
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

    /// @inheritdoc IIsolatedMargin
    function closeLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount, // type(uint256).max for 100% close
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        ExecutionLogic.executeCloseLong(
            _traderConfig[trader],
            Types.executeCloseLongParams({
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
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                minQuoteAmount: minQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                quoteD: 0,
                isLiquidating: false
            })
        );
    }

    /// @inheritdoc IIsolatedMargin
    function closeShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyExecutor {
        ExecutionLogic.executeCloseShort(
            _traderConfig[trader],
            Types.executeCloseShortParams({
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
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                maxQuoteAmount: maxQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                isLiquidating: false
            })
        );
    }

    /// @inheritdoc IIsolatedMargin
    function liquidateLong(
        uint16 pairId,
        address trader,
        uint256 baseAmount, // type(uint256).max for 100% close
        uint256 minQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyLiquidator {
        ExecutionLogic.executeLiquidateLong(
            msg.sender,
            _traderConfig[trader],
            Types.executeCloseLongParams({
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
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(trader),
                userConfig: _traderConfig[trader],
                trader: trader,
                baseAmount: baseAmount,
                minQuoteAmount: minQuoteAmount,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                quoteD: 0,
                isLiquidating: true
            })
        );
    }

    function liquidateShort(
        uint16 pairId,
        address trader,
        uint256 baseAmount,
        uint256 maxQuoteAmount, // this will be used for limit orders
        uint160 sqrtPriceLimitX96, // to ensure the swap doesn't slip too far away
        uint24 uniFee
    ) external virtual override onlyLiquidator {
        ExecutionLogic.executeLiquidateShort(
            msg.sender,
            _traderConfig[trader],
            Types.executeCloseShortParams({
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
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(trader),
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
            Types.executeOpenLongParams memory params = abi.decode(__data, (Types.executeOpenLongParams));

            require(msg.sender == params.uniPool);

            SwapCallback.openLongCallback(params, amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta));
        } else if (direction == Types.DIRECTION.OPEN_SHORT) {
            Types.executeOpenShortParams memory params = abi.decode(__data, (Types.executeOpenShortParams));

            //callback validation
            require(msg.sender == params.uniPool);

            SwapCallback.openShortCallback(params, amount0Delta > 0 ? uint256(-amount1Delta) : uint256(-amount0Delta));
        } else if (direction == Types.DIRECTION.CLOSE_LONG) {
            Types.executeCloseLongParams memory params = abi.decode(__data, (Types.executeCloseLongParams));

            //callback validation
            require(msg.sender == params.uniPool);

            SwapCallback.closeLongCallback(params, amount0Delta > 0 ? uint256(-amount1Delta) : uint256(-amount0Delta));
        } else if (direction == Types.DIRECTION.CLOSE_SHORT) {
            Types.executeCloseShortParams memory params = abi.decode(__data, (Types.executeCloseShortParams));

            //callback validation
            require(msg.sender == params.uniPool);

            SwapCallback.closeShortCallback(params, amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta));
        }
    }

    /// @inheritdoc IIsolatedMargin
    function withdrawFund(uint16 pairId, address trader, uint256 amountToWithdraw) external virtual override {
        if (msg.sender != FLAEX_PROVIDER.getFunctionExecutor()) trader = msg.sender;
        ExecutionLogic.executeWithdrawFund(
            _traderConfig[trader],
            Types.executeWithdrawParams({
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                uniPool: PoolAddress.computeAddress(
                    FLAEX_PROVIDER.getUniswapFactory(),
                    PoolAddress.getPoolKey(
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                        ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                        uint24(
                            ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig().getDefaultUniFee()
                        )
                    )
                ),
                pairId: pairId,
                pairAddress: _tradingPairs[_tradingPairList[pairId]],
                baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                config: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(trader),
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
            IsolatedLogic.executeGetUserData(
                Types.calculateUserDataParams({
                    pairId: pairId,
                    aavePool: FLAEX_PROVIDER.getAavePool(),
                    aaveOracle: FLAEX_PROVIDER.getAaveOracle(),
                    uniPool: PoolAddress.computeAddress(
                        FLAEX_PROVIDER.getUniswapFactory(),
                        PoolAddress.getPoolKey(
                            ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                            ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                            uint24(
                                ITradePair(_tradingPairs[_tradingPairList[pairId]])
                                    .getIsolatedConfig()
                                    .getDefaultUniFee()
                            )
                        )
                    ),
                    baseToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).baseToken(),
                    quoteToken: ITradePair(_tradingPairs[_tradingPairList[pairId]]).quoteToken(),
                    userData: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getUserPosition(user),
                    pairConfig: ITradePair(_tradingPairs[_tradingPairList[pairId]]).getIsolatedConfig(),
                    userConfig: _traderConfig[user]
                })
            )
        );
    }

    function collectGasFee(uint16[] calldata pairId, address treasury) external virtual override onlyIsolatedAdmin {
        IsolatedLogic.executeCollectGasFee(FLAEX_PROVIDER, _tradingPairs, _tradingPairList, pairId, treasury);
    }

    function collectCommissionFee(uint256 amount, address treasury) external virtual override onlyIsolatedAdmin {
        IsolatedLogic.executeCollectCommissionFee(FLAEX_PROVIDER, amount, treasury);
    }

    function collectLiquidationIncentive(
        address asset,
        uint256 amount,
        address treasury
    ) external virtual override onlyIsolatedAdmin {
        IsolatedLogic.executeCollectLiquidationIncentive(FLAEX_PROVIDER, asset, amount, treasury);
    }
}
