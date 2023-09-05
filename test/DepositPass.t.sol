// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DepositPass.sol";
import "../src/Errors.sol";

contract DepositPassTest is Test {
    DepositPass depositPass;
    address deadAddress = 0x000000000000000000000000000000000000dEaD;
    address minter = 0x00000000000000000000000000000000DeaDBeef;

    constructor() {
        depositPass = new DepositPass(minter);
    }

    modifier afterMintOneNft() {
        vm.prank(minter);
        depositPass.mint(deadAddress);
        _;
    }

    function testSetMinter() external {
        depositPass.setMinter(deadAddress);
        assertEq(depositPass.minter(), deadAddress);
    }

    function testSetMinterAccessControl() external {
        vm.prank(deadAddress);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositPass.setMinter(deadAddress);
    }

    function testMintByNonMinter() external {
        vm.expectRevert(NotMinter.selector);
        depositPass.mint(deadAddress);
    }

    function testMintByMinter() external {
        vm.prank(minter);
        depositPass.mint(deadAddress);
        assertEq(depositPass.ownerOf(0), deadAddress);
        assertEq(depositPass.totalSupply(), 1);
    }

    function testSetBaseUri() external afterMintOneNft {
        string memory baseUri = "https://example.com/";
        depositPass.setBaseURI(baseUri);
        depositPass.tokenURI(0);
    }

    function testSetBaseUriAccessControl() external {
        vm.prank(deadAddress);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositPass.setBaseURI("https://example.com/");
    }
}
