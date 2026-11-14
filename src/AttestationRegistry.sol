// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AttestationRegistry
/// @notice Arc-native attestation registry for RWA ownership/authenticity proofs.
/// @dev Sign Protocol has no confirmed deployment on Arc Testnet (chain id 5042002) as of writing.
///      This registry mirrors Sign Protocol's core pattern (attester -> subject -> claim, with
///      revocation and expiry) so the vault has a working, on-chain source of truth today.
///      If/when Sign Protocol deploys on Arc, swap the vault's IAttestationSource implementation
///      to point at it without changing the vault's external interface.
contract AttestationRegistry {
    struct Attestation {
        address attester;
        address subject;      // the borrower/owner the attestation is about
        address assetToken;   // the exact token contract accepted as collateral
        address issuer;       // approved issuer of the underlying asset
        address custodian;    // approved custodian / administrator
        bytes32 assetType;    // normalized off-chain asset category
        bytes32 assetId;      // identifier of the underlying real-world asset
        bytes32 assetHash;    // keccak256 hash of off-chain asset documentation/metadata
        uint64 issuedAt;
        uint64 expiresAt;
        bool revoked;
    }

    address public owner;
    mapping(address => bool) public isAttester;
    mapping(address => bool) public isIssuer;
    mapping(uint64 => Attestation) public attestations;
    uint64 public nextAttestationId = 1;

    event OwnerUpdated(address indexed newOwner);
    event AttesterUpdated(address indexed attester, bool allowed);
    event IssuerUpdated(address indexed issuer, bool allowed);
    event AttestationIssued(
        uint64 indexed id,
        address indexed attester,
        address indexed subject,
        address assetToken,
        address issuer,
        address custodian,
        bytes32 assetId,
        bytes32 assetHash,
        uint64 expiresAt
    );
    event AttestationRevoked(uint64 indexed id, address indexed revokedBy);

    modifier onlyOwner() {
        require(msg.sender == owner, "AttestationRegistry: not owner");
        _;
    }

    modifier onlyAttester() {
        require(isAttester[msg.sender], "AttestationRegistry: not attester");
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), "AttestationRegistry: zero owner");
        owner = _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "AttestationRegistry: zero owner");
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    function setAttester(address attester, bool allowed) external onlyOwner {
        isAttester[attester] = allowed;
        emit AttesterUpdated(attester, allowed);
    }

    function setIssuer(address issuer, bool allowed) external onlyOwner {
        require(issuer != address(0), "AttestationRegistry: zero issuer");
        isIssuer[issuer] = allowed;
        emit IssuerUpdated(issuer, allowed);
    }

    /// @notice Issue an attestation that `subject` owns/controls the asset behind `assetHash`.
    /// @param validityPeriod seconds the attestation remains valid for.
    function attest(address subject, bytes32 assetHash, uint64 validityPeriod)
        external
        onlyAttester
        returns (uint64 id)
    {
        require(subject != address(0), "AttestationRegistry: zero subject");
        require(validityPeriod > 0, "AttestationRegistry: zero validity");

        id = nextAttestationId++;
        attestations[id] = Attestation({
            attester: msg.sender,
            subject: subject,
            assetToken: address(0),
            issuer: address(0),
            custodian: address(0),
            assetType: bytes32(0),
            assetId: bytes32(0),
            assetHash: assetHash,
            issuedAt: uint64(block.timestamp),
            expiresAt: uint64(block.timestamp) + validityPeriod,
            revoked: false
        });

        emit AttestationIssued(id, msg.sender, subject, address(0), address(0), address(0), bytes32(0), assetHash, attestations[id].expiresAt);
    }

    /// @notice Issue an attestation bound to one exact tokenized RWA asset.
    function attestRWA(
        address subject,
        address assetToken,
        address issuer,
        address custodian,
        bytes32 assetType,
        bytes32 assetId,
        bytes32 assetHash,
        uint64 validityPeriod
    ) external onlyAttester returns (uint64 id) {
        require(subject != address(0), "AttestationRegistry: zero subject");
        require(assetToken != address(0), "AttestationRegistry: zero token");
        require(isIssuer[issuer], "AttestationRegistry: issuer not approved");
        require(custodian != address(0), "AttestationRegistry: zero custodian");
        require(assetId != bytes32(0), "AttestationRegistry: zero asset id");
        require(assetHash != bytes32(0), "AttestationRegistry: zero asset hash");
        require(validityPeriod > 0, "AttestationRegistry: zero validity");

        id = nextAttestationId++;
        attestations[id] = Attestation({
            attester: msg.sender,
            subject: subject,
            assetToken: assetToken,
            issuer: issuer,
            custodian: custodian,
            assetType: assetType,
            assetId: assetId,
            assetHash: assetHash,
            issuedAt: uint64(block.timestamp),
            expiresAt: uint64(block.timestamp) + validityPeriod,
            revoked: false
        });

        emit AttestationIssued(
            id,
            msg.sender,
            subject,
            assetToken,
            issuer,
            custodian,
            assetId,
            assetHash,
            attestations[id].expiresAt
        );
    }

    function revoke(uint64 id) external {
        Attestation storage a = attestations[id];
        require(a.attester != address(0), "AttestationRegistry: unknown id");
        require(msg.sender == a.attester || msg.sender == owner, "AttestationRegistry: not authorized");
        a.revoked = true;
        emit AttestationRevoked(id, msg.sender);
    }

    /// @notice View check used by the vault before accepting collateral.
    function isValid(uint64 id, address subject) external view returns (bool) {
        Attestation memory a = attestations[id];
        if (a.attester == address(0)) return false;
        if (a.revoked) return false;
        if (a.subject != subject) return false;
        if (block.timestamp > a.expiresAt) return false;
        return true;
    }

    function isValidForAsset(uint64 id, address subject, address assetToken) external view returns (bool) {
        Attestation memory a = attestations[id];
        if (a.attester == address(0)) return false;
        if (a.revoked || a.subject != subject || a.assetToken != assetToken) return false;
        if (!isIssuer[a.issuer] || a.custodian == address(0)) return false;
        if (block.timestamp > a.expiresAt) return false;
        return true;
    }

    function getAttestation(uint64 id) external view returns (Attestation memory) {
        return attestations[id];
    }
}
