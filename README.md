# Arc RWA Self-Paying Vault 🏦✨

**Arc RWA Self-Paying Vault** is a decentralized protocol built on the **Arc Testnet** that enables users to leverage Real-World Assets (RWA) as collateral, pass on-chain compliance & attestation verification, and receive automated self-paying loans.

---

## 🌟 Key Features

- **RWA Collateralization**: Lock verified Real-World Asset tokens to borrow stablecoins.
- **On-Chain Compliance (KYC & AML)**: Integrated `ComplianceRegistry` to manage borrower limits and institutional KYC status.
- **Attestation Framework**: On-chain verification via `AttestationRegistry` for eligible collateral and credentials.
- **Self-Paying Yield Streaming**: Continuous automated repayment options for active vaults.

---

## 📜 Deployed Smart Contracts (Arc Testnet)

- **Network Name**: Arc Testnet
- **Chain ID**: `5042002`
- **RPC Endpoint**: `https://rpc.testnet.arc.network`

| Contract | Address |
| :--- | :--- |
| **ArcRWASelfPayingVault** | `0x6f29286af2134afce4619038a2cd7a48666449d7` |
| **AttestationRegistry** | `0xe49151151a55a84909e581066233de33f4d0f396` |
| **ComplianceRegistry** | `0x28b0fe105d3a936ea72791d5730991df8a0e6863` |
| **MockRWAToken** | `0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751` |

---

## 🛠️ Architecture & Tech Stack

- **Smart Contracts**: Solidity `^0.8.20`
- **Framework**: Foundry (`forge` / `cast`)
- **Frontend**: Web3 Native HTML/JS + `ethers.js`
- **Hosting**: GitHub Pages

---

## 🚀 Development & Deployment

### Build Contracts
```bash
forge build

