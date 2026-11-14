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
        bytes32 attestationHash; // hash of the off-chain provider result; no PII is stored on-chain
    }

    address public owner;
    mapping(address => bool) public isComplianceOfficer;
    mapping(address => bool) public isAttestationVerifier;
    mapping(address => Profile) public profiles;
    mapping(address => uint256) public attestationNonces;

    /// @notice Maximum USDC (6 decimals) loan size permitted for each accreditation tier.
    mapping(AccreditationTier => uint256) public maxLoanForTier;

    event OwnerUpdated(address indexed newOwner);
    event OfficerUpdated(address indexed officer, bool allowed);
    event AttestationVerifierUpdated(address indexed verifier, bool allowed);
    event ProfileUpdated(
        address indexed subject,
        bool kycVerified,
        AccreditationTier tier,
        uint64 expiresAt,
        bytes32 attestationHash,
        address indexed updatedBy
    );
    event ProfileUpdatedByAttestation(
        address indexed subject,
        AccreditationTier tier,
        uint64 expiresAt,
        bytes32 attestationHash,
        address indexed verifier,
        uint256 nonce
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

    function setAttestationVerifier(address verifier, bool allowed) external onlyOwner {
        require(verifier != address(0), "ComplianceRegistry: zero verifier");
        isAttestationVerifier[verifier] = allowed;
        emit AttestationVerifierUpdated(verifier, allowed);
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
        profiles[subject].attestationHash = bytes32(0);

        emit ProfileUpdated(subject, kycVerified, tier, expiresAt, bytes32(0), msg.sender);
    }

    /// @notice Apply a provider result signed by an authorized verifier.
    /// @dev The provider keeps the identity documents off-chain. Only a hash of
    ///      the provider result and its signed eligibility claim are stored here.
    function setProfileByAttestation(
        address subject,
        bool kycVerified,
        AccreditationTier tier,
        uint64 validityPeriod,
        bytes32 attestationHash,
        uint256 nonce,
        bytes calldata signature
    ) external {
        require(subject != address(0), "ComplianceRegistry: zero subject");
        require(attestationHash != bytes32(0), "ComplianceRegistry: zero attestation");
        require(nonce == attestationNonces[subject], "ComplianceRegistry: bad nonce");

        bytes32 digest = getAttestationDigest(
            subject,
            kycVerified,
            tier,
            validityPeriod,
            attestationHash,
            nonce
        );
        address verifier = _recover(digest, signature);
        require(isAttestationVerifier[verifier], "ComplianceRegistry: invalid verifier");

        uint64 expiresAt = validityPeriod == 0 ? uint64(0) : uint64(block.timestamp) + validityPeriod;
        profiles[subject] = Profile({
            kycVerified: kycVerified,
            restricted: profiles[subject].restricted,
            tier: tier,
            verifiedAt: uint64(block.timestamp),
            expiresAt: expiresAt,
            attestationHash: attestationHash
        });
        attestationNonces[subject] = nonce + 1;

        emit ProfileUpdatedByAttestation(subject, tier, expiresAt, attestationHash, verifier, nonce);
    }

    function getAttestationDigest(
        address subject,
        bool kycVerified,
        AccreditationTier tier,
        uint64 validityPeriod,
        bytes32 attestationHash,
        uint256 nonce
    ) public view returns (bytes32) {
        bytes32 payload = keccak256(
            abi.encode(
                address(this),
                block.chainid,
                subject,
                kycVerified,
                tier,
                validityPeriod,
                attestationHash,
                nonce
            )
        );
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", payload));
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

    function _recover(bytes32 digest, bytes calldata signature) internal pure returns (address signer) {
        require(signature.length == 65, "ComplianceRegistry: bad signature");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "ComplianceRegistry: bad v");
        signer = ecrecover(digest, v, r, s);
        require(signer != address(0), "ComplianceRegistry: invalid signature");
    }
}
