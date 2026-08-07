// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AttestationRegistry.sol";
import "../src/ComplianceRegistry.sol";
import "../src/mocks/MockRWAToken.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/SelfPayingVault.sol";

contract SelfPayingVaultTest is Test {
    /// @dev Local mirror of ComplianceRegistry.EligibilityChecked. Foundry's vm.expectEmit matches
    ///      by event signature (topic0) and the emitting address, not by which contract the emit
    ///      statement is textually written in — so declaring an identically-shaped event here lets
    ///      us assert on it without depending on newer cross-contract qualified-event emit syntax.
    event EligibilityChecked(address indexed subject, uint256 loanValueUSDC, bool eligible);

    AttestationRegistry registry;
    ComplianceRegistry compliance;
    MockRWAToken rwa;
    MockUSDC usdc;
    ArcRWASelfPayingVault vault;

    address deployer = address(this);
    address aiAgent = address(0xAAA1);
    address treasury = address(0xAAA2);
    address borrower = address(0xB0B);

    uint256 constant PRICE = 1_000_000000; // 1 RWA token = 1,000 USDC (6 decimals)

    function setUp() public {
        registry = new AttestationRegistry(deployer);
        registry.setAttester(deployer, true);

        compliance = new ComplianceRegistry(deployer);
        compliance.setOfficer(deployer, true);

        rwa = new MockRWAToken();
        usdc = new MockUSDC();

        vault = new ArcRWASelfPayingVault(
            address(usdc),
            address(rwa),
            address(registry),
            address(compliance),
            aiAgent,
            treasury,
            PRICE
        );

        // Fund the vault so it can pay out loans.
        usdc.mint(address(vault), 200_000e6);

        // Give borrower some collateral.
        rwa.mint(borrower, 210 ether);
    }

    function _attestBorrower() internal returns (uint64 id) {
        id = registry.attest(borrower, keccak256("asset-doc-hash"), 365 days);
    }

    function _kyc(ComplianceRegistry.AccreditationTier tier) internal {
        compliance.setProfile(borrower, true, tier, 365 days);
    }

    // ---------------------------------------------------------------------
    // Attestation gating (unchanged behavior)
    // ---------------------------------------------------------------------

    function test_RevertsWithoutAttestation() public {
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vm.expectRevert("invalid attestation");
        vault.depositRWAAndBorrow(1 ether, 100e6, 999);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // Compliance gating (new)
    // ---------------------------------------------------------------------

    function test_RevertsWithoutComplianceProfile() public {
        uint64 id = _attestBorrower(); // attested, but never KYC'd

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vm.expectRevert("compliance check failed");
        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();
    }

    function test_RevertsWhenRestricted() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);
        compliance.setRestricted(borrower, true); // e.g. sanctions hit after KYC

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vm.expectRevert("compliance check failed");
        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();
    }

    function test_RevertsWhenLoanExceedsAccreditationTier() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail); // capped at 50,000 USDC by default

        vm.startPrank(borrower);
        rwa.approve(address(vault), 200 ether);
        // 200 RWA tokens @ 1,000 USDC = 200,000 value; 60% LTV allows up to 120,000 USDC,
        // which passes the LTV check but should still be rejected by the Retail tier cap.
        vm.expectRevert("compliance check failed");
        vault.depositRWAAndBorrow(200 ether, 100_000e6, id);
        vm.stopPrank();
    }

    function test_AccreditedTierUnlocksLargerLoan() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Accredited); // capped at 250,000 USDC by default

        vm.startPrank(borrower);
        rwa.approve(address(vault), 200 ether);
        vault.depositRWAAndBorrow(200 ether, 100_000e6, id); // now within both LTV and tier limits
        vm.stopPrank();

        ArcRWASelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertEq(loan.principal, 100_000e6);
        assertTrue(loan.isActive);
    }

    // ---------------------------------------------------------------------
    // Core lending flow (now with a compliant borrower)
    // ---------------------------------------------------------------------

    function test_BorrowRespectingLTV() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        // 1 RWA token = 1000 USDC value, 60% LTV => max borrow 600 USDC
        vm.expectRevert("exceeds max LTV");
        vault.depositRWAAndBorrow(1 ether, 700e6, id);

        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();

        ArcRWASelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertEq(loan.collateralAmount, 1 ether);
        assertEq(loan.principal, 600e6);
        assertTrue(loan.isActive);
        assertEq(usdc.balanceOf(borrower), 600e6);
    }

    function test_StreamSettlesDebtOverTime() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();

        // Borrower needs USDC income to stream from; simulate external income.
        usdc.mint(borrower, 1_000e6);

        vm.startPrank(borrower);
        usdc.approve(address(vault), type(uint256).max);
        vault.startSelfPayingStream(1e6); // 1 USDC/sec
        vm.stopPrank();

        vm.warp(block.timestamp + 100); // 100 seconds pass
        vault.settleStream(borrower);

        ArcRWASelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        // 600e6 principal + accrued interest - 100e6 streamed
        assertLt(loan.principal, 600e6);
    }

    function test_FullRepaymentReturnsCollateral() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();

        usdc.mint(borrower, 1_000e6);

        vm.startPrank(borrower);
        usdc.approve(address(vault), type(uint256).max);
        vault.repay(700e6); // overpay; should cap at outstanding principal (incl. any interest)
        vm.stopPrank();

        ArcRWASelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertEq(loan.principal, 0);
        assertFalse(loan.isActive);
        assertEq(loan.collateralAmount, 0);
        assertEq(rwa.balanceOf(borrower), 210 ether); // collateral fully returned
    }

    function test_AutoNettingSeizesProportionalCollateral() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 2 ether);
        vault.depositRWAAndBorrow(2 ether, 1_000e6, id); // 2 RWA @ 1000 = 2000 value, borrow 1000
        vm.stopPrank();

        vm.prank(aiAgent);
        vault.autoNettingRepay(borrower, 1 ether); // seize 1 RWA (worth 1000 USDC) to clear 1000 debt

        ArcRWASelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertEq(loan.principal, 0);
        assertFalse(loan.isActive);
        assertEq(rwa.balanceOf(treasury), 1 ether);
        // Remaining collateral (1 ether) returned to borrower on close.
        assertEq(loan.collateralAmount, 0);
        assertEq(rwa.balanceOf(borrower), 209 ether); // 210 - 2 deposited + 1 returned
    }

    function test_OnlyAIAgentCanLiquidate() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vault.depositRWAAndBorrow(1 ether, 500e6, id);
        vm.stopPrank();

        vm.expectRevert("only AI risk agent");
        vault.autoNettingRepay(borrower, 1 ether);
    }

    // ---------------------------------------------------------------------
    // ComplianceRegistry audit trail
    // ---------------------------------------------------------------------

    function test_EligibilityCheckEmitsAuditEvent() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.expectEmit(true, false, false, true, address(compliance));
        emit EligibilityChecked(borrower, 600e6, true);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();
    }
}
