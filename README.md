# ArcRWASelfPayingVault

**Track 3 — Real World Asset Tokenization on Arc with Embedded Compliance**
Submitted to *The Stablecoins Commerce Stack Challenge* (Ignyte × Circle × Arc)

🔗 **Live demo:** https://0ogodboyo0.github.io/arc-vault/
🔗 **Repo:** https://github.com/0ogodboyo0/arc-vault

## What this is

A self-repaying, RWA-collateralized USDC lending vault on Arc Testnet. A borrower locks a
tokenized real-world asset as collateral, borrows USDC against it, and repays through a
continuous on-chain stream instead of manual installments. Every borrow is gated by two
independent on-chain checks — **asset attestation** and **KYC/accreditation compliance** — and
every compliance decision is logged as an on-chain event, giving Track 3's "embedded compliance"
requirement a working, queryable audit trail rather than an off-chain promise.

## Why it's built this way

Sign Protocol and Superfluid — the obvious off-the-shelf choices for attestation and streaming —
have no confirmed deployment on Arc Testnet. Rather than depend on infrastructure that doesn't
exist on this chain yet, this project implements both natively:

- **`AttestationRegistry.sol`** — an attester issues on-chain proof that a borrower owns/controls
  an asset, with revocation and expiry. Same role Sign Protocol would play.
- **Pull-based streaming inside the vault itself** — the borrower authorizes a USDC-per-second
  rate; anyone (borrower, keeper, or the AI risk agent) can call `settleStream` to advance the
  debt by elapsed time × rate. Same role Superfluid's CFA would play.

Both are documented as swap-in points: if Sign Protocol or Superfluid deploy on Arc later, the
vault's external interface doesn't need to change.

## Contracts

| File | Purpose |
|---|---|
| `src/SelfPayingVault.sol` | Core vault — deposit/borrow, stream repayment, manual repay, AI-agent soft liquidation |
| `src/AttestationRegistry.sol` | Arc-native attestation registry (Sign Protocol substitute) |
| `src/ComplianceRegistry.sol` | KYC/AML gate + investor accreditation tiers + on-chain audit log |
| `src/mocks/MockRWAToken.sol` | Test collateral token (18 decimals) |
| `src/mocks/MockUSDC.sol` | Local-test-only USDC stand-in (6 decimals) — Arc Testnet itself uses the real USDC at `0x3600000000000000000000000000000000000000` |
| `script/Deploy.s.sol` | Foundry deployment script |
| `test/SelfPayingVault.t.sol` | 11 Foundry tests, all passing |
| `index.html` | Live frontend (ethers.js, no build step) — served directly via GitHub Pages from repo root |
| `integrations/circle-wallets-onboarding.js` | Circle Wallets integration (architecture-level, see file header) |
| `integrations/circle-gateway-treasury.js` | Circle Gateway integration (architecture-level, see file header) |

## Circle products used on Arc

- **USDC** — Arc's native gas asset *and* the vault's settlement currency; no separate gas token
  needed for borrowers.
- **Circle Wallets** & **Circle Gateway** — integrated at the architecture level (see the two
  files above for exact SDK calls, chain codes, and honest notes on what's verified vs. not).

Full write-up of what worked, what didn't, and recommendations: [`CIRCLE_PRODUCT_FEEDBACK.md`](./CIRCLE_PRODUCT_FEEDBACK.md).

## Arc Testnet parameters

| Field | Value |
|---|---|
| Chain ID | `5042002` |
| RPC | `https://rpc.testnet.arc.network` |
| USDC (6 decimals) | `0x3600000000000000000000000000000000000000` |
| Explorer | `https://testnet.arcscan.app` |
| Faucet | `https://faucet.circle.com` |

## Running it yourself

Full beginner-to-deployed walkthrough (including a mobile/Termux path) is in
[`GETTING_STARTED.md`](./GETTING_STARTED.md). Quick version if you already have Foundry:

```bash
git clone https://github.com/0ogodboyo0/arc-vault.git
cd arc-vault
forge install foundry-rs/forge-std
forge build
forge test -vvv          # 11 passed, 0 failed

cp .env.example .env     # fill in PRIVATE_KEY
source .env
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url https://rpc.testnet.arc.network --broadcast --private-key $PRIVATE_KEY
```

After deploying, fund the vault's own address with USDC (it pays out loans from its own
balance) and open `index.html` — paste the four deployed addresses into its Settings panel.

## Other submission assets

- Architecture diagram: [`architecture-diagram.mermaid`](./architecture-diagram.mermaid)
- Demo video script: [`VIDEO_SCRIPT.md`](./VIDEO_SCRIPT.md)
- Circle product feedback: [`CIRCLE_PRODUCT_FEEDBACK.md`](./CIRCLE_PRODUCT_FEEDBACK.md)

## Honest limitations

- `collateralPriceUSDC` is owner-set, not a live oracle (Chainlink/Pyth) — noted as a
  production next-step, not hidden.
- The AI Risk Agent and Compliance Officer are single addresses in this demo; production would
  use a multisig or a real off-chain KYC provider feeding `ComplianceRegistry.setProfile`.
- Sign Protocol / Superfluid replacements above are intentional design decisions given current
  Arc Testnet deployment status, not workarounds hiding a limitation — see
  `CIRCLE_PRODUCT_FEEDBACK.md` for the full reasoning.
