// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;

    // Metadata
    // 我们会把NFT的Metadata（详细描述、特性、图片等数据）都存在去中心化的存储网络中，比如Ipfs
    // 将图片存储好之后，我们就系写一个符合Metadata标准的json文件，也存储到ipfs上，然后就生成了一个链接
    // https://ipfs.filebase.io/ipfs/QmXw7TEAJwKjKifvLE25Z9yjvowwk2NwY3WgnZPUto9XoA 这个链接就是符合Metadata标准json数据
    // 使用OpenSea查看NFT的时候，会自动去ipfs读取json数据，然后显示出来，所以下面的地址可以不写通过filebase访问ipfs前缀（因为直接使用ipfs存储数据上手比较难，所以有一些提供商会提供方便大家使用ipfs存储数据的服务，比如filebase）
    string constant META_DATA = "ipfs://QmXw7TEAJWKjKifvLE25Z9yjvowWk2NWY3WgnZPUto9XoA";

    constructor(address initialOwner)
        ERC721("MyToken", "MTK")
        Ownable(initialOwner)
    {}

    // 铸造NFT
    // 入参：to 要将这个NFT铸造给哪个地址
    function safeMint(address to)
        public
        onlyOwner
        returns (uint256)
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, META_DATA); // 铸造NFT的时候要传入这个NFT的Metadata
        return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}