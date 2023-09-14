import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { save, deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const myDanPass = await deploy(`MyDanPass`, {
    from: deployer,
    log: true,
    contract: "MyDanPass",
  });
  await save(`MyDanPass`, {
    abi: myDanPass.abi,
    address: myDanPass.address,
  });
};
export default func;
func.tags = ["pass"];
