require("@nomicfoundation/hardhat-toolbox");

// 如果想在项目中使用引入的hardhat插件，就需要在hardhat.config.js中声明引入
// 引入hardhat-ethers插件
require("@nomicfoundation/hardhat-ethers");
// 引入hardhat-deploy插件
require("hardhat-deploy");
// 引入hardhat-deploy-ethers插件
require("hardhat-deploy-ethers");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  namedAccounts: {
    firstAccount: {
      default: 0 // 当部署在本地网络时，会默认使用hardhat准备的第0个地址
    }
  }
};
