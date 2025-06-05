import dotenv from "dotenv";
import "@typechain/hardhat";
import "hardhat-abi-exporter";
import "hardhat-gas-reporter";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@openzeppelin/hardhat-upgrades";

import { HardhatUserConfig } from "hardhat/config";
import { NetworkUserConfig } from "hardhat/types";

dotenv.config();

const chainIds = {
  hardhat: 31337,
  ganache: 1337,
  mainnet: 1,
  sepolia: 11155111,
  bera: 80094,
  'bera-bartio': 80084,
  story: 1514,
  'monad-testnet': 10143,
  'tac-spb': 2391
};

// Ensure that we have all the environment variables we need.
const deployerKey: string = process.env.DEPLOYER_KEY || "";
const infuraKey: string = process.env.INFURA_KEY || "";

function createTestnetConfig(network: keyof typeof chainIds): NetworkUserConfig {
  if (!infuraKey) {
    throw new Error("Missing INFURA_KEY");
  }

  let nodeUrl;
  switch (network) {
    case "mainnet":
      nodeUrl = `https://mainnet.infura.io/v3/${infuraKey}`;
      break;
    case "sepolia":
      nodeUrl = `https://sepolia.infura.io/v3/${infuraKey}`;
      break;
    case 'bera':
      nodeUrl = 'https://rpc.berachain.com';
      break;
    case 'bera-bartio':
      nodeUrl = 'https://bartio.rpc.berachain.com';
      break;
    case 'story':
      nodeUrl = 'https://mainnet.storyrpc.io';
      break;
    case 'monad-testnet':
      nodeUrl = 'https://testnet-rpc.monad.xyz';
      break;
    case 'tac-spb':
      nodeUrl = 'https://spb.rpc.tac.build';
      break;      
  }

  return {
    chainId: chainIds[network],
    url: nodeUrl,
    accounts: [`${deployerKey}`],
  };
}

const config: HardhatUserConfig = {
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          // needed for verifying contracts on monand testnet
          // metadata: {
          //   bytecodeHash: "none", // disable ipfs
          //   useLiteralContent: true // store source code in the json file directly
          // },
          // metadata: {
          //   bytecodeHash: "ipfs",
          // },
          // You should disable the optimizer when debugging
          // https://hardhat.org/hardhat-network/#solidity-optimizer-support
          optimizer: {
            enabled: true,
            runs: 100,
            // https://hardhat.org/hardhat-runner/docs/reference/solidity-support#support-for-ir-based-codegen
            // details: {
            //   yulDetails: {
            //     optimizerSteps: "u",
            //   },
            // },
          },
          // viaIR: true
        },
      },
    ],
  },
  // abiExporter: {
  //   flat: true,
  // },
  gasReporter: {
    enabled: false
  },
  mocha: {
    parallel: false,
    timeout: 100000000
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v6",
  },
  sourcify: {
    enabled: false
    // Uncomment the following lines to enable contract verify on monand testnet
    // ref: https://docs.monad.xyz/getting-started/verify-smart-contract/hardhat
    // enabled: true,
    // apiUrl: "https://sourcify-api-monad.blockvision.org",
    // browserUrl: "https://testnet.monadexplorer.com/"
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_KEY || "",
      sepolia: process.env.ETHERSCAN_KEY || "",
      bera: process.env.BERASCAN_KEY  || "",
      'bera-bartio': process.env.BERA_EXPLORER_KEY  || "",
      story: process.env.STORYSCAN_KEY  || "",
      'tac-spb': process.env.TAC_SPB_EXPLORER_KEY  || "",
    },
    customChains: [
      {
        network: "story",
        chainId: 1514,
        urls: {
          apiURL: "https://www.storyscan.io/api",
          browserURL: "https://storyscan.io"
        }
      },
      {
        network: "bera",
        chainId: 80094,
        urls: {
          apiURL: "https://api.berascan.com/api",
          browserURL: "https://berascan.com"
        }
      },
      {
        network: "bera-bartio",
        chainId: 80084,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan/api",
          browserURL: "https://bartio.beratrail.io"
        }
      },
      {
        network: "tac-spb",
        chainId: 2391,
        urls: {
          apiURL: "https://spb.explorer.tac.build/api",
          browserURL: "https://spb.explorer.tac.build"
        }
      }
    ]
  },
};

if (deployerKey) {
  config.networks = {
    mainnet: createTestnetConfig("mainnet"),
    sepolia: createTestnetConfig("sepolia"),
    bera: createTestnetConfig('bera'),
    'bera-bartio': createTestnetConfig('bera-bartio'),
    story: createTestnetConfig('story'),
    'monad-testnet': createTestnetConfig('monad-testnet'),
    'tac-spb': createTestnetConfig('tac-spb'),
  };
}

config.networks = {
  ...config.networks,
  hardhat: {
    chainId: 1337,
    gas: "auto",
    gasPrice: "auto",
    allowUnlimitedContractSize: false,
    // loggingEnabled: true,
  },
};

export default config;
