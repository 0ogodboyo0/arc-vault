// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ComplianceRegistry
/// @notice Arc-native KYC/AML gate and investor-accreditation tiering for the vault, plus an
///         on-chain audit trail (every eligibility check is logged as an event).
/// @dev No external KYC/sanctions oracle has a confirmed deployment on Arc Testnet, so this
///      registry is the on-chain source of truth: a compliance officer records verification
///      results, and the vault calls `isEligible` before accepting any borrower. Swap in a real
///      KYC provider or on-chain identity network later without changing the vault's
///      IComplianceRegistry interface.
contract ComplianceRegistry {
    enum AccreditationTier {
        None,          // not verified — cannot borrow anything
        Retail,        // KYC'd individual, no formal accreditation
        Accredited,    // KYC'd + accredited investor
        Institutional  // KYC'd + institutional / qualified purchaser
    }

    struct Profile {
        bool kycVerified;
        bool restricted;        // sanctions/AML block — overrides everything else
        AccreditationTier tier;
        uint64 verifiedAt;
        uint64 expiresAt;       // 0 = never expires
    }

    address public owner;
    mapping(address => bool) public isComplianceOfficer;
    mapping(address => Profile) public profiles;

    /// @notice Maximum USDC (6 decimals) loan size permitted for each accreditation tier.
    mapping(AccreditationTier => uint256) public maxLoanForTier;

    event OwnerUpdated(address indexed newOwner);
    event OfficerUpdated(address indexed officer, bool allowed);
    event ProfileUpdated(
        address indexed subject,
        bool kycVerified,
        AccreditationTier tier,
        uint64 expiresAt,
        address indexed updatedBy
    );
    event RestrictionSet(address indexed subject, bool restricted, address indexed updatedBy);
    event TierLimitUpdated(AccreditationTier tier, uint256 maxLoanValueUSDC);
    event EligibilityChecked(address indexed subject, uint256 loanValueUSDC, bool eligible);

    modifier onlyOwner() {
        require(msg.sender == owner, "ComplianceRegistry: not owner");
        _;
    }

    modifier onlyOfficer() {
        require(isComplianceOfficer[msg.sender], "ComplianceRegistry: not officer");
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), "ComplianceRegistry: zero owner");
        owner = _owner;

        // Sensible testnet defaults — tune via setTierLimit for your own risk appetite.
        maxLoanForTier[AccreditationTier.None] = 0;
        maxLoanForTier[AccreditationTier.Retail] = 50_000e6;
        maxLoanForTier[AccreditationTier.Accredited] = 250_000e6;
        maxLoanForTier[AccreditationTier.Institutional] = type(uint256).max;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ComplianceRegistry: zero owner");
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    function setOfficer(address officer, bool allowed) external onlyOwner {
        isComplianceOfficer[officer] = allowed;
        emit OfficerUpdated(officer, allowed);
    }

    function setTierLimit(AccreditationTier tier, uint256 maxLoanValueUSDC) external onlyOwner {
        maxLoanForTier[tier] = maxLoanValueUSDC;
        emit TierLimitUpdated(tier, maxLoanValueUSDC);
    }

    /// @notice Compliance officer records/updates a KYC + accreditation result for `subject`.
    /// @param validityPeriod seconds until re-verification is required; 0 = never expires.
    function setProfile(
        address subject,
        bool kycVerified,
        AccreditationTier tier,
        uint64 validityPeriod
    ) external onlyOfficer {
        require(subject != address(0), "ComplianceRegistry: zero subject");
        uint64 expiresAt = validityPeriod == 0 ? uint64(0) : uint64(block.timestamp) + validityPeriod;

        profiles[subject].kycVerified = kycVerified;
        profiles[subject].tier = tier;
        profiles[subject].verifiedAt = uint64(block.timestamp);
        profiles[subject].expiresAt = expiresAt;

        emit ProfileUpdated(subject, kycVerified, tier, expiresAt, msg.sender);
    }

    /// @notice Sanctions/AML block. Overrides KYC + accreditation status entirely while true.
    function setRestricted(address subject, bool restricted) external onlyOfficer {
        profiles[subject].restricted = restricted;
        emit RestrictionSet(subject, restricted, msg.sender);
    }

    /// @notice Full eligibility check used by the vault before accepting a borrower.
    /// @dev State-changing (emits an event every call) so the complete history of who was
    ///      checked, when, for how much, and with what result is queryable on-chain — this
    ///      event log is the data source for an off-chain "audit dashboard" UI.
    function isEligible(address subject, uint256 loanValueUSDC) external returns (bool eligible) {
        eligible = _checkEligibility(subject, loanValueUSDC);
        emit EligibilityChecked(subject, loanValueUSDC, eligible);
    }

    /// @notice Same check but view-only (no event/state write) — for frontends to preview
    ///         eligibility before submitting a transaction.
    function checkEligibility(address subject, uint256 loanValueUSDC) external view returns (bool) {
        return _checkEligibility(subject, loanValueUSDC);
    }

    function _checkEligibility(address subject, uint256 loanValueUSDC) internal view returns (bool) {
        Profile memory p = profiles[subject];
        if (!p.kycVerified || p.restricted) return false;
        if (p.expiresAt != 0 && block.timestamp > p.expiresAt) return false;
        return loanValueUSDC <= maxLoanForTier[p.tier];
    }

    function getProfile(address subject) external view returns (Profile memory) {
        return profiles[subject];
    }
}
