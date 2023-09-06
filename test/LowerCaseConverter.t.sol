// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/utils/LowerCaseConverter.sol";

contract LowerCaseConverterTest is Test {
    using LowerCaseConverter for string;

    function testUpperCase() external {
        string memory message = "HELLO";
        assertEq(message.toLowerCase(), "hello");
    }

    function testMixedCase() external {
        string memory message = "HeLlO";
        assertEq(message.toLowerCase(), "hello");
    }

    function testAlphaNumeric() external {
        string memory message = "HeLlO123";
        assertEq(message.toLowerCase(), "hello123");
    }

    function testAlphaNumericWithSpecialCharacters() external {
        string memory message = "HeLlO123_!";
        assertEq(message.toLowerCase(), "hello123_!");
    }
}
