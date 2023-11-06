// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IUSDT {
    function decimals() external view returns (uint8);

    function transferFrom(address _from, address _to, uint256 _value) external;

    function balanceOf(address who) external returns (uint256);

    function transfer(address _to, uint _value) external;
}
