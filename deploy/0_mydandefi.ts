import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { save, deploy } = deployments;
  const { deployer, usdt } = await getNamedAccounts();
  const myDanDefiImpl = await deploy(`MyDanDefi`, {
    from: deployer,
    args: [],
    log: true,
  });
  const myDanDefiFactory = await ethers.getContractFactory("MyDanDefi");
  const myDanDefiFactoryInitFunction = myDanDefiFactory.interface.getFunction("initialize");
  const myDanDefiInitData = myDanDefiFactory.interface.encodeFunctionData(myDanDefiFactoryInitFunction, [usdt]);
  const myDanDefiProxy = await deploy(`MyDanDefiProxy`, {
    from: deployer,
    args: [myDanDefiImpl.address, myDanDefiInitData],
    log: true,
    contract: "MyDanDefiProxy",
  });
  await save(`MyDanDefiProxy`, {
    abi: myDanDefiImpl.abi,
    address: myDanDefiProxy.address,
  });
};
export default func;
func.tags = ["MyDanDefi"];
