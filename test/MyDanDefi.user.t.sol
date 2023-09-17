// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyDanDefi.sol";
import "../src/MyDanDefiStorage.sol";
import "../src/MyDanDefiProxy.sol";
import "./mocks/MockERC20.sol";
import "./MyDanDefi.setup.t.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract MyDanDefiTest is Test, MyDanDefiTestSetup {
    using Strings for uint256;
    event ReferralBonusCreated(uint256 referrerTokenId, uint256 referralBonusId, uint256 referralLevel, uint256 depositId);
    event ReferralBonusLevelCollectionDeactivated(uint256 tokenId, uint256 referralLevel, uint256 logIndex, uint256 timestamp);

    function testClaimPass() external Setup {
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        assertEq(myDanPass.ownerOf(mintedTokenId), address(this));
        (uint256 referrerTokenId, , , , ) = myDanDefi.profiles(mintedTokenId);
        assertEq(referrerTokenId, myDanDefi.genesisTokenId());
        // test non genesis referral code
        string memory referralCode = "mydandefi2";
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector));
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
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector));
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
    }

    function testSetReferralCodeAlreadyInUse() external Setup {
        // mint a pass
        uint256 mintedTokenId1 = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 mintedTokenId2 = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "hello";
        myDanDefi.setReferralCode(referralCode, mintedTokenId1);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringArgument.selector));
        myDanDefi.setReferralCode(referralCode, mintedTokenId2);
    }

    function testSetReferralCodeTwice() external Setup {
        // mint a pass
        uint256 mintedTokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        string memory referralCode = "hello";
        myDanDefi.setReferralCode(referralCode, mintedTokenId);
        string memory newReferralCode = "hello2";
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, mintedTokenId));
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
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, oneDollar / 10));
        myDanDefi.deposit(tokenId, oneDollar / 10, 1);
    }

    function testDepositOverAUMCap() external Setup {
        uint256 cap = myDanDefi.assetsUnderManagementCap();
        mockERC20.mint(address(this), cap + 1);
        mockERC20.approve(address(myDanDefi), cap + 1);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, cap + 1));
        myDanDefi.deposit(tokenId, cap + 1, 1);
    }

    function testDepositWithInvalidDuration() external Setup {
        mockERC20.mint(address(this), 100 ether);
        mockERC20.approve(address(myDanDefi), 100 ether);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 duration = 1;
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, duration));
        myDanDefi.deposit(tokenId, 1 ether, duration);
    }

    function testDepositWithNonExistentTokenId() external Setup {
        mockERC20.mint(address(this), 1 ether);
        mockERC20.approve(address(myDanDefi), 1 ether);
        uint256 invalidTokenId = 100;
        uint256 validDuration = myDanDefi.depositDurations(0);
        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, invalidTokenId));
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
            (uint256 referralLevel, uint256 referralStartTime, uint256 referralMaturity, uint256 referralBonusReceivable, uint256 rewardClaimed, uint256 lastClaimedAt, uint256 depositId) = myDanDefi
                .referralBonuses(referrerTokenId, 0);
            assertEq(referralLevel, 1);
            assertEq(referralStartTime, block.timestamp);
            assertEq(referralMaturity, block.timestamp + validDuration);
            assertEq(referralBonusReceivable, (((myDanDefi.referralBonusRates(1) * oneDollar) / 10000) * validDuration) / 365 days);
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
            (uint256 referralLevel, uint256 referralStartTime, uint256 referralMaturity, uint256 referralBonusReceivable, uint256 rewardClaimed, uint256 lastClaimedAt, uint256 depositId) = myDanDefi
                .referralBonuses(referrerTokenId, 0);
            assertEq(referralLevel, 1);
            assertEq(referralStartTime, block.timestamp);
            assertEq(referralMaturity, block.timestamp + validDuration);
            assertEq(referralBonusReceivable, (((myDanDefi.referralBonusRates(1) * oneDollar * 100) / 10000) * validDuration) / 365 days);
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
        for (uint256 i = 0; i < referralBonusMaxLevel; i++) {
            tokenId = myDanDefi.claimPass(referralCode);
            // referralIds[tokenId] = referrerId;
            referralCode = string(abi.encodePacked("referrerCodeMadeBy", tokenId.toString()));
            myDanDefi.setReferralCode(referralCode, tokenId);
            // referrerId = tokenId;
        }
        uint256 validDuration = myDanDefi.depositDurations(0);

        for (uint256 i = 1; i < referralBonusMaxLevel; i++) {
            vm.expectEmit(false, false, false, true);
            emit ReferralBonusCreated(referralBonusMaxLevel - (i), i - 1, i, 0);
        }
        myDanDefi.deposit(tokenId, testAmount, validDuration);
        uint256[] memory allReferrers = myDanDefi.getAllReferrers(tokenId);
        assertEq(allReferrers.length, referralBonusMaxLevel - 1);
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
        myDanDefi.collectInterests(tokenId, depositIds);
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
        vm.warp(block.timestamp + validDuration / 3);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = 0;
        myDanDefi.collectInterests(tokenId, depositIds);
        uint256 expectedInterestClaimed = (((testAmount * 700) / 10000) * 90) / 365 / 3;
        uint256 totalExpectedInterest = (((testAmount * 700) / 10000) * 90) / 365;
        assertEq(expectedInterestClaimed, mockERC20.balanceOf(address(this)));
        vm.warp(block.timestamp + validDuration / 3);
        myDanDefi.collectInterests(tokenId, depositIds);
        assertEq(expectedInterestClaimed * 2, mockERC20.balanceOf(address(this)));
        vm.warp(block.timestamp + validDuration / 3 + 100);
        myDanDefi.collectInterests(tokenId, depositIds);
        assertEq(totalExpectedInterest, mockERC20.balanceOf(address(this)));
        vm.warp(block.timestamp + validDuration / 3);
        uint256 received = myDanDefi.collectInterests(tokenId, depositIds);
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

        vm.warp(block.timestamp + validDuration / 2);
        uint256[] memory bonusIds = new uint256[](1);
        bonusIds[0] = 0;
        uint256 received = myDanDefi.claimReferralBonus(myDanDefi.genesisTokenId(), bonusIds);
        // should receive zero because genesis hasnt deposited
        assertEq(0, received);
    }

    function testClaimReferralBonusWithActivationBeforeRewardCreation() external Setup {
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

    function testClaimReferralBonusWithDeactivation() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        mockERC20.mint(address(this), testAmount * 3);
        mockERC20.approve(address(myDanDefi), type(uint256).max);
        uint256 genesisTokenId = myDanDefi.genesisTokenId();
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 oneYear = 365 days;
        uint256 depositId = myDanDefi.deposit(tokenId, testAmount, oneYear);
        vm.warp(block.timestamp + 30 days);
        // activate for 180 days
        depositId = myDanDefi.deposit(genesisTokenId, testAmount, 180 days);
        vm.warp(block.timestamp + 180 days);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = depositId;
        myDanDefi.withdraw(genesisTokenId, depositIds);
        // deactivate for 30 days
        vm.warp(block.timestamp + 30 days);
        depositId = myDanDefi.deposit(genesisTokenId, testAmount, 90 days);
        // activate for 100 days (depsite being matured)
        vm.warp(block.timestamp + 100 days);
        depositIds[0] = depositId;
        uint256 withdrawnAmount = myDanDefi.withdraw(genesisTokenId, depositIds);
        uint256 expectedWithdrawnAmount = (((testAmount * 800) / 10000) * 90) / 365 + testAmount;
        assertEq(withdrawnAmount, expectedWithdrawnAmount);
        // total activation days = 90 + 100 = 190
        uint256 totalReward = (testAmount * 600) / 10000;
        // this takes into the 10 extra days becoz the user hasnt been downgraded due to withdrawal.
        uint256 expectedReferralBonus = (totalReward * 280) / 365;
        uint256[] memory referralBonusIds = new uint256[](1);
        referralBonusIds[0] = 0;
        uint256 calculatedReferralBonus = myDanDefi.getClaimableReferralBonus(genesisTokenId, referralBonusIds);
        uint256 receivedReferralBonus = myDanDefi.claimReferralBonus(genesisTokenId, referralBonusIds);
        assertEq(calculatedReferralBonus, expectedReferralBonus);
        assertEq(receivedReferralBonus, expectedReferralBonus);
        {
            (uint256 referralLevel, , , uint256 referralBonusReceivable, uint256 rewardClaimed, uint256 lastClaimedAt, uint256 contributorDepositId) = myDanDefi.referralBonuses(0, 0);
            assertEq(referralLevel, 1);
            assertEq(referralBonusReceivable, totalReward);
            assertEq(rewardClaimed, expectedReferralBonus);
            assertEq(lastClaimedAt, block.timestamp);
            assertEq(contributorDepositId, 0);
        }
    }

    function testWithdraw() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 duration = 365 days;
        uint256 depositId = myDanDefi.deposit(tokenId, testAmount, duration);
        vm.warp(block.timestamp + duration);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = depositId;
        // airdrop for liquidity management
        uint256 aumBeforeWithdrawal = myDanDefi.currentAUM();
        mockERC20.mint(address(myDanDefi), testAmount);
        uint256 deactivationTime = block.timestamp;
        // expect events
        for (uint256 referralLevel = 1; referralLevel < referralBonusMaxLevel; referralLevel++) {
            vm.expectEmit(false, false, false, true);
            emit ReferralBonusLevelCollectionDeactivated(tokenId, referralLevel, 0, deactivationTime);
        }
        uint256 withdrawnAmount = myDanDefi.withdraw(tokenId, depositIds);
        // expect aum decrease
        uint256 expectedWithdrawnAmount = (testAmount * 850) / 10000 + testAmount;
        assertEq(withdrawnAmount, expectedWithdrawnAmount);
        assertEq(mockERC20.balanceOf(address(this)), expectedWithdrawnAmount);
        uint256 aumAfterWithdrawal = myDanDefi.currentAUM();
        assertEq(aumAfterWithdrawal, aumBeforeWithdrawal - testAmount);
        // expect profile depositSum/ vip tier change
        (, , uint256 depositSum, uint256 membershipTier, ) = myDanDefi.profiles(tokenId);
        assertEq(depositSum, 0);
        assertEq(membershipTier, 0);
        // withdraw again should revert

        vm.expectRevert(abi.encodeWithSelector(InvalidArgument.selector, depositId));
        myDanDefi.withdraw(tokenId, depositIds);
    }

    function testWithdrawAfterHalfInterestHasBeenClaimed() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        // airdrop for liquidity management
        mockERC20.mint(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);

        uint256 duration = 365 days;
        uint256 depositId = myDanDefi.deposit(tokenId, testAmount, duration);
        vm.warp(block.timestamp + duration / 2);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = depositId;
        uint256 calculatedInterests = myDanDefi.getCollectableInterests(tokenId, depositIds);
        uint256 interestsClaimed = myDanDefi.collectInterests(tokenId, depositIds);
        // check half interest claimed
        uint256 expectedHalfInterests = ((((testAmount * 850) / 10000) * duration) / 2) / 365 days;
        assertEq(interestsClaimed, calculatedInterests);
        assertEq(interestsClaimed, expectedHalfInterests);
        assertEq(mockERC20.balanceOf(address(this)), interestsClaimed);
        vm.warp(block.timestamp + duration / 2);
        interestsClaimed = myDanDefi.collectInterests(tokenId, depositIds);
        assertEq(interestsClaimed, expectedHalfInterests);
        assertEq(mockERC20.balanceOf(address(this)), expectedHalfInterests * 2);
        uint256 withdrawnAmount = myDanDefi.withdraw(tokenId, depositIds);
        assertEq(withdrawnAmount, testAmount);
        assertEq(mockERC20.balanceOf(address(this)), expectedHalfInterests * 2 + testAmount);
    }

    function testWithdrawBeforeMaturity() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 duration = 365 days;
        uint256 maturity = block.timestamp + duration;
        uint256 depositId = myDanDefi.deposit(tokenId, testAmount, duration);
        vm.warp(block.timestamp + duration - 1);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = depositId;
        // airdrop for liquidity management
        mockERC20.mint(address(myDanDefi), testAmount);
        vm.expectRevert(abi.encodeWithSelector(NotWithdrawable.selector, tokenId, depositId, maturity));
        myDanDefi.withdraw(tokenId, depositIds);
    }

    function testWithdrawOnBehalf() external Setup {
        uint256 testAmount = oneDollar * 100_000_000;
        mockERC20.mint(address(this), testAmount);
        mockERC20.approve(address(myDanDefi), testAmount);
        uint256 tokenId = myDanDefi.claimPass(myDanDefi.genesisReferralCode());
        uint256 duration = 365 days;
        uint256 depositId = myDanDefi.deposit(tokenId, testAmount, duration);
        vm.warp(block.timestamp + duration);
        uint256[] memory depositIds = new uint256[](1);
        depositIds[0] = depositId;
        // airdrop for liquidity management
        mockERC20.mint(address(myDanDefi), testAmount);
        vm.prank(deadAddress);
        uint256 withdrawnAmount = myDanDefi.withdraw(tokenId, depositIds);
        uint256 expectedWithdrawnAmount = (testAmount * 850) / 10000 + testAmount;
        // nft owner gets the token, not the triggerer
        assertEq(withdrawnAmount, expectedWithdrawnAmount);
        assertEq(mockERC20.balanceOf(address(this)), expectedWithdrawnAmount);
        assertEq(mockERC20.balanceOf(deadAddress), 0);
    }
}
