/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

// const PRIVATE_KEY = process.env.PRIVATE_KEY || "0xkey";
const PRIVATE_KEY2 = process.env.PRIVATE_KEY2 || "0xkey";

module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      // this is actually mainnet
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.alchemyApiKey}`,
      from: "0x1B23c1D7Ad49C9c3bdCAA4d7696496C87cc777b7",
      accounts: [PRIVATE_KEY2],
    },
    actuallysepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.alchemyApiKey}`,
      accounts: [PRIVATE_KEY2],
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.etherscanApiKey,
  },
};
