// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyDanDefiUtility {
    function max(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        if (a > b) {
            if (a > c) {
                return a;
            }
            return c;
        }
        if (b > c) {
            return b;
        }
        return c;
    }

    function min(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        if (a < b) {
            if (a < c) {
                return a;
            }
            return c;
        }
        if (b < c) {
            return b;
        }
        return c;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a;
        }
        return b;
    }
}
