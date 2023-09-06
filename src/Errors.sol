pragma solidity ^0.8.10;
error NotMinter();
error InvalidArgument(uint256 argument, string message);
error InvalidStringArgument(string argument, string message);
error NotTokenOwner(uint256 tokenId, address messageSender, address actualOwner);
