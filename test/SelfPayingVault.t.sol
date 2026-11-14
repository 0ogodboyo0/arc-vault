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
    uint256 verifierKey = 0x12345;
    address verifier;

    uint256 constant PRICE = 1_000_000000; // 1 RWA token = 1,000 USDC (6 decimals)

    function setUp() public {
        registry = new AttestationRegistry(deployer);
        registry.setAttester(deployer, true);
        registry.setIssuer(deployer, true);

        verifier = vm.addr(verifierKey);

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
        id = registry.attestRWA(
            borrower,
            address(rwa),
            deployer,
            deployer,
            keccak256("real-estate"),
            keccak256("asset-001"),
            keccak256("asset-doc-hash"),
            365 days
        );
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
        vm.expectRevert("invalid asset attestation");
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

    function test_RevertsWhenAttestationTargetsDifferentToken() public {
        uint64 id = registry.attestRWA(
            borrower,
            address(0xCAFE),
            deployer,
            deployer,
            keccak256("real-estate"),
            keccak256("asset-002"),
            keccak256("asset-doc-hash-002"),
            365 days
        );
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vm.expectRevert("invalid asset attestation");
        vault.depositRWAAndBorrow(1 ether, 100e6, id);
        vm.stopPrank();
    }

    function test_RevertsWhenIssuerIsNoLongerApproved() public {
        uint64 id = _attestBorrower();
        registry.setIssuer(deployer, false);
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vm.expectRevert("invalid asset attestation");
        vault.depositRWAAndBorrow(1 ether, 100e6, id);
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

        vault.setCollateralPrice(500_000000); // position becomes undercollateralized
        vm.prank(aiAgent);
        vault.autoNettingRepay(borrower, 2 ether); // seize 2 RWA (worth 1000 USDC) to clear 1000 debt

        ArcRWASelfPayingVault.LoanPosition memory loan = vault.getLoan(borrower);
        assertEq(loan.principal, 0);
        assertFalse(loan.isActive);
        assertEq(rwa.balanceOf(treasury), 2 ether);
        // All collateral was seized to clear the debt after the price drop.
        assertEq(loan.collateralAmount, 0);
        assertEq(rwa.balanceOf(borrower), 208 ether); // 210 - 2 deposited
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

    function test_HealthyPositionCannotBeSoftLiquidated() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 2 ether);
        vault.depositRWAAndBorrow(2 ether, 1_000e6, id);
        vm.stopPrank();

        vm.prank(aiAgent);
        vm.expectRevert("position healthy");
        vault.autoNettingRepay(borrower, 1 ether);
    }

    function test_SecondBorrowAccruesInterestBeforeLTVCheck() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Accredited);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 2 ether);
        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        vm.startPrank(borrower);
        vm.expectRevert("exceeds max LTV");
        vault.depositRWAAndBorrow(0.1 ether, 13e6, id);
        vm.stopPrank();
    }

    function test_SecondBorrowUsesTotalDebtForComplianceLimit() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 200 ether);
        vault.depositRWAAndBorrow(100 ether, 49_500e6, id);
        vm.expectRevert("compliance check failed");
        vault.depositRWAAndBorrow(2 ether, 1_000e6, id);
        vm.stopPrank();
    }

    function test_SignedKYCProviderAttestationUpdatesProfile() public {
        compliance.setAttestationVerifier(verifier, true);
        bytes32 attestationHash = keccak256("provider-result-001");
        uint64 validity = 365 days;
        uint256 nonce = compliance.attestationNonces(borrower);
        bytes32 digest = compliance.getAttestationDigest(
            borrower,
            true,
            ComplianceRegistry.AccreditationTier.Accredited,
            validity,
            attestationHash,
            nonce
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifierKey, digest);

        compliance.setProfileByAttestation(
            borrower,
            true,
            ComplianceRegistry.AccreditationTier.Accredited,
            validity,
            attestationHash,
            nonce,
            abi.encodePacked(r, s, v)
        );

        ComplianceRegistry.Profile memory profile = compliance.getProfile(borrower);
        assertTrue(profile.kycVerified);
        assertEq(uint256(profile.tier), uint256(ComplianceRegistry.AccreditationTier.Accredited));
        assertEq(profile.attestationHash, attestationHash);
        assertEq(compliance.attestationNonces(borrower), nonce + 1);
    }

    function test_SignedKYCProviderAttestationCannotBeReplayed() public {
        compliance.setAttestationVerifier(verifier, true);
        bytes32 attestationHash = keccak256("provider-result-002");
        uint64 validity = 365 days;
        uint256 nonce = compliance.attestationNonces(borrower);
        bytes32 digest = compliance.getAttestationDigest(
            borrower,
            true,
            ComplianceRegistry.AccreditationTier.Retail,
            validity,
            attestationHash,
            nonce
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifierKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        compliance.setProfileByAttestation(
            borrower,
            true,
            ComplianceRegistry.AccreditationTier.Retail,
            validity,
            attestationHash,
            nonce,
            signature
        );

        vm.expectRevert("ComplianceRegistry: bad nonce");
        compliance.setProfileByAttestation(
            borrower,
            true,
            ComplianceRegistry.AccreditationTier.Retail,
            validity,
            attestationHash,
            nonce,
            signature
        );
    }

    // ---------------------------------------------------------------------
    // ComplianceRegistry audit trail
    // ---------------------------------------------------------------------

    function test_EligibilityCheckEmitsAuditEvent() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);

        vm.expectEmit(true, false, false, true, address(compliance));
        emit EligibilityChecked(borrower, 600e6, true);

        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();
    }
}
