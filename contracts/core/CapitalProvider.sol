// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// openzeppelin
import {Initializable} from "../dependencies/openzeppelin/upgradability/Initializable.sol";
import {UUPSUpgradeable} from "../dependencies/openzeppelin/upgradability/UUPSUpgradeable.sol";

import {ICapitalProvider} from "../interfaces/ICapitalProvider.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";
import {IAC} from "../interfaces/IAC.sol";
import {IVault} from "../interfaces/IVault.sol";
import {Types} from "../libraries/types/Types.sol";
import {CapitalProviderLogic} from "../libraries/logic/CapitalProviderLogic.sol";

import {IERC20} from "../dependencies/openzeppelin/contracts/IERC20.sol";

/**  
  * @title User's Interaction Point To provide capital 
  * @author Flaex
  * @notice User can:
    - supply
    - withdraw
    - claim yield
 */

contract CapitalProvider is Initializable, UUPSUpgradeable, ICapitalProvider {
    IAddressesProvider public FLAEX_PROVIDER;
    uint256 public supplyCap;
    uint256 public yieldIndex;
    uint256 public lastUpdatedCom;

    uint16 internal _aaveReferralCode;

    /// @dev only owner can call
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view virtual {
        require(msg.sender == FLAEX_PROVIDER.Owner(), ErrorList.CALLER_NOT_OWNER);
    }

    /// @dev only isolated admin can call
    modifier onlyCapitalProviderAdmin() {
        _onlyCapitalProviderAdmin();
        _;
    }

    function _onlyCapitalProviderAdmin() internal view virtual {
        IAC AC = IAC(FLAEX_PROVIDER.getAC());
        require(AC.isCapitalProviderAdmin(msg.sender), ErrorList.CALLER_NOT_CAPITAL_PROVIDER_ADMIN);
    }

    // /**
    //  * @dev Constructor.
    //  * @param provider The address of the AddressesProvider contract
    //  */

    /**
     * @notice Initializes.
     * @dev Function is invoked by the proxy contract
     * @param provider The address of the PoolAddressesProvider
     */

    function initialize(IAddressesProvider provider, uint256 _supplyCap) external virtual initializer {
        FLAEX_PROVIDER = provider;
        supplyCap = _supplyCap;
        lastUpdatedCom = IVault(FLAEX_PROVIDER.getVault()).getScaledCommissionFeeCp();
        __UUPSUpgradeable_init();
    }

    /**
     * @notice overridden function to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function supply(
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external virtual override {
        (yieldIndex, lastUpdatedCom) = CapitalProviderLogic.executeSupply(
            Types.executeCPSupplyParams({
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                flToken: FLAEX_PROVIDER.getFlToken(),
                permit2: FLAEX_PROVIDER.getPermit2(),
                eligibleStableCoin: IVault(FLAEX_PROVIDER.getVault()).getEligibleStablecoin(),
                yieldIndex: yieldIndex,
                lastUpdatedCom: lastUpdatedCom,
                amount: amount,
                supplyCap: supplyCap,
                currentCom: IVault(FLAEX_PROVIDER.getVault()).getScaledCommissionFeeCp(),
                aaveReferralCode: _aaveReferralCode,
                nonce: nonce,
                deadline: deadline,
                signature: signature
            })
        );
    }

    /// @dev amount = max uint256 for 100% withdrawal
    function withdraw(uint256 amount) external virtual override {
        (yieldIndex, lastUpdatedCom) = CapitalProviderLogic.executeWithdraw(
            Types.executeCPWithdrawParams({
                aavePool: FLAEX_PROVIDER.getAavePool(),
                vault: FLAEX_PROVIDER.getVault(),
                flToken: FLAEX_PROVIDER.getFlToken(),
                eligibleStableCoin: IVault(FLAEX_PROVIDER.getVault()).getEligibleStablecoin(),
                yieldIndex: yieldIndex,
                lastUpdatedCom: lastUpdatedCom,
                amount: amount,
                currentCom: IVault(FLAEX_PROVIDER.getVault()).getScaledCommissionFeeCp()
            })
        );
    }

    function setSupplyCap(uint256 cap) external virtual override onlyCapitalProviderAdmin {
        supplyCap = cap;
    }

    function initCP() external virtual override onlyCapitalProviderAdmin {
        IERC20(IVault(FLAEX_PROVIDER.getVault()).getEligibleStablecoin()).approve(
            FLAEX_PROVIDER.getAavePool(),
            type(uint256).max
        );
    }

    function getCapitalProviderInfo(address user) external view virtual override returns (uint256) {
        return
            CapitalProviderLogic.executeGetCapitalProviderInfo(
                Types.executeGetCapitalProviderInfo({
                    user: user,
                    aavePool: FLAEX_PROVIDER.getAavePool(),
                    flToken: FLAEX_PROVIDER.getFlToken(),
                    eligibleStableCoin: IVault(FLAEX_PROVIDER.getVault()).getEligibleStablecoin(),
                    yieldIndex: yieldIndex,
                    lastUpdatedCom: lastUpdatedCom,
                    currentCom: IVault(FLAEX_PROVIDER.getVault()).getScaledCommissionFeeCp()
                })
            );
    }
}
