// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyDanDefi.sol";
import "../src/MyDanDefiProxy.sol";
import "../src/MyDanDefiStorage.sol";

import "../src/MyDanPass.sol";
import "./mocks/MockERC20.sol";

contract MyDanDefiTestSetup is Test {
    using LowerCaseConverter for string;
    using Strings for uint256;
    MyDanDefi myDanDefi;
    MyDanPass myDanPass;
    address deadAddress = 0x000000000000000000000000000000000000dEaD;
    MockERC20 mockERC20 = new MockERC20();
    uint256 oneDollar = 10 ** mockERC20.decimals();
    uint256 referralBonusMaxLevel;

    constructor() {
        MyDanDefi myDanDefiImpl = new MyDanDefi();
        MyDanDefiProxy myDanDefiProxy = new MyDanDefiProxy(address(myDanDefiImpl), abi.encodeWithSelector(myDanDefiImpl.initialize.selector, address(mockERC20)));
        myDanDefi = MyDanDefi(address(myDanDefiProxy));
        myDanPass = myDanDefi.myDanPass();
    }

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

    function setReferralBonusRates() internal {
        uint256 length = 8;
        uint256[] memory rates = new uint256[](length);
        rates[0] = 0;
        rates[1] = 600;
        rates[2] = 200;
        rates[3] = 200;
        rates[4] = 100;
        rates[5] = 100;
        rates[6] = 100;
        rates[7] = 100;
        myDanDefi.setReferralBonusRates(rates);
        referralBonusMaxLevel = length;
    }

    modifier Setup() {
        MyDanDefi myDanDefiImpl = new MyDanDefi();
        MyDanDefiProxy myDanDefiProxy = new MyDanDefiProxy(address(myDanDefiImpl), abi.encodeWithSelector(myDanDefiImpl.initialize.selector, address(mockERC20)));
        myDanDefi = MyDanDefi(address(myDanDefiProxy));
        myDanPass = myDanDefi.myDanPass();
        myDanDefi.setAssetsUnderManagementCap(100 ether);
        setDurations();
        setMembershipTiers();
        setReferralBonusRates();
        _;
    }
}
