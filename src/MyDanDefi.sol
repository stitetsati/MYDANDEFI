pragma solidity ^0.8.10;
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./MyDanDefiStorage.sol";
import "./utils/LowerCaseConverter.sol";
import "./utils/MyDanDefiUtility.sol";
import "./IERC20Expanded.sol";

contract MyDanDefi is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard, MyDanDefiUtility, MyDanDefiStorage {
    string public constant genesisReferralCode = "mydandefi";
    uint256 public constant genesisTokenId = 0;
    using LowerCaseConverter for string;

    constructor() initializer {}

    function initialize(address _targetToken) public initializer {
        __Ownable_init();
        targetToken = _targetToken;
        // set minter to address(this) and transfer ownership to deployer
        myDanPass = new MyDanPass(address(this));
        myDanPass.transferOwnership(msg.sender);
        // mint a genesis nft and set up the profile
        uint256 tokenId = myDanPass.mint(msg.sender);
        referralCodes[genesisReferralCode] = tokenId;
        profiles[tokenId] = Profile({referrerTokenId: tokenId, referralCode: genesisReferralCode, depositSum: 0, membershipTier: 0, isInitialised: true});
    }

    /**********************************/
    /**********************************/
    /*****                       ******/
    /*****    ADMIN FUNCTIONS    ******/
    /*****                       ******/
    /**********************************/
    /**********************************/

    function fetch(address token, uint256 amount) external onlyOwner {
        sendToken(token, msg.sender, amount);
    }

    function setAssetsUnderManagementCap(uint256 newCap) external onlyOwner {
        if (newCap == 0) {
            revert InvalidArgument(newCap, "Cap cannot be zero");
        }
        assetsUnderManagementCap = newCap;
        emit AssetsUnderManagementCapSet(newCap);
    }

    function editMembershipTier(uint256 i, MembershipTier calldata updatedMembershipTier) external onlyOwner {
        // TODO: check reward calc impact
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

    function setReferralBonusRates(uint256[] calldata rates) external onlyOwner {
        if (rates[0] != 0) {
            revert InvalidArgument(rates[0], "First rate must be zero");
        }
        delete referralBonusRates;
        referralBonusRates = rates;
    }

    /**********************************/
    /**********************************/
    /*****                       ******/
    /*****     USER FUNCTIONS    ******/
    /*****                       ******/
    /**********************************/
    /**********************************/

    function claimPass(string memory referralCode) external nonReentrant returns (uint256) {
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

    function deposit(uint256 tokenId, uint256 amount, uint256 duration) external nonReentrant returns (uint256) {
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
        (uint256 newMembershipTierIndex, uint256 tierInterestRate) = getMembershipTierInterestByDeposit(profile.depositSum + amount);

        handleMembershipTierUpdate(tokenId, profile, newMembershipTierIndex, profile.depositSum + amount);
        uint256 depositId = createDepositObject(tokenId, tierInterestRate, amount, duration);
        createReferralBonusObjects(tokenId, profile.referrerTokenId, depositId, amount, duration);
        IERC20Expanded(targetToken).transferFrom(msg.sender, address(this), amount);
        return depositId;
    }

    function collectInterests(uint256 tokenId, uint256[] calldata depositIds) external nonReentrant returns (uint256) {
        if (!profiles[tokenId].isInitialised) {
            revert InvalidArgument(tokenId, "Token Id does not exist");
        }
        return _collectInterests(tokenId, depositIds);
    }

    function withdraw(uint256 tokenId, uint256[] calldata depositIds) external nonReentrant returns (uint256) {
        if (!profiles[tokenId].isInitialised) {
            revert InvalidArgument(tokenId, "Token Id does not exist");
        }

        uint256 interestClaimed = _collectInterests(tokenId, depositIds);
        address receiver = myDanPass.ownerOf(tokenId);
        uint256 withdrawnPrincipal = 0;

        for (uint256 i = 0; i < depositIds.length; i++) {
            Deposit memory deposit = deposits[tokenId][depositIds[i]];
            if (deposit.maturity == 0) {
                revert InvalidArgument(depositIds[i], "Deposit does not exist");
            }
            if (deposit.maturity > block.timestamp) {
                revert NotWithdrawable(tokenId, depositIds[i], deposit.maturity);
            }
            withdrawnPrincipal += deposit.principal;
            emit DepositWithdrawn(tokenId, depositIds[i], deposit.principal);
            delete deposits[tokenId][depositIds[i]];
        }
        if (withdrawnPrincipal == 0) {
            return withdrawnPrincipal;
        }
        currentAUM -= withdrawnPrincipal;
        Profile storage profile = profiles[tokenId];
        (uint256 newMembershipTierIndex, ) = getMembershipTierInterestByDeposit(profile.depositSum - withdrawnPrincipal);
        handleMembershipTierUpdate(tokenId, profile, newMembershipTierIndex, profile.depositSum - withdrawnPrincipal);
        sendToken(targetToken, receiver, withdrawnPrincipal);
        return withdrawnPrincipal + interestClaimed;
    }

    function claimReferralBonus(uint256 tokenId, uint256[] calldata referralBonusIds) external nonReentrant returns (uint256) {
        if (!profiles[tokenId].isInitialised) {
            revert InvalidArgument(tokenId, "Token Id does not exist");
        }
        address receiver = myDanPass.ownerOf(tokenId);
        uint256 totalReward = 0;
        totalReward = _claimReferralBonus(tokenId, referralBonusIds);
        sendToken(targetToken, receiver, totalReward);

        return totalReward;
    }

    /**********************************/
    /**********************************/
    /*****                       ******/
    /*****     VIEW FUNCTIONS    ******/
    /*****                       ******/
    /**********************************/
    /**********************************/

    function getClaimableReferralBonus(uint256 tokenId, uint256[] calldata referralBonusIds) public view returns (uint256) {
        // FIX storage vs memory
        uint256 totalReward = 0;
        for (uint256 i = 0; i < referralBonusIds.length; i++) {
            totalReward += calculateClaimableReferralBonus(tokenId, referralBonusIds[i]);
        }
        return totalReward;
    }

    function getCollectableInterests(uint256 tokenId, uint256[] calldata depositIds) public view returns (uint256) {
        uint256 totalInterests = 0;
        for (uint256 i = 0; i < depositIds.length; i++) {
            totalInterests += _calculateInterests(tokenId, depositIds[i]);
        }
        return totalInterests;
    }

    /**********************************/
    /**********************************/
    /*****                       ******/
    /*****  INTERNAL FUNCTIONS   ******/
    /*****                       ******/
    /**********************************/
    /**********************************/

    function sendToken(address token, address to, uint256 value) internal {
        if (IERC20Expanded(token).balanceOf(address(this)) < value) {
            revert InvalidArgument(value, "Not enough token balance");
        }
        IERC20Expanded(token).transfer(to, value);
    }

    function _claimReferralBonus(uint256 tokenId, uint256[] calldata referralBonusIds) internal returns (uint256) {
        // FIX storage vs memory
        uint256 totalReward = 0;
        for (uint256 i = 0; i < referralBonusIds.length; i++) {
            uint256 referralBonusId = referralBonusIds[i];
            uint256 claimableReward = calculateClaimableReferralBonus(tokenId, referralBonusId);
            if (claimableReward > 0) {
                referralRewards[tokenId][referralBonusId].lastClaimedAt = block.timestamp;
                referralRewards[tokenId][referralBonusId].rewardClaimed += claimableReward;
                totalReward += claimableReward;
                emit ReferralBonusClaimed(tokenId, referralBonusId, claimableReward);
            }
        }
        return totalReward;
    }

    function calculateClaimableReferralBonus(uint256 tokenId, uint256 referralBonusId) private view returns (uint256) {
        ReferralReward storage reward = referralRewards[tokenId][referralBonusId];
        if (reward.rewardClaimed == reward.referralBonusReceivable) {
            return 0;
        }
        uint256 totalReward = 0;
        uint256 tierActivationLogArrayLength = tierActivationLogs[tokenId][reward.referralLevel].length;
        for (uint256 i = 0; i < tierActivationLogArrayLength; i++) {
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
            uint256 rewardCollectible = (reward.referralBonusReceivable * applicableDuration) / (reward.maturity - reward.startTime);
            if (rewardCollectible + reward.rewardClaimed > reward.referralBonusReceivable) {
                rewardCollectible = reward.referralBonusReceivable - reward.rewardClaimed;
            }
            totalReward += rewardCollectible;
        }
        return totalReward;
    }

    function handleMembershipTierUpdate(uint256 tokenId, Profile storage profile, uint256 newMembershipTierIndex, uint256 newDepositSum) internal {
        uint256 oldMembershipTierIndex = profile.membershipTier;
        profile.membershipTier = newMembershipTierIndex;
        profile.depositSum = newDepositSum;
        emit MembershipTierChanged(tokenId, newMembershipTierIndex);

        if (oldMembershipTierIndex == newMembershipTierIndex) {
            return;
        }

        bool isUpgrade;
        uint256 startTier;
        uint256 endTier;
        if (newMembershipTierIndex > oldMembershipTierIndex) {
            isUpgrade = true;
            startTier = oldMembershipTierIndex + 1;
            endTier = newMembershipTierIndex;
        } else {
            isUpgrade = false;
            startTier = newMembershipTierIndex + 1;
            endTier = oldMembershipTierIndex;
        }
        for (uint256 tier = startTier; tier <= endTier; tier++) {
            uint256 lowerBound = membershipTiers[tier].referralBonusCollectibleLevelLowerBound;
            uint256 upperBound = membershipTiers[tier].referralBonusCollectibleLevelUpperBound;
            for (uint256 referralLevel = lowerBound; referralLevel <= upperBound; referralLevel++) {
                if (isUpgrade) {
                    tierActivationLogs[tokenId][referralLevel].push(TierActivationLog({start: block.timestamp, end: 0}));
                    uint256 logIndex = tierActivationLogs[tokenId][referralLevel].length - 1;
                    emit ReferralBonusLevelCollectionActivated(tokenId, referralLevel, logIndex, block.timestamp);
                } else {
                    uint256 logIndex = tierActivationLogs[tokenId][referralLevel].length - 1;
                    tierActivationLogs[tokenId][referralLevel][logIndex].end = block.timestamp;
                    emit ReferralBonusLevelCollectionDeactivated(tokenId, referralLevel, logIndex, block.timestamp);
                }
            }
        }
    }

    function _collectInterests(uint256 tokenId, uint256[] calldata depositIds) internal returns (uint256) {
        address receiver = myDanPass.ownerOf(tokenId);
        uint256 totalInterest = 0;
        for (uint256 i = 0; i < depositIds.length; i++) {
            Deposit memory deposit = deposits[tokenId][depositIds[i]];
            uint256 interestCollectable = _calculateInterests(tokenId, depositIds[i]);
            deposits[tokenId][depositIds[i]].interestCollected = deposit.interestCollected + interestCollectable;
            deposits[tokenId][depositIds[i]].lastClaimedAt = block.timestamp;
            emit InterestClaimed(tokenId, depositIds[i], interestCollectable);
            totalInterest += interestCollectable;
        }
        sendToken(targetToken, receiver, totalInterest);
        return totalInterest;
    }

    function _calculateInterests(uint256 tokenId, uint256 depositId) internal view returns (uint256) {
        Deposit memory deposit = deposits[tokenId][depositId];
        if (deposit.interestCollected == deposit.interestReceivable || deposit.principal == 0) {
            return 0;
        }
        uint256 durationPassed = block.timestamp - max(deposit.lastClaimedAt, deposit.startTime);
        // TODO: check dust precision
        uint256 interestCollectible = (deposit.interestReceivable * durationPassed) / (deposit.maturity - deposit.startTime);
        if (interestCollectible + deposit.interestCollected > deposit.interestReceivable) {
            interestCollectible = deposit.interestReceivable - deposit.interestCollected;
        }
        return interestCollectible;
    }

    function isValidDepositDuration(uint256 duration) public view returns (bool) {
        for (uint256 i = 0; i < depositDurations.length; i++) {
            if (duration == depositDurations[i]) {
                return true;
            }
        }
        return false;
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
        emit DepositCreated(tokenId, depositId, amount, duration, interestRate, interestReceivable);
        return depositId;
    }

    function createReferralBonusObjects(uint256 tokenId, uint256 referrerTokenId, uint256 depositId, uint256 depositedPrincipal, uint256 duration) internal {
        if (tokenId == genesisTokenId) {
            // do not create referral bonus objects for genesis token
            return;
        }
        for (uint256 referralLevel = 1; referralLevel < referralBonusRates.length; referralLevel++) {
            // TODO: precision
            uint256 referralBonusReceivable = ((depositedPrincipal * referralBonusRates[referralLevel]) * duration) / 10000 / 365 days;
            if (referralBonusReceivable == 0) {
                continue;
            }
            uint256 referralBonusId = nextReferralRewardId;
            nextReferralRewardId += 1;
            referralRewards[referrerTokenId][referralBonusId] = ReferralReward({
                referralLevel: referralLevel,
                startTime: block.timestamp,
                maturity: block.timestamp + duration,
                referralBonusReceivable: referralBonusReceivable,
                rewardClaimed: 0,
                lastClaimedAt: 0,
                depositId: depositId
            });
            // next iteration

            emit ReferralRewardCreated(referrerTokenId, referralBonusId, referralLevel);
            uint256 nextReferrerTokenId = profiles[referrerTokenId].referrerTokenId;

            if (nextReferrerTokenId == referrerTokenId) {
                // no more referrer
                break;
            }
            referrerTokenId = nextReferrerTokenId;
        }
    }

    function getMembershipTierInterestByDeposit(uint256 depositSum) internal view returns (uint256 index, uint256 interestRate) {
        for (uint256 i = 0; i < membershipTiers.length; i++) {
            if (depositSum >= membershipTiers[i].lowerThreshold && depositSum < membershipTiers[i].upperThreshold) {
                return (i, membershipTiers[i].interestRate);
            }
        }
        revert InvalidArgument(depositSum, "No membership tier found");
    }
}
