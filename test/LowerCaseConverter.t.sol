// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/utils/MyDanDefiUtility.sol";

contract LowerCaseConverterTest is Test, MyDanDefiUtility {
    function testUpperCase() external {
        string memory message = "HELLO";
        assertEq(toLowerCase(message), "hello");
    }

    function testMixedCase() external {
        string memory message = "HeLlO";
        assertEq(toLowerCase(message), "hello");
    }

    function testAlphaNumeric() external {
        string memory message = "HeLlO123";
        assertEq(toLowerCase(message), "hello123");
    }

    function testAlphaNumericWithSpecialCharacters() external {
        string memory message = "HeLlO123_!";
        assertEq(toLowerCase(message), "hello123_!");
    }
}
