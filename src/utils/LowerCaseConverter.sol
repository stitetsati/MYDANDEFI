// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LowerCaseConverter {
    // Function to convert a string to lowercase
    function toLowerCase(string memory str) public pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);

        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character ASCII range: 65 to 90
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // Convert to lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }

        return string(bLower);
    }
}
