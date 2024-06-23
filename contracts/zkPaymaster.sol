// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";

import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";

/// @author 0xAA 0xAA https://x.com/0xAA_Science
/// @notice This smart contract is used in rescue zkSync Airdrop from exploited wallets, by [RescuETH team](https://x.com/OurRescuETH).
/// This Paymaster contract pays the gas fees on behalf of wallets who sends more than 10 tokens to target address (rescueWallet).
contract zkPaymaster is IPaymaster, Ownable {
    address public immutable rescueWallet;
    IERC20 public immutable zkToken;
    bytes4 public transferSelector = bytes4(keccak256("transfer(address,uint256)"));

    modifier onlyBootloader() {
        require(
            msg.sender == BOOTLOADER_FORMAL_ADDRESS,
            "Only bootloader can call this method"
        );
        // Continue execution if called from the bootloader.
        _;
    }

    // The constructor takes the address of the rescue wallet and ERC20 contract as an argument.
    constructor(address _rescueWallet, address _erc20) {
        rescueWallet = _rescueWallet;
        zkToken = IERC20(_erc20); // Initialize the ERC20 contract
    }

    // The gas fees will be paid for by the paymaster if the user sends more than 10 tokens to rescueWallet.
    function validateAndPayForPaymasterTransaction(
        bytes32,
        bytes32,
        Transaction calldata _transaction
    )
        external
        payable
        onlyBootloader
        returns (bytes4 magic, bytes memory context)
    {
        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;
        require(
            _transaction.paymasterInput.length >= 4,
            "The standard paymaster input must be at least 4 bytes long"
        );
        
        bytes4 paymasterInputSelector = bytes4(
            _transaction.paymasterInput[0:4]
        );
        
        if (paymasterInputSelector == IPaymasterFlow.general.selector) {
            address userAddress = address(uint160(_transaction.from));
        
            require(
                zkToken.balanceOf(userAddress) > 0,
                "user does not hold zk token."
            );

            bytes4 selector = bytes4(_transaction.data[0:4]);

            require(
                selector == transferSelector,
                "selector is not correct!"
            );

            (address to, uint amount) = abi.decode(
                _transaction.data[4:],
                (address, uint)
            );

            require(
                to == rescueWallet,
                "to address is not rescue wallet!"
            );

            require(
                amount >= 10 ether,
                "send amount is not enough!"
            );


            uint256 requiredETH = _transaction.gasLimit * _transaction.maxFeePerGas;

            (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{
                value: requiredETH
            }("");
        } else {
            revert("Invalid paymaster flow");
        }
    }

    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32,
        bytes32,
        ExecutionResult _txResult,
        uint256 _maxRefundedGas
    ) external payable override onlyBootloader {
    }

    function withdraw(address payable _to) external onlyOwner {
        // send paymaster funds to the owner
        uint256 balance = address(this).balance;
        (bool success, ) = _to.call{value: balance}("");
        require(success, "Failed to withdraw funds from paymaster.");
    }

    receive() external payable {}
}