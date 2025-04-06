//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 引入chainlink的本地模拟器
// 这个合约是chainlink提供商部署的合约，用于模拟chainlink的本地网络
// 有了它，我们就可以在本地测试跨链应用时，使用chainlink提供的router和link的mock合约，进而完成开发调试
import "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";