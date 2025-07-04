require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ignition-ethers");

require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {

    },
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    rootstockTestnet: {
      url: "https://public-node.testnet.rsk.co",
      chainId: 31,
      accounts: [process.env.PRIVATE_KEY] // Add your private key
    }
  }
};