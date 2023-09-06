// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyDanDefi.sol";
import "../src/MyDanPass.sol";

contract MyDanDefiTest is Test {
    using LowerCaseConverter for string;
    MyDanDefi myDanDefi;
    MyDanPass myDanPass;
    address deadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor() {
        myDanDefi = new MyDanDefi();
        myDanPass = myDanDefi.myDanPass();
    }

    function testDeploy() external {
        assertEq(myDanPass.minter(), address(myDanDefi));
        assertEq(myDanPass.owner(), address(this));
        assertEq(myDanPass.ownerOf(0), address(this));
    }

    function testSetAssetsUnderManagementCap() external {
        assertEq(myDanDefi.assetsUnderManagementCap(), 0);
        uint256 newCap = 100;
        myDanDefi.setAssetsUnderManagementCap(newCap);
        assertEq(myDanDefi.assetsUnderManagementCap(), newCap);
        // zero value guard
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, 0, "Cap cannot be zero"));
        myDanDefi.setAssetsUnderManagementCap(0);
    }

    function testEditOutOfBoundMembershipTier() external {
        IMyDanDefi.MembershipTier memory newTier = IMyDanDefi.MembershipTier({name: "hello", lowerThreshold: 1, upperThreshold: 100, interestRate: 100});
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, 0, "Index out of bounds"));
        myDanDefi.editMembershipTier(0, newTier);
    }

    function testEditMembershipTier() external {
        // insert 2 tiers
        IMyDanDefi.MembershipTier[] memory newTiers = new IMyDanDefi.MembershipTier[](2);
        newTiers[0] = IMyDanDefi.MembershipTier({name: "hello", lowerThreshold: 1, upperThreshold: 100, interestRate: 100});
        newTiers[1] = IMyDanDefi.MembershipTier({name: "world", lowerThreshold: 101, upperThreshold: 1000, interestRate: 1000});
        myDanDefi.insertMembershipTiers(newTiers);
        // assert result of edit index 1
        IMyDanDefi.MembershipTier memory newTier = IMyDanDefi.MembershipTier({name: "hello", lowerThreshold: 1, upperThreshold: 100, interestRate: 1000});
        myDanDefi.editMembershipTier(1, newTier);
        (string memory name, uint256 lowerThreshold, uint256 upperThreshold, uint256 interestRate) = myDanDefi.membershipTiers(1);
        assertEq(name, "hello");
        assertEq(lowerThreshold, 1);
        assertEq(upperThreshold, 100);
        assertEq(interestRate, 1000);
        // zero value guard
        newTier.interestRate = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, newTier.interestRate, "Rate cannot be zero"));
        myDanDefi.editMembershipTier(1, newTier);
    }

    function testSetDurationsWithMismatchedArrayLength() external {
        uint256[] memory durations = new uint256[](2);
        uint256[] memory bonusRates = new uint256[](3);
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, durations.length, "Durations length does not match bonus rates length"));
        myDanDefi.setDurations(durations, bonusRates);
    }

    function testSetDurations() external {
        uint256[] memory durations = new uint256[](4);
        uint256[] memory bonusRates = new uint256[](4);
        for (uint256 i = 0; i < durations.length; i++) {
            durations[i] = i + 1;
            bonusRates[i] = i + 100;
        }
        myDanDefi.setDurations(durations, bonusRates);
        for (uint256 i = 0; i < durations.length; i++) {
            assertEq(myDanDefi.durationBonusRates(durations[i]), bonusRates[i]);
        }
        // set zero value
        durations[0] = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, durations[0], "Duration cannot be zero"));
        myDanDefi.setDurations(durations, bonusRates);
    }

    function testInsertMembershipTiers() external {
        IMyDanDefi.MembershipTier[] memory newTiers = new IMyDanDefi.MembershipTier[](2);
        newTiers[0] = IMyDanDefi.MembershipTier({name: "hello", lowerThreshold: 1, upperThreshold: 100, interestRate: 100});
        newTiers[1] = IMyDanDefi.MembershipTier({name: "world", lowerThreshold: 101, upperThreshold: 1000, interestRate: 1000});
        myDanDefi.insertMembershipTiers(newTiers);
        (string memory name, uint256 lowerThreshold, uint256 upperThreshold, uint256 interestRate) = myDanDefi.membershipTiers(0);
        assertEq(name, "hello");
        assertEq(lowerThreshold, 1);
        assertEq(upperThreshold, 100);
        assertEq(interestRate, 100);
        (name, lowerThreshold, upperThreshold, interestRate) = myDanDefi.membershipTiers(1);
        assertEq(name, "world");
        assertEq(lowerThreshold, 101);
        assertEq(upperThreshold, 1000);
        assertEq(interestRate, 1000);
    }

    function testSetReferralBonusRewardRates() external {
        uint256[] memory rates = new uint256[](2);
        rates[0] = 100;
        rates[1] = 200;
        myDanDefi.setReferralBonusRewardRates(rates);
        assertEq(myDanDefi.referralBonusRewardRates(0), 100);
        assertEq(myDanDefi.referralBonusRewardRates(1), 200);
        // test zero value
        rates[1] = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, rates[1], "Rate cannot be zero"));
        myDanDefi.setReferralBonusRewardRates(rates);
    }

    function testClaimPass() external {
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        assertEq(myDanPass.ownerOf(mintedTokenId), address(this));
        (uint256 referrerTokenId, ) = myDanDefi.profiles(mintedTokenId);
        assertEq(referrerTokenId, myDanDefi.genesisTokenId());
        // test non genesis referral code
        string memory referralCode = "mydandefi2";
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector, referralCode, "Referral code does not exist"));
        myDanDefi.claimPass(referralCode);
    }

    function testSetReferralCodeOnBehalf() external {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        // set referral code by non owner
        vm.startPrank(deadAddress);
        vm.expectRevert(abi.encodeWithSelector(NotTokenOwner.selector, mintedTokenId, deadAddress, myDanPass.ownerOf(mintedTokenId)));
        string memory referralCode = "random";
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
    }

    function testSetReferralCodeConflictingWithGenesis() external {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        // set referral code by non owner
        string memory referralCode = myDanDefi.genesisReferralCode();
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector, referralCode, "Referral code cannot be genesis referral code"));
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
    }

    function testSetReferralCodeAlreadyInUse() external {
        // mint a pass
        uint256 mintedTokenId1 = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 mintedTokenId2 = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "hello";
        myDanDefi.setReferralCode(referralCode, mintedTokenId1);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector, referralCode, "Referral code already used by other tokenId"));
        myDanDefi.setReferralCode(referralCode, mintedTokenId2);
    }

    function testSetReferralCodeTwice() external {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "hello";
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
        string memory newReferralCode = "hello2";
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, mintedTokenId, "Referral code already set"));
        myDanDefi.setReferralCode(newReferralCode, mintedTokenId);
    }

    function testSetReferralCode() external {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "HeLLo";
        string memory lowerCaseReferralCode = "hello";
        // set mixed case as ref code
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
        // assert lower case ref code is set as key
        assertEq(myDanDefi.referralCodes(lowerCaseReferralCode), mintedTokenId);
        (uint256 referrerTokenId, string memory setReferralCode) = myDanDefi.profiles(mintedTokenId);
        assertEq(referrerTokenId, myDanDefi.genesisTokenId());
        // assert lower case ref code is set in profile storage
        assertEq(setReferralCode, lowerCaseReferralCode);
    }
}
