import * as dotenv from "dotenv";
import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-ethers";
import "hardhat-deploy";

dotenv.config();

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: {
      default: 0,
    },
    usdt: {
      mainnet: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
      goerli: "0xfa873c8A5C5F93c6BFac672df089FADc17127b73",
      hardhat: "0xfa873c8A5C5F93c6BFac672df089FADc17127b73",
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      // forking: {
      // url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      // url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      // blockNumber: 28919813, // for stable mainnet fork test
      // },
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.TEST_PRIVATE_KEY}`],
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.MAINNET_PRIVATE_KEY}`],
    },
    ftmTestnet: {
      url: `https://rpc.ankr.com/fantom_testnet`,
      accounts: [`${process.env.TEST_PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      hardhat: "",
      mainnet: `${process.env.ETHERSCAN_API_KEY}`,
      goerli: `${process.env.ETHERSCAN_API_KEY}`,
    },
  },
};

export default config;
