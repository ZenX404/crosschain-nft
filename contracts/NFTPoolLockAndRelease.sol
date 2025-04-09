// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {MyToken} from "./MyToken.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

// 源链的 NFTPool（NFT池） LockAndRelease用于锁定NFT和解锁NFT
/// @title - A simple messenger contract for sending/receiving string data across chains.
contract NFTPoolLockAndRelease is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes text, // The text being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    // Event emitted when a message is received from another chain.
    event TokenUnLocked(
        uint256 tokenId,
        address newOwner 
    );

    bytes32 private s_lastReceivedMessageId; // Store the last received messageId.
    string private s_lastReceivedText; // Store the last received text.



    IERC20 private s_linkToken;
    // 源NFT
    MyToken public nft;

    struct RequestData {
        uint256 tokenId;
        address newOwner;
    }
 

    /// @notice Constructor initializes the contract with the router address.   
    /// @param _router The address of the router contract. 路由合约地址   这个是chainlink提供商部署的合约地址
    /// @param _link The address of the link contract. 链接合约地址  这个是chainlink提供商部署的合约地址
    constructor(address _router, address _link, address nftAddr) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        // 创建源NFT合约对象
        nft = MyToken(nftAddr);
    }

  



    /// @dev Modifier that checks the receiver address is not 0.
    /// @param _receiver The receiver address.
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    // 锁定NFT，并发送给目标链
    function lockAndSendNFT(
        uint256 tokenId, // 要锁定的NFT的tokenId
        address newOwner, // 包装NFT的对应在源NFT的所属人地址
        uint64 chainSelector, // 目标链的chainSelector，也就是目标链的chainId
        address receiver // 目标链的receiver，也就是目标链的合约地址
        ) public returns (bytes32){
        
            // transfer NFT to this address to lock the NFT
            // 需要先将源链上的NFT转移到当前这个NFTPoolLockAndRelease合约的地址上，来将NFT锁定
            // 要将msg.sender持有人所持有的tokenId这个NFT转移到address(this)当前NFTPoolLockAndRelease合约的地址上
            // 经过这一步，我们就可以认为该NFT已经被锁定在池子里了
            // 这里调用nft.transferFrom函数，调用地址是当前这个NFTPoolLockAndRelease合约的地址，也就是address(this)
            // 所以如果有一个地址调用了当前这个lockAndSendNFT函数，然后这个函数中又调用了nft.transferFrom函数，最终实际调用nft.transferFrom函数的是NFTPoolLockAndRelease合约的地址，而不是最初调用lockAndSendNFT函数的地址，这一点一定要想清楚
            // 所以如果想要转移nft，需要先调用nft.approve函数，将nft的转移权限授予当前这个NFTPoolLockAndRelease合约的地址
            nft.transferFrom(msg.sender, address(this), tokenId);

            // construct data to be sent
            // 要开始发送跨链信息了
            // 信息需要转换为bytes格式，更方便传输。我发送要跨链的tokenId以及包装token的所有人地址
            bytes memory payload = abi.encode(tokenId, newOwner);
            bytes32 messageId = sendMessagePayLINK(chainSelector, receiver, payload);
            return messageId;
                
    }



    /// @notice Sends data to receiver on the destination chain.
    /// @notice Pay for fees in LINK.
    /// @dev Assumes your contract has sufficient LINK.
    /// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param _receiver The address of the recipient on the destination blockchain.
    /// @param _text The text to be sent.
    /// @return messageId The ID of the CCIP message that was sent.
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _text
    )
        internal
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            address(s_linkToken)
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(router), fees);

        // Send the CCIP message through the router and store the returned CCIP message ID
        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _text,
            address(s_linkToken),
            fees
        );

        // Return the CCIP message ID
        return messageId;
    }


    // 处理从目的链发送过来的信息
    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
    {
        // 要接受两个信息  address newOwner, uint256 tokenId
        // 解析收到的数据，解码为RequestData结构体
        RequestData memory rd = abi.decode(any2EvmMessage.data, (RequestData));
        uint256 tokenId = rd.tokenId;
        address newOwner = rd.newOwner;
        

       // transfer token from this address to new owner
       // unlock the nft
       // 将当前token池中的token转移回源链，就相当于解锁操作
       nft.transferFrom(address(this), newOwner, tokenId);
       // 发送解锁事件
       emit TokenUnLocked(tokenId, newOwner);

    }

    // 构建CCIP消息
    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for sending a text.
    /// @param _receiver The address of the receiver.
    /// @param _data The string data to be sent.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _data,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: abi.encode(_data), // ABI-encoded string
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array as no tokens are transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit and allowing out-of-order execution.
                    // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                    // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                    // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/best-practices#using-extraargs
                    Client.EVMExtraArgsV2({
                        gasLimit: 200_000, // Gas limit for the callback on the destination chain
                        allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                    })
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: _feeTokenAddress
            });
    }

    /// @notice Fetches the details of the last received message.
    /// @return messageId The ID of the last received message.
    /// @return text The last received text.
    function getLastReceivedMessageDetails()
        external
        view
        returns (bytes32 messageId, string memory text)
    {
        return (s_lastReceivedMessageId, s_lastReceivedText);
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

    /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
    /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
    /// It should only be callable by the owner of the contract.
    /// @param _beneficiary The address to which the Ether should be sent.
    function withdraw(address _beneficiary) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        (bool sent, ) = _beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    /// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
    /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
    /// @param _beneficiary The address to which the tokens will be sent.
    /// @param _token The contract address of the ERC20 token to be withdrawn.
    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }
}
