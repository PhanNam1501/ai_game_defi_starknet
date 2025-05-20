require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.0",
      },
      {
        version: "0.6.6",
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }

        },
      },
    ],
  },
  networks: {
    bscTestnet: {
      url: "https://bsc-testnet-rpc.publicnode.com",
      chainId: 97,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      hardfork: "cancun",
    },
    sepolia: {
      url: "https://sepolia.infura.io/v3/" + process.env.INFURA_API_KEY,
      chainId: 11155111,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
};
