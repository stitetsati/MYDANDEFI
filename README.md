# MYDANDEFI

## Deployment
```bash
npx hardhat deploy --tags pass,main,setup --network goerli
```
## Requirements

### Smart Contract:

All costs associated with deploying smart contracts to the blockchain shall be paid for by the project owner.

It is the project owner's responsibility to maintain the USDT balance in the smart contract at a certain level so that users can withdraw upon their term deposit's maturity.

1. **Admin Functions**:
    
    a. `Setup(string[3] tierNames, uint256[3] interestRates, uint256[6] durations, uint256[] referralRewards,uint256 aumCap)`
      - Each tier (Sapphire, Emerald, Imperial) has its default interest rate, regardless of the deposit duration.
      - Duration options are: 3m, 6m, 9m, 1y, 2y, 3y.
      - Referral reward rates for level 1 - 7 referrals are to be configured.
      - AUM cap is to be configured; the system AUM will be capped at this amount.
    
    b. `Withdraw(tokenAddress, amount)`
      - Allows the admin to withdraw a specified amount of tokens from the contract.

2. **User Functions**:

    a. `ClaimPass(referralCode)`
      - Allows a user to claim an NFT, serving as a pass for depositing into MyBank.
      - An internal storage will record the referrer associated with this newly minted pass.
    
    b. `CreateReferralCode(tokenId, referralCode)`
      - Allows a user to create a referralCode associated with the NFT they own.
      - 1 NFT can only be associated with 1 referralCode. The referral code must be universally unique.
    
    c. `Deposit(tokenId, duration, amount)`
      - Allows an NFT holder to set up a term deposit of a specified duration.
      - If the deposit leads to a tier upgrade, it should trigger referral bonus accumulation from eligible deposits (e.g., a Sapphire to Emerald upgrade).
    
    d. `ClaimReferralBonus(tokenId, rewardIds[])`
      - Allows an NFT holder to claim the referral bonus accumulated up to the current timestamp.
      - The front end will query the subgraph API to get metadata of any referral bonus associated with an NFT. It will then pass an array of bonusIds to the smart contract for claiming.
    
    e. `ClaimRewards(tokenId, depositIds[])`
      - Allows an NFT holder to claim the deposit rewards accumulated up to the current timestamp.
      - The front end will query the subgraph API to get term deposit metadata associated with an NFT. It will then pass an array of deposit ids to the smart contract for claiming.
    
    f. `Withdraw(tokenId, depositIds[])`
      - Allows an NFT holder to withdraw multiple matured term deposits.
      - If the withdrawal results in a tier downgrade, it should collect all accumulated rewards from the deposits that are no longer in the collectable range.

3. **Referral Hierarchy Mechanism**:
    In the MYDANDEFI system, each user is assigned a tier based on their deposit amount. Alongside this, a unique referral mechanism is integrated:

    a. **Personal Referral Code**:
    Every user, upon interacting with the smart contract's createReferralCode function, generates a unique personal referral code. They can share this code with others to invite them to use MYDANDEFI.

    b. **Referral Levels**:
    When a new user joins using an existing user's referral code, they become a "Level 1" referral for that user.

    c. **Extended Referral System**:
    - If User A joins using your referral code, they become your Level 1 referral.
    - If User A invites User B with their referral code, User B becomes User A's Level 1 referral and your Level 2 referral.

    d. **Example**:  
    Imagine you invite Alice using your referral code. Alice is your Level 1 referral. If Alice then invites Bob, Bob is Alice's Level 1 referral and your Level 2 referral.

4. **Other Specifications**:

    a. **Tiers**:  
        * Tier Sapphire: USDT 100 <= total deposit < USDT 1,000  
        * Tier Emerald: USDT 1,000 <= total deposit < USDT 10,000  
        * Tier Imperial: USDT 10,000 <= total deposit  
    b. **Collectable Rewards from Referrals**:  
        * Tier Sapphire: Collect from deposits made by levels 1 - 3 referrals  
        * Tier Emerald: Collect from deposits made by levels 1 - 5 referrals  
        * Tier Imperial: Collect from deposits made by levels 1 - 7 referrals    
    c. **Interests from Deposits (configurable)**:  
        * Tier Sapphire: 7 %  
        * Tier Emerald: 7.5 %  
        * Tier Imperial: 8 %    
    d. **Rewards from Referral Deposits (configurable)**:  
        * Level 1: 6 %  
        * Level 2: 2 %  
        * Level 3: 2 %  
        * Level 4: 1 %  
        * Level 5: 1 %  
        * Level 6: 1 %  
        * Level 7: 1 %  
    e. **Interest and Rewards Calculation**:  
    All interests and rewards are calculated at the deposit time. For example, when a level 1 referral deposits USDT 100 for 6 months, the system calculates the total collectable rewards as: 100 * 6% * 6 / 12 = $3. This amount is vested over the 6-month period. Admin changes to the configurable interest or reward rates WILL NOT affect any existing vesting rewards or interest-accruing term deposits.

5. **Withdrawal Bot**:  

    a. **Smart Contract**: 

    * Add a user function WithdrawOnBehalf(tokenIds[], depositIds[]) so that anyone can send a transaction to withdraw the EXPIRED deposits from the protocol on behalf of anyone  

    * Add an admin function EnableAutoWithdrawOnMaturity(boolean) so that the admin can enable/disable the bot  

    b. **Subgraph**:  

    * Within the entity definition, add expiry to the deposit object and allow Subgraph API calls to get the expired deposits directly with GraphQL queries.  


    c. **Bots**:  

    * Read from the protocol smart contract to enable/disable functions  

    * Develop a bot that queries the subgraph, once matured deposits are identified, send a transaction and call WithdrawOnBehalf. Save event logs in Postgres and send to Telegram  

    * Develop a monitor bot to check if the withdrawal bot is running and that there is no unexpected downtime. Integrate with PagerDuty (downtime notification), Sentry(logging production errors)  

    c. **Estimate**:  

    * 2 Heroku Nodes: $25 * 2 = $50/month
    * PostgreSQL $50/month
    * Sentry: $29/month
    * PagerDuty: $21/month
    * Total: $150/month



