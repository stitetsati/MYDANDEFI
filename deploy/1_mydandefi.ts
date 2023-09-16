import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { save, deploy } = deployments;
  const { deployer, usdt } = await getNamedAccounts();
  const myDanDefiImpl = await deploy(`MyDanDefi`, {
    from: deployer,
    args: [],
    log: true,
    contract: "MyDanDefi",
  });
  const myDanDefiFactory = await ethers.getContractFactory("MyDanDefi");
  const myDanDefiFactoryInitFunction = myDanDefiFactory.interface.getFunction("initialize");
  const myDanPassAddress = (await deployments.get("MyDanPass")).address;
  const myDanDefiInitData = myDanDefiFactory.interface.encodeFunctionData(myDanDefiFactoryInitFunction, [usdt, myDanPassAddress]);
  const myDanDefiProxy = await deploy(`MyDanDefiProxy`, {
    from: deployer,
    args: [myDanDefiImpl.address, myDanDefiInitData],
    log: true,
    contract: "MyDanDefiProxy",
  });
  await save(`MyDanDefi`, {
    abi: myDanDefiImpl.abi,
    address: myDanDefiProxy.address,
  });
};
export default func;
func.tags = ["main"];
