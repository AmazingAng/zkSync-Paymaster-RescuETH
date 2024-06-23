# zkSync-Paymaster-RescuETH

Paymaster contracts used in resue zkSync airdrop from exploited wallets, by [RescuETH team](https://x.com/OurRescuETH).


## Details

1. [wlPaymaster.sol](./contracts/wlPaymaster.sol): This Paymaster contract pays the gas fees on behalf of Whitelisted wallets.

2. [zkPaymaster.sol](./contracts/zkPaymaster.sol): This Paymaster contract pays the gas fees on behalf of wallets who sends more than 10 tokens to target address (rescueWallet).