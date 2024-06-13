// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IFlToken} from "../interfaces/IFlToken.sol";
import {IAddressesProvider} from "../interfaces/IAddressesProvider.sol";
import {IVault} from "../interfaces/IVault.sol";
import {ErrorList} from "../libraries/helpers/ErrorList.sol";

contract FlToken is IFlToken {
    IAddressesProvider public immutable FLAEX_PROVIDER;

    string public name; // = "Flaex Token";
    string public symbol; // flUSDC
    uint8 public decimals; // = 6;
    uint256 public totalSupply;
    address public underlying;

    mapping(address => CPInfo) public _balanceOf;

    /// @dev only Margin can call
    modifier onlyCapitalProvider() {
        _onlyCapitalProvider();
        _;
    }

    function _onlyCapitalProvider() internal view virtual {
        require(msg.sender == FLAEX_PROVIDER.getCapitalProvider(), ErrorList.INVALID_CAPITAL_PROVIDER);
    }

    constructor(IAddressesProvider provider, string memory _name, uint8 _decimals, string memory _symbol) {
        FLAEX_PROVIDER = provider;
        name = _name;
        decimals = _decimals;
        symbol = _symbol;
        underlying = IVault(FLAEX_PROVIDER.getVault()).getEligibleStablecoin();
    }

    function balanceOf(address owner) external view virtual override returns (uint256) {
        return _balanceOf[owner].balance;
    }

    function mint(address to, uint256 amount, uint256 newIndex) external virtual override onlyCapitalProvider {
        totalSupply += amount;
        _balanceOf[to].balance += amount;
        _updateIndex(to, newIndex);

        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external virtual override onlyCapitalProvider {
        totalSupply -= amount;
        _balanceOf[from].balance -= amount;

        emit Transfer(from, address(0), amount);
    }

    function _updateIndex(address owner, uint256 newIndex) private {
        _balanceOf[owner].yieldIndex = newIndex;
    }
}
