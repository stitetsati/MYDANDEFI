import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { save, deploy } = deployments;
  const { deployer, usdt } = await getNamedAccounts();
  const myDanPass = await deploy(`MyDanPass`, {
    from: deployer,
    log: true,
    contract: "MyDanPass",
  });
  await save(`MyDanPass`, {
    abi: myDanPass.abi,
    address: myDanPass.address,
  });
  const myDanPassAddress = (await deployments.get("MyDanPass")).address;
  const myDanDefiAddress = (await deployments.get("MyDanDefi")).address;

  const myDanDefiFactory = await ethers.getContractFactory("MyDanDefi");
  const myDanDefiFactoryInitFunction = myDanDefiFactory.interface.getFunction("initialize");
  const myDanDefiInitData = myDanDefiFactory.interface.encodeFunctionData(myDanDefiFactoryInitFunction, [usdt, myDanPassAddress]);
  const myDanDefiProxyAddress = (await deployments.get("MyDanDefiProxy")).address;

  await hre.run("verify:verify", {
    address: myDanPassAddress,
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: myDanDefiAddress,
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: myDanDefiProxyAddress,
    constructorArguments: [myDanDefiAddress, myDanDefiInitData],
    contract:"src/MyDanDefiProxy.sol:MyDanDefiProxy"
  });
};
export default func;
func.tags = ["verify"];
