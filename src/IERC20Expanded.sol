pragma solidity ^0.8.10;
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IERC20Expanded is IERC20 {
    function decimals() external view returns (uint8);
}