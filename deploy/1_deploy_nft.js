// 部署源NFT合约

// 入参是hardhat的插件，getNamedAccounts用于获取部署账户，deployments用于部署合约
module.exports = async({getNamedAccounts, deployments}) => {
    // 获取部署账户  这个就是在hardhat.config.js中配置的namedAccounts的firstAccount
    const {firstAccount} = await getNamedAccounts()
    // 获取部署合约的实例，并且拿到deploy函数和log函数
    const {deploy, log} = deployments
    

    log("Deploying the nft contract")
    // 部署合约
    await deploy("MyToken", {
        contract: "MyToken", // 合约名称
        from: firstAccount, // 部署账户
        log: true, // 是否打印日志
        args: ["MyNFT", "MNT"] // 合约构造函数要传入的参数
    })
    log("MyToken is deployed!")
}

// 标签，用于标识部署的合约
// 这里将该部署脚本的标签设置为sourcechain，all
// 表示该部署脚本既属于sourcechain，又属于all
module.exports.tags = ["sourcechain", "all"]