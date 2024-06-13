// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library Types {
    struct tradingPairConfigMap {
        // bit 0-15: commissionFee, 0.05% = 5
        // bit 16-31: commisison fee protocol share, 60% = 6000
        // bit 32-47: Maximum Leverage, 20 = 20
        // bit 48-63: Liq. threshold, 1.1 = 110
        // bit 64-79: Liq. factor, 50% = 5000
        // bit 80-95: Liq. incentive, 2% = 200
        // bit 96-111: Liq. protocol share, 40% = 4000
        // bit 112-127: default gas fee, 0.4 usd = 40
        // bit 128-143: secondsAgo, used for uniswap pricing, 5 = 5
        // bit 144-159: baseToken decimals, 18 = 18
        // bit 159-175: quoteToken decimals, 6 = 6
        // bit 176-191: margin call threshold, 1.2 = 120
        // bit 192-207: standard deviation, 3% = 300
        // bit 208-223: default unipool fee, if no fee is specified then reverts to this value
        // bit 224: is Live
        uint256 info;
    }

    // unifee: 500 (0.05%), 3000 (0.3%), 10000 (1%)

    struct tradingPairData {
        address baseToken;
        address quoteToken;
        uint256 gasFeeAccumulated;
        tradingPairConfigMap config;
    }

    struct positionData {
        // Scaled balance of aToken of Base Currency
        uint256 sbATokenAmount;
        // Scaled balance of debtToken of Base Currency
        uint256 sbDebtTokenAmount;
        // scaled balance of aToken of Quote Currency, which is USDC!
        uint256 sqATokenAmount;
        // scaled balance of debtToken of Quote Currency, which is USDC!
        uint256 sqDebtTokenAmount;
    }

    struct crossPositionData {
        // interchangeable, for pairId 0 it's USDC, for others it's base token
        uint256 sATokenAmount;
        uint256 sDebtTokenAmount;
    }

    struct commissionFeeData {
        // capital provider
        uint256 cp;
        // protocol
        uint256 pr;
    }

    struct executeRegisterPairParams {
        address aavePool;
        address baseToken;
        address quoteToken;
        address pairAddress;
        uint16 tradingPairCount;
    }

    struct traderConfigMap {
        // it is divided into a 3-bit per pair (from right to left) where:
        // 1st bit: is deposited
        // 2nd bit: is Long
        // 3rd bit: is Short
        uint256 info;
    }

    struct executeDepositFundParams {
        address aavePool;
        address vault;
        address permit2;
        uint16 pairId;
        address pairAddress;
        address beneficiary;
        uint256 amountToDeposit;
        uint16 aaveReferralCode;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    struct calculateUserDataParams {
        uint16 pairId;
        address aavePool;
        address aaveOracle;
        address uniPool;
        address baseToken;
        address quoteToken;
        positionData userData;
        tradingPairConfigMap pairConfig;
        traderConfigMap userConfig;
    }

    struct calculatedUserCrossDataParams {
        uint16 pairId;
        address trader;
        address aavePool;
        address aaveOracle;
        address uniFactory;
        uint16 tradingPairCount;
        traderConfigMap userConfig;
    }

    struct executeOpenLongParams {
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        positionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 maxQuoteAmount;
        uint160 sqrtPriceLimitX96;
        uint16 aaveReferralCode;
    }

    struct executeOpenShortParams {
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        positionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 minQuoteAmount;
        uint160 sqrtPriceLimitX96;
        uint16 aaveReferralCode;
    }

    struct executeCloseLongParams {
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        positionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint256 minQuoteAmount;
        uint160 sqrtPriceLimitX96;
        uint256 quoteD;
        bool isLiquidating;
    }

    struct executeCloseShortParams {
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        positionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint256 maxQuoteAmount;
        uint160 sqrtPriceLimitX96;
        bool isLiquidating;
    }

    struct executeWithdrawParams {
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        positionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 amountToWithdraw;
    }
    struct executeOpenLongCrossParams {
        uint16 tradingPairCount;
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        address uniFactory;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        crossPositionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 maxQuoteAmount;
        uint160 sqrtPriceLimitX96;
        uint16 aaveReferralCode;
    }

    struct executeOpenShortCrossParams {
        uint16 tradingPairCount;
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        address uniFactory;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        crossPositionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint16 leverage;
        uint256 minQuoteAmount;
        uint160 sqrtPriceLimitX96;
        uint16 aaveReferralCode;
    }

    struct executeCloseLongCrossParams {
        uint16 tradingPairCount;
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        address uniFactory;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        crossPositionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint256 minQuoteAmount;
        uint160 sqrtPriceLimitX96;
        uint256 quoteD;
        bool isLiquidating;
        uint16 aaveReferralCode;
    }

    struct executeCloseShortCrossParams {
        uint16 tradingPairCount;
        address aavePool;
        address vault;
        address aaveOracle;
        address uniPool;
        address uniFactory;
        uint16 pairId;
        address pairAddress;
        address baseToken;
        address quoteToken;
        tradingPairConfigMap config;
        crossPositionData userData;
        traderConfigMap userConfig;
        address trader;
        uint256 baseAmount;
        uint256 maxQuoteAmount;
        uint160 sqrtPriceLimitX96;
        bool isLiquidating;
    }

    struct executeCrossWithdrawParams {
        address aavePool;
        address vault;
        address aaveOracle;
        address uniFactory;
        address pairAddress;
        address quoteToken;
        tradingPairConfigMap config;
        traderConfigMap userConfig;
        address trader;
        uint256 amountToWithdraw;
    }

    enum DIRECTION {
        OPEN_LONG,
        OPEN_SHORT,
        CLOSE_LONG,
        CLOSE_SHORT
    }

    struct executeCPSupplyParams {
        address aavePool;
        address vault;
        address flToken;
        address permit2;
        address eligibleStableCoin;
        uint256 yieldIndex;
        uint256 lastUpdatedCom;
        uint256 amount;
        uint256 supplyCap;
        uint256 currentCom;
        uint16 aaveReferralCode;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    struct executeCPWithdrawParams {
        address aavePool;
        address vault;
        address flToken;
        address eligibleStableCoin;
        uint256 yieldIndex;
        uint256 lastUpdatedCom;
        uint256 amount;
        uint256 currentCom;
    }

    struct executeGetCapitalProviderInfo {
        address user;
        address aavePool;
        address flToken;
        address eligibleStableCoin;
        uint256 yieldIndex;
        uint256 lastUpdatedCom;
        uint256 currentCom;
    }
}
