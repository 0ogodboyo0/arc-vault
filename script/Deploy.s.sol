// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AttestationRegistry.sol";
import "../src/ComplianceRegistry.sol";
import "../src/mocks/MockRWAToken.sol";
import "../src/SelfPayingVault.sol";

/// @dev Deploy order:
///      1. AttestationRegistry
///      2. MockRWAToken (skip this and pass a real RWA token address if you have one)
///      3. ArcRWASelfPayingVault, wired to (1) and (2), plus Arc Testnet's native USDC ERC20 wrapper
///
/// Arc Testnet USDC ERC20 wrapper (6 decimals): 0x3600000000000000000000000000000000000000
/// Chain ID: 5042002 | RPC: https://rpc.testnet.arc.network | Explorer: https://testnet.arcscan.app
contract DeployScript is Script {
    address constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // Optional: set AI_RISK_AGENT / TREASURY in .env, otherwise default to deployer.
        address aiRiskAgent = vm.envOr("AI_RISK_AGENT", deployer);
        address treasury = vm.envOr("TREASURY", deployer);

        // Initial collateral price: USDC (6 decimals) per 1 whole (1e18) RWA token.
        // Example: 1,000_000000 = 1 RWA token is worth 1,000 USDC. Adjust before running.
        uint256 initialPrice = vm.envOr("INITIAL_COLLATERAL_PRICE", uint256(1_000_000000));

        vm.startBroadcast(deployerKey);

        AttestationRegistry registry = new AttestationRegistry(deployer);
        registry.setAttester(deployer, true); // deployer can issue attestations for demo/testing

        ComplianceRegistry compliance = new ComplianceRegistry(deployer);
        compliance.setOfficer(deployer, true); // deployer can KYC/accredit borrowers for demo/testing

        MockRWAToken rwaToken = new MockRWAToken();
        rwaToken.mint(deployer, 1_000 ether); // seed 1,000 test RWA tokens to deployer

        ArcRWASelfPayingVault vault = new ArcRWASelfPayingVault(
            ARC_TESTNET_USDC,
            address(rwaToken),
            address(registry),
            address(compliance),
            aiRiskAgent,
            treasury,
            initialPrice
        );

        vm.stopBroadcast();

        console.log("AttestationRegistry deployed at:", address(registry));
        console.log("ComplianceRegistry deployed at:", address(compliance));
        console.log("MockRWAToken deployed at:", address(rwaToken));
        console.log("ArcRWASelfPayingVault deployed at:", address(vault));
        console.log("Remember: borrowers need BOTH an attestation AND a compliance profile");
        console.log("  (ComplianceRegistry.setProfile) before depositRWAAndBorrow will succeed.");
        console.log("Remember to fund the vault with USDC so it can issue loans:");
        console.log("  the vault pays out from its own USDC balance in depositRWAAndBorrow.");
    }
}
