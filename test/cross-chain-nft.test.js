const { getNamedAccounts, deployments, ethers } = require("hardhat");
const { expect } = require("chai");

// 需要在before外面生命，因为还需要再别的代码块中使用这些对象
let firstAccount;
let ccipSimulator;
let nft;
let nftPoolLockAndRelease;
let wnft;
let nftPoolBurnAndMint;
let chainSelector;

before(async function() {
    // prepare variables: contract, account
    // getNamedAccounts()返回的是一组地址，所以我们要取第一个
    firstAccount = (await getNamedAccounts()).firstAccount;
    // 将所有tag为all的脚本都执行一下，因为我们要在本地测试，所以要部署我们需要的所有合约（执行deploy中我们自己写的5个脚本）
    await deployments.fixture(["all"]);

    // 部署完所有合约之后，我们就要获取到每一个合约对象
    // 通过传入合约名字以及指定与合约交互的账户地址来获取合约对象
    /**
     * 传入的第二个参数 firstAccount 通常用于指定与合约交互的默认账户地址。具体来说，firstAccount 的作用是：
     * 充当交易发送者，当你调用合约的函数时，firstAccount 会被用作交易的发送者地址。这意味着合约的任何状态更改（例如，代币转移、合约状态更新等）都会由这个账户发起。
     * 在测试环境中，firstAccount 通常是由测试框架（如 Hardhat 或 Truffle）自动提供的一个账户（我们这里也是使用hardhat提供的本地网络测试账户），确保你可以顺利地进行合约交互和测试。
     */
    ccipSimulator = await ethers.getContract("CCIPLocalSimulator", firstAccount);
    nft = await ethers.getContract("MyToken", firstAccount);
    nftPoolLockAndRelease = await ethers.getContract("NFTPoolLockAndRelease", firstAccount);
    wnft = await ethers.getContract("WrappedMyToken", firstAccount);
    nftPoolBurnAndMint = await ethers.getContract("NFTPoolBurnAndMint", firstAccount);
    // 获取目标链地址
    chainSelector = (await ccipSimulator.configuration()).chainSelector_;
});

// 按照NFT跨链流程来进行测试，把每一个步骤都测试到

describe("source chain -> dest chain tests", async function() {
    it("test if user can mint a nft from ngt contract successfully",
        async function() {
            // 调用ERC721合约提供的safeMint函数，给firstAccount地址铸造一个nft
            // 铸造的第一个NFT的tokenid为0
            await nft.safeMint(firstAccount);
            // 获取tokenid为0的nft的owner地址
            const owner = await nft.ownerOf(0);
            // 断言owner是否为firstAccount，是则说明铸造成功，通过测试
            expect(owner).to.equal(firstAccount);
        }
    );

    it("test if user can lock the nft in the pool and send ccip message on source chain",
        async function() {
            // 因为后面调用NFTPoolLockAndRelease的lockAndSendNFT函数，该函数中会有一步操作来转移nft
            // 而调用nft.transferFrom函数的地址是NFTPoolLockAndRelease合约的地址
            // 所以需要先调用nft.approve函数，将nft的转移权限授予NFTPoolLockAndRelease合约的地址
            // 将tokenid为0的nft的转移权限授予NFTPoolLockAndRelease合约的地址
            await nft.approve(nftPoolLockAndRelease.target, 0);
            
            // 使用chainlink提供的ccip服务需要支付费用，支付的代币为link
            // 我们引入ccipLocalSimulator合约，就是用来在本地网络中模拟支付link
            // 所以需要先调用ccipSimulator.requestLinkFromFaucet函数，这个函数中会有水龙头为测试账户提供link
            // 这里我们为nftPoolLockAndRelease合约模拟打入了10个link，绝对是足够支付使用ccip服务的费用了
            await ccipSimulator.requestLinkFromFaucet(nftPoolLockAndRelease, ethers.parseEther("100"));
            
            await nftPoolLockAndRelease.lockAndSendNFT(
                // 指定要转移的nft的tokenid
                0,
                // 指定要转移的nft的owner地址  也就是会把转移到目的链中的包装nft与源链的地址firstAccount进行绑定，明确包装nft的跨链所属权
                firstAccount,
                // 目标链id
                chainSelector,
                // 目标链的nftPoolBurnAndMint合约地址  锁定了源链中的nft后，就要在目标链nftPoolBurnAndMint合约中铸造对应的包装NFT，进而完成NFT跨链
                nftPoolBurnAndMint.target
            );
            console.log("aaa");
            // 判断nft是否完成了锁定并向ccip发送了消息
            // 获取源链中该nft的owner地址
            const newOwner = await nft.ownerOf(0);
            // 断言nft的owner地址是否为nftPoolLockAndRelease合约的地址,如果相等，说明nft已经被锁定在nftPoolLockAndRelease合约中了。nft已经完成锁定也就说明已经向ccip发送消息了
            expect(newOwner).to.equal(nftPoolLockAndRelease);
        
        }
    );

    it("test if user can get a wrapped nft in dest chain", 
        async function() {
            // 如果前面在锁定源NFT时向ccip发送消息成功的话，那么在目的链中应该会自动铸造一个包装nft
            // 所以我们这里获取一下目的链中tokenid为0包装nft的owner地址（合约第一个铸造的NFT的tokenid就是0）
            const owner = await wnft.ownerOf(0);
            // 判断wnft的owner是否和源nft的owner一致，是则说明wnft被成功铸造
            expect(owner).to.equal(firstAccount);
        }
    )
});
