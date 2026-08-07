// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SelfPayingVault.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockRWAToken.sol";
import "../src/ComplianceRegistry.sol";
import "../src/AttestationRegistry.sol";

contract SelfPayingVaultTest is Test {
    SelfPayingVault public vault;
    MockUSDC public usdc;
    MockRWAToken public rwa;
    ComplianceRegistry public compliance;
    AttestationRegistry public attestation;

    address public owner = address(1);
    address public borrower = address(2);
    address public aiAgent = address(3);
    address public treasury = address(4);

    function setUp() public {
        vm.startPrank(owner);
        usdc = new MockUSDC();
        rwa = new MockRWAToken();
        compliance = new ComplianceRegistry(owner);
        attestation = new AttestationRegistry(owner);

        vault = new SelfPayingVault(
            address(usdc),
            address(rwa),
            address(compliance),
            address(attestation),
            treasury,
            aiAgent,
            1000 // 10% annual interest
        );

        compliance.setOfficer(owner, true);
        compliance.setProfile(borrower, true, ComplianceRegistry.AccreditationTier.Retail, 365 days);

        usdc.mint(address(vault), 1_000_000 * 1e6);
        rwa.mint(borrower, 100 * 1e18);
        vm.stopPrank();

        vm.startPrank(borrower);
        rwa.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testDepositCollateralAndBorrow() public {
        vm.startPrank(borrower);
        vault.depositCollateral(10 * 1e18);
        vault.borrow(1000 * 1e6);
        
        SelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertTrue(loan.isActive);
        assertEq(loan.collateralAmount, 10 * 1e18);
        assertEq(loan.principal, 1000 * 1e6);
        vm.stopPrank();
    }

    function testRepayLoan() public {
        vm.startPrank(borrower);
        vault.depositCollateral(10 * 1e18);
        vault.borrow(1000 * 1e6);
        
        usdc.mint(borrower, 1000 * 1e6);
        vault.repay(1000 * 1e6);

        SelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertFalse(loan.isActive);
        vm.stopPrank();
    }

    function testAIEmergencyRepayment() public {
        vm.startPrank(borrower);
        vault.depositCollateral(10 * 1e18);
        vault.borrow(1000 * 1e6);
        usdc.mint(borrower, 500 * 1e6);
        vm.stopPrank();

        vm.prank(aiAgent);
        vault.emergencyRiskRepayment(borrower, 500 * 1e6);

        SelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertEq(loan.principal, 500 * 1e6);
    }
}
