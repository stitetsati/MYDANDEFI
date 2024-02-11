import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const myDanDefiProxyAddress = (await deployments.get("MyDanDefiProxy")).address;
  var tx = await execute("MyDanPass", { from: deployer, gasLimit: 1000000 }, "setMinter", myDanDefiProxyAddress);
  console.log(`setMinter ${tx.transactionHash}`);
  // mainnet
  const month = 30 * 24 * 60 * 60;
  const year = 365 * 24 * 60 * 60;
  const durations = [3 * month, 6 * month, 9 * month, 1 * year, 2 * year, 3 * year];
  const bonusRates = [0, 0, 0, 50, 75, 100];
  tx = await execute("MyDanDefiProxy", { from: deployer, gasLimit: 1000000 }, "setDurations", durations, bonusRates);
  console.log(`setDurations ${tx.transactionHash}`);
  const oneDollar = BigInt(10) ** BigInt(18);
  let tiers = [
    ["None", 0, BigInt(100) * oneDollar, 0, 0, 0],
    ["Sapphire", BigInt(100) * oneDollar, BigInt(1000) * oneDollar, 700, 1, 3],
    ["Emerald", BigInt(1000) * oneDollar, BigInt(10000) * oneDollar, 750, 4, 5],
    ["Imperial", BigInt(10000) * oneDollar, "115792089237316195423570985008687907853269984665640564039457584007913129639935", 800, 6, 7],
  ];
  let uri = "ipfs://QmeLyorcnU4jFZ3tGpCsRQ5V85NezzFsJBvQS3hEHcZE5w/";
  tx = await execute("MyDanPass", { from: deployer, gasLimit: 1000000 }, "setBaseURI", uri);
  console.log(`setBaseURI ${tx.transactionHash}`);
  tx = await execute("MyDanDefiProxy", { from: deployer, gasLimit: 1000000 }, "insertMembershipTiers", tiers);
  console.log(`insertMembershipTiers ${tx.transactionHash}`);
  let assetUnderManagementCap = "1000000000000000000000000000";
  tx = await execute("MyDanDefiProxy", { from: deployer, gasLimit: 1000000 }, "setAssetsUnderManagementCap", assetUnderManagementCap);
  console.log(`setAssetsUnderManagementCap ${tx.transactionHash}`);
  let referralBonusRates = [0, 600, 200, 200, 100, 100, 100, 100];
  tx = await execute("MyDanDefiProxy", { from: deployer, gasLimit: 1000000 }, "setReferralBonusRates", referralBonusRates);
  console.log(`setReferralBonusRates ${tx.transactionHash}`);
};
export default func;
func.tags = ["setup"];
func.dependencies = ["main"];
