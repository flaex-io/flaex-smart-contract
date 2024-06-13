// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Types} from "../types/Types.sol";

library TraderConfig {
    /**
     * @notice Sets if the trader has deposited
     * @param self The configuration object
     * @param pairIndex The index of the pair in the bitmap
     * @param isDeposited True if the user has deposited, false otherwise
     */
    function setDeposit(Types.traderConfigMap storage self, uint256 pairIndex, bool isDeposited) internal {
        unchecked {
            uint bitPos = 1 << ((pairIndex << 1) + pairIndex);
            if (isDeposited) {
                self.info |= bitPos;
            } else {
                self.info &= ~bitPos;
            }
        }
    }

    /**
     * @notice check if the trader has deposited
     * @param self The configuration object
     * @param pairIndex The index of the pair in the bitmap
     * @return True if the user has deposited, false otherwise
     */
    function isDeposit(Types.traderConfigMap memory self, uint256 pairIndex) internal pure returns (bool) {
        unchecked {
            return (self.info >> ((pairIndex << 1) + pairIndex)) & 1 != 0;
        }
    }

    function setLong(Types.traderConfigMap storage self, uint256 pairIndex, bool isLonged) internal {
        unchecked {
            uint bitPos = 1 << ((pairIndex << 1) + pairIndex + 1);
            if (isLonged) {
                self.info |= bitPos;
            } else {
                self.info &= ~bitPos;
            }
        }
    }

    function isLong(Types.traderConfigMap memory self, uint256 pairIndex) internal pure returns (bool) {
        unchecked {
            return (self.info >> ((pairIndex << 1) + pairIndex + 1)) & 1 != 0;
        }
    }

    function setShort(Types.traderConfigMap storage self, uint256 pairIndex, bool isShorted) internal {
        uint bitPos = 1 << ((pairIndex << 1) + pairIndex + 2);
        if (isShorted) {
            self.info |= bitPos;
        } else {
            self.info &= ~bitPos;
        }
    }

    function isShort(Types.traderConfigMap memory self, uint256 pairIndex) internal pure returns (bool) {
        return (self.info >> ((pairIndex << 1) + pairIndex + 2)) & 1 != 0;
    }

    function isNullAll(Types.traderConfigMap memory self) internal pure returns (bool) {
        return self.info == 0;
    }

    function isNullAllEx0(Types.traderConfigMap memory self) internal pure returns (bool) {
        return (self.info >> 3) == 0;
    }

    function isNull(Types.traderConfigMap memory self, uint256 pairIndex) internal pure returns (bool) {
        return (self.info >> ((pairIndex << 1) + pairIndex)) & 7 == 0;
    }

    function isLongOrShort(Types.traderConfigMap memory self, uint256 pairIndex) internal pure returns (bool) {
        return (self.info >> ((pairIndex << 1) + pairIndex + 1)) & 3 != 0;
    }
}
