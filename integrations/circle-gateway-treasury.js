// Circle Gateway & Treasury Integration Script
const { ethers } = require('ethers');

class CircleGatewayTreasury {
    constructor(providerUrl, treasuryAddress, gatewayAddress) {
        this.provider = new ethers.JsonRpcProvider(providerUrl);
        this.treasuryAddress = treasuryAddress;
        this.gatewayAddress = gatewayAddress;
    }

    async getTreasuryBalance(usdcContractAddress) {
        const abi = ["function balanceOf(address) view returns (uint256)"];
        const usdc = new ethers.Contract(usdcContractAddress, abi, this.provider);
        return await usdc.balanceOf(this.treasuryAddress);
    }

    async bridgeCrossChainUSDC(signer, destinationDomain, targetRecipient, amount) {
        const tokenMessengerAbi = [
            "function depositForBurn(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken) external returns (uint64)"
        ];
        const messenger = new ethers.Contract(this.gatewayAddress, tokenMessengerAbi, signer);
        
        const recipientBytes32 = ethers.zeroPadValue(targetRecipient, 32);
        const tx = await messenger.depositForBurn(
            amount,
            destinationDomain,
            recipientBytes32,
            usdcAddress
        );
        return await tx.wait();
    }
}

module.exports = CircleGatewayTreasury;
