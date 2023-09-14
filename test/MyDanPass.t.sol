// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyDanPass.sol";
import "../src/Errors.sol";

contract MyDanPassTest is Test {
    MyDanPass myDanPass;
    address deadAddress = 0x000000000000000000000000000000000000dEaD;
    address minter = 0x00000000000000000000000000000000DeaDBeef;

    constructor() {
        myDanPass = new MyDanPass();
        myDanPass.setMinter(minter);
    }

    modifier afterMintOneNft() {
        vm.prank(minter);
        myDanPass.mint(deadAddress);
        _;
    }

    function testSetMinter() external {
        myDanPass.setMinter(deadAddress);
        assertEq(myDanPass.minter(), deadAddress);
    }

    function testSetMinterAccessControl() external {
        vm.prank(deadAddress);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        myDanPass.setMinter(deadAddress);
    }

    function testMintByNonMinter() external {
        vm.expectRevert(NotMinter.selector);
        myDanPass.mint(deadAddress);
    }

    function testMintByMinter() external {
        vm.prank(minter);
        uint256 tokenId = myDanPass.mint(deadAddress);
        assertEq(myDanPass.ownerOf(tokenId), deadAddress);
        assertEq(myDanPass.totalSupply(), 2);
    }

    function testSetBaseUri() external afterMintOneNft {
        string memory baseUri = "https://example.com/";
        myDanPass.setBaseURI(baseUri);
        myDanPass.tokenURI(0);
    }

    function testSetBaseUriAccessControl() external {
        vm.prank(deadAddress);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        myDanPass.setBaseURI("https://example.com/");
    }
}
