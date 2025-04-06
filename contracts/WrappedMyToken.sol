// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {MyToken} from "./MyToken.sol";

// MyToken的包装合约
contract WrappedMyToken is MyToken {
    constructor(string memory tokenName, string memory tokenSymbol)
        // 这里要为父合约的构造函数传入这两个参数
        MyToken(tokenName, tokenSymbol)
    {}

    // 这里只是专注于教学，所以没有添加任何的权限控制。但是真正开发跨链应用的时候，需要非常注意权限控制，不然可能会造成巨大财产损失
    // 铸造NFT，将MyToken的NFT铸造到WrappedMyToken中，传入MyToken的tokenId，to是铸造给哪个地址
    function mintTokenWithSpecificTokenId(address to, uint256 tokenId) public {
        // 这里我们调用父合约的safeMint函数(这是因为继承了ERC721)，铸造一个NFT
        // 入参：to 要将这个NFT铸造给哪个地址
        _safeMint(to, tokenId);
    }
}
