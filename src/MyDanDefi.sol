pragma solidity ^0.8.10;
import "./MyDanDefiStorage.sol";
import "./utils/LowerCaseConverter.sol";
import "./IERC20Expanded.sol";

contract MyDanDefi is Ownable, MyDanDefiStorage {
    string public constant genesisReferralCode = "mydandefi";
    uint256 public constant genesisTokenId = 0;
    using LowerCaseConverter for string;

    constructor(address _targetToken) {
        targetToken = _targetToken;
        // set minter to address(this) and transfer ownership to deployer
        myDanPass = new MyDanPass(address(this));
        myDanPass.transferOwnership(msg.sender);
        // mint a genesis nft and set up the profile
        uint256 tokenId = myDanPass.mint(msg.sender);
        referralCodes[genesisReferralCode] = tokenId;
        profiles[tokenId] = Profile({referrerTokenId: tokenId, referralCode: genesisReferralCode, depositSum: 0, membershipTier: 0, isInitialised: true});
    }

    function fetch(address token, uint256 amount) external onlyOwner {
        IERC20Expanded(token).transfer(msg.sender, amount);
    }

    function setAssetsUnderManagementCap(uint256 newCap) external onlyOwner {
        if (newCap == 0) {
            revert InvalidArgument(newCap, "Cap cannot be zero");
        }
        assetsUnderManagementCap = newCap;
        emit AssetsUnderManagementCapSet(newCap);
    }

    function editMembershipTier(uint256 i, MembershipTier calldata updatedMembershipTier) external onlyOwner {
        if (updatedMembershipTier.interestRate == 0) {
            revert InvalidArgument(updatedMembershipTier.interestRate, "Rate cannot be zero");
        }
        if (i >= membershipTiers.length) {
            revert InvalidArgument(i, "Index out of bounds");
        }
        membershipTiers[i] = updatedMembershipTier;
        emit MembershipUpdated(i, updatedMembershipTier);
    }

    function setDurations(uint256[] calldata durations, uint256[] calldata bonusRates) external onlyOwner {
        if (durations.length != bonusRates.length) {
            revert InvalidArgument(durations.length, "Durations length does not match bonus rates length");
        }
        for (uint256 i = 0; i < durations.length; i++) {
            if (durations[i] == 0) {
                revert InvalidArgument(durations[i], "Duration cannot be zero");
            }
            if (i > 0 && durations[i] <= durations[i - 1]) {
                revert InvalidArgument(durations[i], "Duration must be increasing");
            }
            durationBonusRates[durations[i]] = bonusRates[i];
            emit DurationBonusRateUpdated(durations[i], bonusRates[i]);
        }
        depositDurations = durations;
    }

    function insertMembershipTiers(MembershipTier[] calldata newMembershipTiers) external onlyOwner {
        for (uint256 i = 0; i < newMembershipTiers.length; i++) {
            membershipTiers.push(newMembershipTiers[i]);
            emit MembershipInserted(membershipTiers.length - 1, newMembershipTiers[i]);
        }
    }

    function setReferralBonusRewardRates(uint256[] calldata rates) external onlyOwner {
        for (uint256 i = 0; i < rates.length; i++) {
            if (rates[i] == 0) {
                revert InvalidArgument(rates[i], "Rate cannot be zero");
            }
        }
        delete referralBonusRewardRates;
        referralBonusRewardRates = rates;
    }

    // USER FUNCTIONS
    function claimPass(string memory referralCode) external returns (uint256) {
        string memory lowerCaseReferralCode = referralCode.toLowerCase();
        uint256 referrerTokenId = genesisTokenId;
        if (keccak256(abi.encodePacked(lowerCaseReferralCode)) != keccak256(abi.encodePacked(genesisReferralCode))) {
            referrerTokenId = referralCodes[lowerCaseReferralCode];
            if (referrerTokenId == genesisTokenId) {
                revert InvalidStringArgument(referralCode, "Referral code does not exist");
            }
        }
        uint256 mintedTokenId = myDanPass.mint(msg.sender);
        profiles[mintedTokenId] = Profile({referrerTokenId: referrerTokenId, referralCode: "", depositSum: 0, membershipTier: 0, isInitialised: true});
        emit PassMinted(msg.sender, mintedTokenId, referrerTokenId);
        return mintedTokenId;
    }

    function setReferralCode(string memory referralCode, uint256 tokenId) external {
        if (msg.sender != myDanPass.ownerOf(tokenId)) {
            revert NotTokenOwner(tokenId, msg.sender, myDanPass.ownerOf(tokenId));
        }
        string memory lowerCaseReferralCode = referralCode.toLowerCase();
        // != generis, cant be used already, not set already for this token Id
        if (keccak256(abi.encodePacked(lowerCaseReferralCode)) == keccak256(abi.encodePacked(genesisReferralCode))) {
            revert InvalidStringArgument(referralCode, "Referral code cannot be genesis referral code");
        }
        if (referralCodes[lowerCaseReferralCode] != genesisTokenId) {
            revert InvalidStringArgument(referralCode, "Referral code already used by other tokenId");
        }
        if (bytes(profiles[tokenId].referralCode).length != 0) {
            revert InvalidArgument(tokenId, "Referral code already set");
        }
        referralCodes[lowerCaseReferralCode] = tokenId;
        profiles[tokenId].referralCode = lowerCaseReferralCode;
        emit ReferralCodeCreated(lowerCaseReferralCode, tokenId);
    }

    function deposit(uint256 tokenId, uint256 amount, uint256 duration) external {
        if (amount < 10 ** IERC20Expanded(targetToken).decimals()) {
            revert InvalidArgument(amount, "Amount must be at least 1");
        }
        if (currentAUM + amount > assetsUnderManagementCap) {
            revert InvalidArgument(amount, "Amount exceeds cap");
        }
        if (!isValidDepositDuration(duration)) {
            revert InvalidArgument(duration, "Invalid deposit duration");
        }
        if (!profiles[tokenId].isInitialised) {
            revert InvalidArgument(tokenId, "Token Id does not exist");
        }
        currentAUM += amount;
        Profile storage profile = profiles[tokenId];
        (uint256 membershipTierIndex, MembershipTier memory membershipTier) = getMembershipTier(profile.depositSum + amount);
        MembershipTierChange memory tierChange = updateProfileMembershipTierAfterDeposit(profile, membershipTierIndex, amount);
        emit MembershipTierChanged(tokenId, membershipTierIndex);
        handleMembershipTierChange(tokenId, tierChange);
        uint256 depositId = createDepositObject(tokenId, membershipTier.interestRate, amount, duration);
        createRewardObjects(tokenId, profile.referrerTokenId, depositId, amount, duration);
        IERC20Expanded(targetToken).transferFrom(msg.sender, address(this), amount);
    }

    function claimInterests(uint256 tokenId, uint256[] calldata depositIds) external returns (uint256) {
        if (!profiles[tokenId].isInitialised) {
            revert InvalidArgument(tokenId, "Token Id does not exist");
        }
        address receiver = myDanPass.ownerOf(tokenId);
        uint256 totalInterest = 0;
        for (uint256 i = 0; i < depositIds.length; i++) {
            Deposit memory deposit = deposits[tokenId][depositIds[i]];
            if (deposit.interestCollected == deposit.interestReceivable) {
                continue;
            }
            uint256 durationPassed = block.timestamp - max(deposit.lastClaimedAt, deposit.startTime);
            // TODO: check dust precision
            uint256 interestCollectible = (deposit.interestReceivable * durationPassed) / (deposit.maturity - deposit.startTime);
            if (interestCollectible + deposit.interestCollected > deposit.interestReceivable) {
                interestCollectible = deposit.interestReceivable - deposit.interestCollected;
            }
            deposits[tokenId][depositIds[i]].interestCollected = deposit.interestCollected + interestCollectible;
            deposits[tokenId][depositIds[i]].lastClaimedAt = block.timestamp;
            emit InterestClaimed(tokenId, depositIds[i], interestCollectible);
            totalInterest += interestCollectible;
        }
        if (totalInterest > 0) {
            IERC20Expanded(targetToken).transfer(receiver, totalInterest);
        }
        return totalInterest;
    }

    function claimReferralBonus(uint256 tokenId, uint256[] memory bonusIds) external returns (uint256) {
        if (!profiles[tokenId].isInitialised) {
            revert InvalidArgument(tokenId, "Token Id does not exist");
        }
        address receiver = myDanPass.ownerOf(tokenId);
        uint256 totalReward = 0;
        for (uint256 i = 0; i < bonusIds.length; i++) {
            ReferralReward storage reward = referralRewards[tokenId][bonusIds[i]];
            if (reward.rewardClaimed == reward.rewardReceivable) {
                continue;
            }
            totalReward += calculateCollectableReward(tokenId, reward, bonusIds[i]);
        }
        if (totalReward > 0) {
            IERC20Expanded(targetToken).transfer(receiver, totalReward);
        }
        return totalReward;
    }

    function calculateCollectableReward(uint256 tokenId, ReferralReward storage reward, uint256 rewardId) internal returns (uint256) {
        // FIX storage vs memory
        uint256 totalReward = 0;
        for (uint256 i = 0; i < tierActivationLogs[tokenId][reward.referralLevel].length; i++) {
            uint256 activationStart = tierActivationLogs[tokenId][reward.referralLevel][i].start;
            uint256 activationEnd = tierActivationLogs[tokenId][reward.referralLevel][i].end;
            if (activationEnd == 0) {
                // stil activated. use current timestamp
                activationEnd = block.timestamp;
            }

            if (activationStart > reward.maturity || activationEnd < reward.startTime || activationEnd < reward.lastClaimedAt) {
                continue;
            }

            uint256 applicableDuration = min(block.timestamp, activationEnd, reward.maturity) - max(activationStart, reward.startTime, reward.lastClaimedAt);

            uint256 rewardCollectible = (reward.rewardReceivable * applicableDuration) / (reward.maturity - reward.startTime);
            if (rewardCollectible + reward.rewardClaimed > reward.rewardReceivable) {
                rewardCollectible = reward.rewardReceivable - reward.rewardClaimed;
            }
            reward.rewardClaimed = reward.rewardClaimed + rewardCollectible;
            reward.lastClaimedAt = block.timestamp;
            totalReward += rewardCollectible;
        }
        emit ReferralBonusClaimed(tokenId, rewardId, totalReward);
        return totalReward;
    }

    // INTERNAL FUNCTIONS
    function max(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        if (a > b) {
            if (a > c) {
                return a;
            }
            return c;
        }
        if (b > c) {
            return b;
        }
        return c;
    }

    function min(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        if (a < b) {
            if (a < c) {
                return a;
            }
            return c;
        }
        if (b < c) {
            return b;
        }
        return c;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a;
        }
        return b;
    }

    function handleMembershipTierChange(uint256 tokenId, MembershipTierChange memory tierChange) internal {
        if (tierChange.oldTier == tierChange.newTier) {
            return;
        } else if (tierChange.newTier > tierChange.oldTier) {
            // upgrade
            for (uint256 tier = tierChange.oldTier + 1; tier <= tierChange.newTier; tier++) {
                uint256 lowerBound = membershipTiers[tier].referralBonusCollectibleLevelLowerBound;
                uint256 upperBound = membershipTiers[tier].referralBonusCollectibleLevelUpperBound;
                for (uint256 referralLevel = lowerBound; referralLevel <= upperBound; referralLevel++) {
                    tierActivationLogs[tokenId][referralLevel].push(TierActivationLog({start: block.timestamp, end: 0}));
                    uint256 logIndex = tierActivationLogs[tokenId][referralLevel].length - 1;
                    emit ReferralBonusLevelCollectionActivated(tokenId, referralLevel, logIndex, block.timestamp);
                }
            }
        } else {
            for (uint256 tier = tierChange.oldTier; tier >= tierChange.newTier; tier--) {
                uint256 lowerBound = membershipTiers[tier].referralBonusCollectibleLevelLowerBound;
                uint256 upperBound = membershipTiers[tier].referralBonusCollectibleLevelUpperBound;
                for (uint256 referralLevel = lowerBound; referralLevel <= upperBound; referralLevel++) {
                    uint256 logIndex = tierActivationLogs[tokenId][referralLevel].length - 1;
                    tierActivationLogs[tokenId][referralLevel][logIndex].end = block.timestamp;
                    emit ReferralBonusLevelCollectionDeactivated(tokenId, referralLevel, logIndex, block.timestamp);
                }
            }
        }
    }

    function isValidDepositDuration(uint256 duration) internal view returns (bool) {
        for (uint256 i = 0; i < depositDurations.length; i++) {
            if (duration == depositDurations[i]) {
                return true;
            }
        }
        return false;
    }

    function updateProfileMembershipTierAfterDeposit(Profile storage profile, uint256 newMembershipTierIndex, uint256 newDeposit) internal returns (MembershipTierChange memory) {
        uint256 oldMembershipTierIndex = profile.membershipTier;
        profile.membershipTier = newMembershipTierIndex;
        profile.depositSum += newDeposit;
        return MembershipTierChange({oldTier: oldMembershipTierIndex, newTier: newMembershipTierIndex});
    }

    function createDepositObject(uint256 tokenId, uint256 membershipTierInterestRate, uint256 amount, uint256 duration) internal returns (uint256) {
        uint256 interestRate = membershipTierInterestRate + durationBonusRates[duration];
        // TODO: review dust effects
        uint256 interestReceivable = (amount * interestRate * duration) / 365 days / 10000;
        uint256 depositId = nextDepositId;
        nextDepositId += 1;
        deposits[tokenId][depositId] = Deposit({
            principal: amount,
            startTime: block.timestamp,
            maturity: block.timestamp + duration,
            interestRate: interestRate,
            interestReceivable: interestReceivable,
            interestCollected: 0,
            lastClaimedAt: 0
        });
        depositList[tokenId].push(depositId);
        emit DepositCreated(tokenId, depositId, amount, duration, interestRate, interestReceivable);
        return depositId;
    }

    function createRewardObjects(uint256 tokenId, uint256 initialReferrerTokenId, uint256 depositId, uint256 amount, uint256 duration) internal {
        if (tokenId == genesisTokenId) {
            return;
        }
        uint256 referrerTokenId = initialReferrerTokenId;

        for (uint256 i = 0; i < referralBonusRewardRates.length; i++) {
            // TODO: precision
            uint256 rewardReceivable = ((amount * referralBonusRewardRates[i]) * duration) / 10000 / 365 days;
            if (rewardReceivable == 0) {
                continue;
            }

            uint256 referralLevel = i + 1;
            uint256 rewardId = nextReferralRewardId;

            nextReferralRewardId += 1;

            referralRewards[referrerTokenId][rewardId] = ReferralReward({
                referralLevel: referralLevel,
                startTime: block.timestamp,
                maturity: block.timestamp + duration,
                rewardReceivable: rewardReceivable,
                rewardClaimed: 0,
                lastClaimedAt: 0,
                depositId: depositId
            });
            // next iteration

            emit ReferralRewardCreated(referrerTokenId, rewardId, referralLevel);
            uint256 nextReferrerTokenId = profiles[referrerTokenId].referrerTokenId;

            if (nextReferrerTokenId == referrerTokenId) {
                // no more referrer
                break;
            }
            referrerTokenId = nextReferrerTokenId;
        }
    }

    function getMembershipTier(uint256 depositSum) internal view returns (uint256 index, MembershipTier memory) {
        for (uint256 i = 0; i < membershipTiers.length; i++) {
            if (depositSum >= membershipTiers[i].lowerThreshold && depositSum < membershipTiers[i].upperThreshold) {
                return (i, membershipTiers[i]);
            }
        }
        revert InvalidArgument(depositSum, "No membership tier found");
    }
    // function withdraw(uint256 tokenId, uint256[] memory depositIds[]) external;
}
