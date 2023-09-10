// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyDanDefi.sol";
import "../src/MyDanDefiStorage.sol";
import "../src/MyDanPass.sol";
import "./mocks/MockERC20.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract MyDanDefiTest is Test {
    using LowerCaseConverter for string;
    using Strings for uint256;
    MyDanDefi myDanDefi;
    MyDanPass myDanPass;
    address deadAddress = 0x000000000000000000000000000000000000dEaD;
    MockERC20 mockERC20 = new MockERC20();
    uint256 oneDollar = 10 ** mockERC20.decimals();
    uint256 referralBonusMaxLevel;
    event ReferralRewardCreated(uint256 referrerTokenId, uint256 rewardId, uint256 referralLevel);

    constructor() {}

    function setDurations() internal {
        uint256[] memory durations = new uint256[](6);
        uint256[] memory bonusRates = new uint256[](6);
        durations[0] = 3 * 30 days;
        durations[1] = 6 * 30 days;
        durations[2] = 9 * 30 days;
        durations[3] = 365 days;
        durations[4] = 365 * 2 days;
        durations[5] = 365 * 3 days;
        bonusRates[0] = 0;
        bonusRates[1] = 0;
        bonusRates[2] = 0;
        bonusRates[3] = 50;
        bonusRates[4] = 75;
        bonusRates[5] = 100;
        myDanDefi.setDurations(durations, bonusRates);
    }

    function setMembershipTiers() internal {
        IMyDanDefi.MembershipTier[] memory tiers = new IMyDanDefi.MembershipTier[](4);

        tiers[0] = IMyDanDefi.MembershipTier({
            name: "None",
            lowerThreshold: 0,
            upperThreshold: 100 * oneDollar,
            interestRate: 0,
            referralBonusCollectibleLevelLowerBound: 0,
            referralBonusCollectibleLevelUpperBound: 0
        });
        tiers[1] = IMyDanDefi.MembershipTier({
            name: "Sapphire",
            lowerThreshold: 100 * oneDollar,
            upperThreshold: 1000 * oneDollar,
            interestRate: 700,
            referralBonusCollectibleLevelLowerBound: 1,
            referralBonusCollectibleLevelUpperBound: 3
        });
        tiers[2] = IMyDanDefi.MembershipTier({
            name: "Emerald",
            lowerThreshold: 1000 * oneDollar,
            upperThreshold: 10000 * oneDollar,
            interestRate: 750,
            referralBonusCollectibleLevelLowerBound: 4,
            referralBonusCollectibleLevelUpperBound: 5
        });
        tiers[3] = IMyDanDefi.MembershipTier({
            name: "Imperial",
            lowerThreshold: 10000 * oneDollar,
            upperThreshold: type(uint256).max,
            interestRate: 800,
            referralBonusCollectibleLevelLowerBound: 6,
            referralBonusCollectibleLevelUpperBound: 7
        });
        myDanDefi.insertMembershipTiers(tiers);
    }

    function setReferralBonusRewardRates() internal {
        uint256 length = 7;
        uint256[] memory rates = new uint256[](length);
        rates[0] = 600;
        rates[1] = 200;
        rates[2] = 200;
        rates[3] = 100;
        rates[4] = 100;
        rates[5] = 100;
        rates[6] = 100;
        myDanDefi.setReferralBonusRewardRates(rates);
        referralBonusMaxLevel = length;
    }

    modifier Setup() {
        myDanDefi = new MyDanDefi(address(mockERC20));
        myDanPass = myDanDefi.myDanPass();
        myDanDefi.setAssetsUnderManagementCap(100 ether);
        setDurations();
        setMembershipTiers();
        setReferralBonusRewardRates();
        _;
    }

    function testClaimPass() external Setup {
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        assertEq(myDanPass.ownerOf(mintedTokenId), address(this));
        (uint256 referrerTokenId, , , , ) = myDanDefi.profiles(mintedTokenId);
        assertEq(referrerTokenId, myDanDefi.genesisTokenId());
        // test non genesis referral code
        string memory referralCode = "mydandefi2";
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector, referralCode, "Referral code does not exist"));
        myDanDefi.claimPass(referralCode);
    }

    function testSetReferralCodeOnBehalf() external Setup {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        // set referral code by non owner
        vm.startPrank(deadAddress);
        vm.expectRevert(abi.encodeWithSelector(NotTokenOwner.selector, mintedTokenId, deadAddress, myDanPass.ownerOf(mintedTokenId)));
        string memory referralCode = "random";
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
    }

    function testSetReferralCodeConflictingWithGenesis() external Setup {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        // set referral code by non owner
        string memory referralCode = myDanDefi.genesisReferralCode();
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector, referralCode, "Referral code cannot be genesis referral code"));
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
    }

    function testSetReferralCodeAlreadyInUse() external Setup {
        // mint a pass
        uint256 mintedTokenId1 = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 mintedTokenId2 = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "hello";
        myDanDefi.setReferralCode(referralCode, mintedTokenId1);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector, referralCode, "Referral code already used by other tokenId"));
        myDanDefi.setReferralCode(referralCode, mintedTokenId2);
    }

    function testSetReferralCodeTwice() external Setup {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "hello";
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
        string memory newReferralCode = "hello2";
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, mintedTokenId, "Referral code already set"));
        myDanDefi.setReferralCode(newReferralCode, mintedTokenId);
    }

    function testSetReferralCode() external Setup {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "HeLLo";
        string memory lowerCaseReferralCode = "hello";
        // set mixed case as ref code
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
        // assert lower case ref code is set as key
        assertEq(myDanDefi.referralCodes(lowerCaseReferralCode), mintedTokenId);
        (uint256 referrerTokenId, string memory setReferralCode, , , ) = myDanDefi.profiles(mintedTokenId);
        assertEq(referrerTokenId, myDanDefi.genesisTokenId());
        // assert lower case ref code is set in profile storage
        assertEq(setReferralCode, lowerCaseReferralCode);
    }

    function testDepositTooLittle() external Setup {
        mockERC20.mint(address(this), 100 * oneDollar);
        mockERC20.approve(address(myDanDefi), 100 * oneDollar);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, oneDollar / 10, "Amount must be at least 1"));
        myDanDefi.deposit(tokenId, oneDollar / 10, 1);
    }

    function testDepositOverAUMCap() external Setup {
        uint256 cap = myDanDefi.assetsUnderManagementCap();
        mockERC20.mint(address(this), cap + 1);
        mockERC20.approve(address(myDanDefi), cap + 1);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, cap + 1, "Amount exceeds cap"));
        myDanDefi.deposit(tokenId, cap + 1, 1);
    }

    function testDepositWithInvalidDuration() external Setup {
        mockERC20.mint(address(this), 100 ether);
        mockERC20.approve(address(myDanDefi), 100 ether);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 duration = 1;
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, duration, "Invalid deposit duration"));
        myDanDefi.deposit(tokenId, 1 ether, duration);
    }

    function testDepositWithNonExistentTokenId() external Setup {
        mockERC20.mint(address(this), 1 ether);
        mockERC20.approve(address(myDanDefi), 1 ether);
        uint256 invalidTokenId = 100;
        uint256 validDuration = myDanDefi.depositDurations(0);
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, invalidTokenId, "Token Id does not exist"));
        myDanDefi.deposit(invalidTokenId, 1 ether, validDuration);
    }

    function testDepositWithoutUpgrade() external Setup {
        uint256 testAmount = oneDollar;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);
        assertEq(myDanDefi.currentAUM(), testAmount);
        (uint256 referrerTokenId, , uint256 depositSum, uint256 membershipTier, ) = myDanDefi.profiles(tokenId);
        assertEq(referrerTokenId, myDanDefi.genesisTokenId());
        assertEq(depositSum, testAmount);
        assertEq(membershipTier, 0);
        {
            (uint256 principal, uint256 startTime, uint256 maturity, uint256 interestRate, uint256 interestReceivable, uint256 interestCollected, uint256 lastClaimedAt) = myDanDefi.deposits(
                tokenId,
                0
            );
            assertEq(principal, testAmount);
            assertEq(startTime, block.timestamp);
            assertEq(maturity, block.timestamp + validDuration);
            assertEq(interestRate, 0);
            assertEq(interestReceivable, 0);
            assertEq(interestCollected, 0);
            assertEq(lastClaimedAt, 0);
        }
        {
            (uint256 referralLevel, uint256 referralStartTime, uint256 referralMaturity, uint256 rewardReceivable, uint256 rewardClaimed, uint256 lastClaimedAt, uint256 depositId) = myDanDefi
                .referralRewards(referrerTokenId, 0);
            assertEq(referralLevel, 1);
            assertEq(referralStartTime, block.timestamp);
            assertEq(referralMaturity, block.timestamp + validDuration);
            assertEq(rewardReceivable, (((myDanDefi.referralBonusRewardRates(0) * oneDollar) / 10000) * validDuration) / 365 days);
            assertEq(rewardClaimed, 0);
            assertEq(lastClaimedAt, 0);
            assertEq(depositId, 0);
        }
    }

    function testDepositWithOneUpgrade() external Setup {
        uint256 testAmount = oneDollar * 100;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);
        (uint256 referrerTokenId, , , uint256 membershipTierIndex, ) = myDanDefi.profiles(tokenId);
        assertEq(membershipTierIndex, 1);
        (, , , uint256 tierInterestRate, uint256 referralBonusCollectibleLevelLowerBound, uint256 referralBonusCollectibleLevelUpperBound) = myDanDefi.membershipTiers(membershipTierIndex);
        {
            (uint256 principal, uint256 startTime, uint256 maturity, uint256 interestRate, uint256 interestReceivable, uint256 interestCollected, ) = myDanDefi.deposits(tokenId, 0);
            assertEq(principal, testAmount);
            assertEq(startTime, block.timestamp);
            assertEq(maturity, block.timestamp + validDuration);
            assertEq(interestRate, tierInterestRate);
            assertEq(interestReceivable, (((principal * tierInterestRate) / 10000) * validDuration) / 365 days);
            assertEq(interestCollected, 0);
        }
        {
            (uint256 referralLevel, uint256 referralStartTime, uint256 referralMaturity, uint256 rewardReceivable, uint256 rewardClaimed, uint256 lastClaimedAt, uint256 depositId) = myDanDefi
                .referralRewards(referrerTokenId, 0);
            assertEq(referralLevel, 1);
            assertEq(referralStartTime, block.timestamp);
            assertEq(referralMaturity, block.timestamp + validDuration);
            assertEq(rewardReceivable, (((myDanDefi.referralBonusRewardRates(0) * oneDollar * 100) / 10000) * validDuration) / 365 days);
            assertEq(rewardClaimed, 0);
            assertEq(lastClaimedAt, 0);
            assertEq(depositId, 0);
        }
        {
            for (uint256 referralLevel = referralBonusCollectibleLevelLowerBound; referralLevel <= referralBonusCollectibleLevelUpperBound; referralLevel++) {
                (uint256 activationStart, uint256 activationEnd) = myDanDefi.tierActivationLogs(tokenId, referralLevel, 0);
                assertEq(activationStart, block.timestamp);
                assertEq(activationEnd, 0);
            }
        }
    }

    function testDepositWithThreeUpgrade() external Setup {
        uint256 testAmount = oneDollar * 100000;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);
        (, , , uint256 membershipTierIndex, ) = myDanDefi.profiles(tokenId);
        assertEq(membershipTierIndex, 3);
        (, , , uint256 tierInterestRate, , uint256 referralBonusCollectibleLevelUpperBound) = myDanDefi.membershipTiers(membershipTierIndex);
        {
            (uint256 principal, uint256 startTime, uint256 maturity, uint256 interestRate, uint256 interestReceivable, uint256 interestCollected, uint256 lastClaimedAt) = myDanDefi.deposits(
                tokenId,
                0
            );
            assertEq(principal, testAmount);
            assertEq(startTime, block.timestamp);
            assertEq(maturity, block.timestamp + validDuration);
            assertEq(interestRate, tierInterestRate);
            assertEq(interestReceivable, (((principal * tierInterestRate) / 10000) * validDuration) / 365 days);
            assertEq(interestCollected, 0);
            assertEq(lastClaimedAt, 0);
        }
        {
            for (uint256 referralLevel = 1; referralLevel <= referralBonusCollectibleLevelUpperBound; referralLevel++) {
                (uint256 activationStart, uint256 activationEnd) = myDanDefi.tierActivationLogs(tokenId, referralLevel, 0);
                assertEq(activationStart, block.timestamp);
                assertEq(activationEnd, 0);
            }
        }
    }

    function testDepositWithDurationBonus() external Setup {
        uint256 testAmount = oneDollar * 100;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 durationIndex = 3;
        uint256 validDuration = myDanDefi.depositDurations(durationIndex);
        uint256 durationBonus = myDanDefi.durationBonusRates(validDuration);
        assertTrue(durationBonus > 0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);
        (, , , uint256 membershipTierIndex, ) = myDanDefi.profiles(tokenId);
        (, , , uint256 tierInterestRate, , ) = myDanDefi.membershipTiers(membershipTierIndex);
        {
            (uint256 principal, , , uint256 interestRate, uint256 interestReceivable, , ) = myDanDefi.deposits(tokenId, 0);
            uint256 totalInterestRate = tierInterestRate + durationBonus;
            assertEq(interestRate, totalInterestRate);
            assertEq(interestReceivable, (((principal * totalInterestRate) / 10000) * validDuration) / 365 days);
        }
    }

    function testDepositAsLastLevelReferral() external Setup {
        uint256 testAmount = oneDollar * 100;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId;
        string memory referralCode = myDanDefi.genesisReferralCode();
        uint256 referrerId = 0;
        for (uint256 i = 0; i < referralBonusMaxLevel; i++) {
            tokenId = myDanDefi.claimPass(referralCode);
            // referralIds[tokenId] = referrerId;
            referralCode = string(abi.encodePacked("referrerCodeMadeBy", tokenId.toString()));
            myDanDefi.setReferralCode(referralCode, tokenId);
            // referrerId = tokenId;
        }
        uint256 validDuration = myDanDefi.depositDurations(0);

        for (uint256 i = 0; i < referralBonusMaxLevel; i++) {
            vm.expectEmit(false, false, false, true);
            emit ReferralRewardCreated(referralBonusMaxLevel - (i + 1), i, i + 1);
        }
        myDanDefi.deposit(tokenId, testAmount, validDuration);
    }

    function testClaimInterests() external Setup {
        uint256 testAmount = oneDollar * 100;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);
        uint256 expectedStartTime = block.timestamp;
        vm.warp(block.timestamp + validDuration / 3);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = 0;
        myDanDefi.claimInterests(tokenId, depositIds);
        uint256 expectedInterestClaimed = (((testAmount * 700) / 10000) * 90) / 365 / 3;
        assertEq(expectedInterestClaimed, mockERC20.balanceOf(address(this)));
        (uint256 principal, uint256 startTime, uint256 maturity, uint256 interestRate, uint256 interestReceivable, uint256 interestCollected, uint256 lastClaimedAt) = myDanDefi.deposits(tokenId, 0);
        assertEq(principal, testAmount);
        assertEq(startTime, expectedStartTime);
        assertEq(maturity, expectedStartTime + validDuration);
        assertEq(interestRate, 700);
        assertEq(interestReceivable, (((principal * interestRate) / 10000) * validDuration) / 365 days);
        assertEq(interestCollected, expectedInterestClaimed);
        assertEq(lastClaimedAt, block.timestamp);
    }

    function testClaimInterestsMultipleTimes() external Setup {
        uint256 testAmount = oneDollar * 100;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);
        uint256 expectedStartTime = block.timestamp;
        vm.warp(block.timestamp + validDuration / 3);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = 0;
        myDanDefi.claimInterests(tokenId, depositIds);
        uint256 expectedInterestClaimed = (((testAmount * 700) / 10000) * 90) / 365 / 3;
        uint256 totalExpectedInterest = (((testAmount * 700) / 10000) * 90) / 365;
        assertEq(expectedInterestClaimed, mockERC20.balanceOf(address(this)));
        vm.warp(block.timestamp + validDuration / 3);
        myDanDefi.claimInterests(tokenId, depositIds);
        assertEq(expectedInterestClaimed * 2, mockERC20.balanceOf(address(this)));
        vm.warp(block.timestamp + validDuration / 3 + 100);
        myDanDefi.claimInterests(tokenId, depositIds);
        assertEq(totalExpectedInterest, mockERC20.balanceOf(address(this)));
        vm.warp(block.timestamp + validDuration / 3);
        uint256 received = myDanDefi.claimInterests(tokenId, depositIds);
        assertEq(0, received);
        assertEq(totalExpectedInterest, mockERC20.balanceOf(address(this)));
    }

    function testClaimReferralBonusWhenReferralHasNoDeposit() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);

        uint256 expectedTotalReward = (((testAmount * 600) / 10000) * validDuration) / 365 days;
        vm.warp(block.timestamp + validDuration / 2);
        uint256[] memory bonusIds = new uint256[](1);
        bonusIds[0] = 0;
        uint256 received = myDanDefi.claimReferralBonus(myDanDefi.genesisTokenId(), bonusIds);
        // should receive zero because genesis hasnt deposited
        assertEq(0, received);
    }

    function testClaimReferralBonusWhenReferralHasDeposit() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        mockERC20.mint(address(this), testAmount * 2);
        mockERC20.approve(address(myDanDefi), testAmount * 2);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(myDanDefi.genesisTokenId(), testAmount, validDuration);
        myDanDefi.deposit(tokenId, testAmount, validDuration);

        uint256 expectedTotalReward = (((testAmount * 600) / 10000) * validDuration) / 365 days;
        vm.warp(block.timestamp + validDuration / 2);
        uint256[] memory bonusIds = new uint256[](1);
        bonusIds[0] = 0;
        uint256 received = myDanDefi.claimReferralBonus(myDanDefi.genesisTokenId(), bonusIds);
        assertEq(expectedTotalReward / 2, received);
        // claim again
        vm.warp(block.timestamp + validDuration / 2 + 100);
        received = myDanDefi.claimReferralBonus(myDanDefi.genesisTokenId(), bonusIds);
        assertEq(expectedTotalReward / 2, received);
        assertEq(mockERC20.balanceOf(address(this)), expectedTotalReward);
    }

    function testClaimReferralBonusWithActivationLaterThanRewardCreation() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        mockERC20.mint(address(this), testAmount * 2);
        mockERC20.approve(address(myDanDefi), testAmount * 2);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 validDuration = myDanDefi.depositDurations(0);
        myDanDefi.deposit(tokenId, testAmount, validDuration);

        uint256 expectedTotalReward = (((testAmount * 600) / 10000) * validDuration) / 365 days;
        vm.warp(block.timestamp + validDuration / 2);
        // deposit after 1/2 duration has passed and activate
        myDanDefi.deposit(myDanDefi.genesisTokenId(), testAmount, validDuration);
        vm.warp(block.timestamp + validDuration / 2);
        // claim after another 1/2 duration has passed. only receive half
        uint256[] memory bonusIds = new uint256[](1);
        bonusIds[0] = 0;
        uint256 received = myDanDefi.claimReferralBonus(myDanDefi.genesisTokenId(), bonusIds);
        assertEq(expectedTotalReward / 2, received);
        assertEq(mockERC20.balanceOf(address(this)), expectedTotalReward / 2);
    }
}
