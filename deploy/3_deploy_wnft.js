// 使用deployments部署包装NFT合约
module.exports = async({getNamedAccounts, deployments}) => {
    const { firstAccount } = await getNamedAccounts()
    const { deploy, log } = deployments

    log("deploying wrapped NFT on destination chain")
    await deploy("WrappedMyToken", {
        contract: "WrappedMyToken",
        from: firstAccount,
        log: true,
        args: ["WrappedMyToken", "WMT"]
    })
    log("deployed wrapped nft")
}

module.exports.tags = ["destchain", "all"]