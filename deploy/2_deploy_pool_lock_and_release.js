// 部署跨链NFT池（NFTPool LockAndRelease）合约
module.exports = async({getNamedAccounts, deployments}) => {
    const {firstAccount} = await getNamedAccounts()
    const {deploy, log} = deployments
    
    log("Deploying the pool lock and release contract")

    // address _router, address _link, address nftAddr
    // 通过合约名称获取该合约的deployment对象  因为在0_deploy_ccip_simulator.js中通过hardhat插件deployments部署了CCIPLocalSimulator合约
    // CCIPLocalSimulator合约就是chainlink的本地模拟器
    const ccipSimulatorDeployment = await deployments.get("CCIPLocalSimulator");
    // 通过ccipSimulatorDeployment获得CCIPLocalSimulator的部署地址，进而通过ethers.getContractAt获得CCIPLocalSimulator的合约实例
    // 要传入合约名称
    const ccipSimulator = await ethers.getContractAt("CCIPLocalSimulator", ccipSimulatorDeployment.address);
    // 通过ccipSimulator合约对象获取CCIPLocalSimulator合约中的ccipConfig成员对象
    // 这个对象中存储了我们需要的_router和_link合约相关的信息
    const ccipConfig = await ccipSimulator.configuration();
    // 获取我们需要的信息address _router和address _link
    const sourceChainRouter = ccipConfig.sourceRouter_;
    const linkTokenAddr = ccipConfig.linkToken_;
    // 通过deployments传入部署的合约名称来获得合约的deployment对象   
    // 这个是在1_deploy_nft.js脚本中通过hardhat插件deployments部署的MyToken合约，所以才可以通过deployments.get获得
    const nftDeployment = await deployments.get("MyToken");
    // 通过nftDeployment获得MyToken合约的部署地址
    const nftAddr = nftDeployment.address;
    
    await deploy("NFTPoolLockAndRelease", {
        contract: "NFTPoolLockAndRelease",
        from: firstAccount,
        log: true,
        args: [sourceChainRouter, linkTokenAddr, nftAddr] // 要传入NFTPoolLockAndRelease构造函数需要的入参
    });

    log("NFTPoolLockAndRelease contract deployed!")
}

module.exports.tags = ["sourcechain", "all"]

