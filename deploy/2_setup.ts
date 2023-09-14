import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const myDanDefiProxyAddress = (await deployments.get("MyDanDefiProxy")).address;
  const tx = await execute("MyDanPass", { from: deployer, gasLimit: 1000000 }, "setMinter", myDanDefiProxyAddress);
  console.log(`setMinter ${tx.transactionHash}`);
};
export default func;
func.tags = ["setup"];
