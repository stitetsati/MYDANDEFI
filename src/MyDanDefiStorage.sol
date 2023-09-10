pragma solidity ^0.8.10;
import "./MyDanPass.sol";

interface IMyDanDefi {
    event AssetsUnderManagementCapSet(uint256 newCap);
    event MembershipUpdated(uint256 index, MembershipTier updatedMembershipTier);
    event MembershipInserted(uint256 index, MembershipTier insertedMembershipTier);
    event DurationBonusRateUpdated(uint256 duration, uint256 newRate);
    event PassMinted(address minter, uint256 mintedTokenId, uint256 referrerTokenId);
    event ReferralCodeCreated(string referralCode, uint256 tokenId);
    event ReferralRewardCreated(uint256 referrerTokenId, uint256 rewardId, uint256 referralLevel);
    event DepositCreated(uint256 tokenId, uint256 depositId, uint256 amount, uint256 duration, uint256 interestRate, uint256 interestReceivable);
    event MembershipTierChanged(uint256 tokenId, uint256 membershipTierIndex);
    event InterestClaimed(uint256 tokenId, uint256 depositId, uint256 interestCollectible);

    event ReferralBonusClaimed(uint256 tokenId, uint256 rewardId, uint256 rewardCollectible);
    event ReferralBonusLevelCollectionActivated(uint256 tokenId, uint256 referralLevel, uint256 logIndex, uint256 timestamp);
    event ReferralBonusLevelCollectionDeactivated(uint256 tokenId, uint256 referralLevel, uint256 logIndex, uint256 timestamp);
    struct MembershipTier {
        string name;
        uint256 lowerThreshold;
        uint256 upperThreshold;
        uint256 interestRate;
        uint256 referralBonusCollectibleLevelLowerBound;
        uint256 referralBonusCollectibleLevelUpperBound;
    }
    struct Deposit {
        uint256 principal;
        uint256 startTime;
        uint256 maturity;
        uint256 interestRate;
        uint256 interestReceivable;
        uint256 interestCollected;
        uint256 lastClaimedAt;
    }
    struct ReferralReward {
        uint256 referralLevel;
        uint256 startTime;
        uint256 maturity;
        uint256 rewardReceivable;
        uint256 rewardClaimed;
        uint256 lastClaimedAt;
        uint256 depositId;
    }
    struct Profile {
        uint256 referrerTokenId;
        string referralCode;
        uint256 depositSum;
        uint256 membershipTier;
        bool isInitialised;
    }
    struct TierActivationLog {
        uint256 start;
        uint256 end;
    }
    struct MembershipTierChange {
        uint256 oldTier;
        uint256 newTier;
    }

    function setAssetsUnderManagementCap(uint256 cap) external;

    function editMembershipTier(uint256 index, MembershipTier calldata updatedMembershipTier) external;

    function setDurations(uint256[] calldata durations, uint256[] calldata bonusRates) external;

    function insertMembershipTiers(MembershipTier[] calldata newMembershipTiers) external;

    function setReferralBonusRewardRates(uint256[] calldata rates) external;

    function claimPass(string memory referralCode) external returns (uint256);

    function setReferralCode(string memory referralCode, uint256 tokenId) external;

    function claimInterests(uint256 tokenId, uint256[] calldata depositIds) external returns (uint256);

    function deposit(uint256 tokenId, uint256 amount, uint256 duration) external;
    // function withdraw(uint256 tokenId, uint256[] memory depositIds) external;
    // function claimReferralBonus(uint256 tokenId, uint256[] memory bonusIds) external;
}

abstract contract MyDanDefiStorage is IMyDanDefi {
    address public targetToken;
    uint256 public assetsUnderManagementCap;
    uint256 public currentAUM;
    uint256 public nextDepositId;
    uint256 public nextReferralRewardId;
    MyDanPass public myDanPass;
    uint256[] public referralBonusRewardRates;
    MembershipTier[] public membershipTiers;
    uint256[] public depositDurations;
    mapping(uint256 => uint256) public durationBonusRates;
    mapping(string => uint256) public referralCodes;
    mapping(uint256 => Profile) public profiles;
    // tokenId -> depositId -> Deposit
    mapping(uint256 => mapping(uint256 => Deposit)) public deposits;
    // tokenId -> referralRewardId -> ReferralReward
    mapping(uint256 => mapping(uint256 => ReferralReward)) public referralRewards;
    // tokenId -> depositId[]
    mapping(uint256 => uint256[]) public depositList;
    // tokenId -> referralLevel -> referralRewardId[]
    mapping(uint256 => mapping(uint256 => TierActivationLog[])) public tierActivationLogs;
}
