pragma solidity ^0.8.10;
import "./MyDanDefiStorage.sol";
import "./utils/LowerCaseConverter.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract MyDanDefi is Ownable, MyDanDefiStorage {
    string public constant genesisReferralCode = "mydandefi";
    uint256 public constant genesisTokenId = 0;
    using LowerCaseConverter for string;

    constructor() {
        // set minter to address(this) and transfer ownership to deployer
        myDanPass = new MyDanPass(address(this));
        myDanPass.transferOwnership(msg.sender);
        // mint a genesis nft and set up the profile
        uint256 tokenId = myDanPass.mint(msg.sender);
        referralCodes[genesisReferralCode] = tokenId;
        profiles[tokenId] = Profile({referrerTokenId: tokenId});
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
            durationBonusRates[durations[i]] = bonusRates[i];
            emit DurationBonusRateUpdated(durations[i], bonusRates[i]);
        }
    }

    function insertMembershipTiers(MembershipTier[] calldata newMembershipTiers) external onlyOwner {
        for (uint256 i = 0; i < newMembershipTiers.length; i++) {
            membershipTiers.push(newMembershipTiers[i]);
            emit MembershipInserted(membershipTiers.length - 1, newMembershipTiers[i]);
        }
    }

    // Admin functions, referral related
    function setReferralBonusRewardRates(uint256[] calldata rates) external onlyOwner {
        for (uint256 i = 0; i < rates.length; i++) {
            if (rates[i] == 0) {
                revert InvalidArgument(rates[i], "Rate cannot be zero");
            }
        }
        delete referralBonusRewardRates;
        referralBonusRewardRates = rates;
    }

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
        profiles[mintedTokenId] = Profile({referrerTokenId: referrerTokenId});
        emit PassMinted(msg.sender, mintedTokenId, referrerTokenId);
        return mintedTokenId;
    }

    // }
    // function setReferralCode(string memory referralCode, uint256 tokenId) external;
    // function deposit(uint256 tokenId, uint256 amount, uint256 duration) external;
    // function withdraw(uint256 tokenId, uint256[] memory depositIds[]) external;
    // function claimRewards(uint256 tokenId, uint256[] memory depositIds[]) external;
    // function claimReferralBonus(uint256 tokenId, uint256[] memory bonusIds)
}
