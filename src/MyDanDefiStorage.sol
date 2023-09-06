pragma solidity ^0.8.10;
import "./MyDanPass.sol";

interface IMyDanDefi {
    struct MembershipTier {
        string name;
        uint256 lowerThreshold;
        uint256 upperThreshold;
        uint256 interestRate;
    }
    struct Profile {
        uint256 referrerTokenId;
    }

    event AssetsUnderManagementCapSet(uint256 newCap);
    event MembershipUpdated(uint256 index, MembershipTier updatedMembershipTier);
    event MembershipInserted(uint256 index, MembershipTier insertedMembershipTier);
    event DurationBonusRateUpdated(uint256 duration, uint256 newRate);
    event PassMinted(address minter, uint256 mintedTokenId, uint256 referrerTokenId);

    function setAssetsUnderManagementCap(uint256 cap) external;

    function editMembershipTier(uint256 index, MembershipTier calldata updatedMembershipTier) external;

    function setDurations(uint256[] calldata durations, uint256[] calldata bonusRates) external;

    function insertMembershipTiers(MembershipTier[] calldata newMembershipTiers) external;

    function setReferralBonusRewardRates(uint256[] calldata rates) external;

    function claimPass(string memory referralCode) external returns (uint256);

    // function setReferralCode(string memory referralCode, uint256 tokenId) external;

    // function deposit(uint256 tokenId, uint256 amount, uint256 duration) external;

    // function withdraw(uint256 tokenId, uint256[] memory depositIds) external;

    // function claimRewards(uint256 tokenId, uint256[] memory depositIds) external;

    // function claimReferralBonus(uint256 tokenId, uint256[] memory bonusIds) external;
}

abstract contract MyDanDefiStorage is IMyDanDefi {
    uint256 public assetsUnderManagementCap;
    MyDanPass public myDanPass;
    uint256[] public referralBonusRewardRates;
    MembershipTier[] public membershipTiers;
    mapping(uint256 => uint256) public durationBonusRates;
    mapping(string => uint256) public referralCodes;
    mapping(uint256 => Profile) public profiles;
}
