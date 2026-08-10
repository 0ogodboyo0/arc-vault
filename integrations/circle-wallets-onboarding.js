
// Default contract constants
if (!localStorage.getItem('vaultAddress')) {
    localStorage.setItem('vaultAddress', '0x6f29286af2134afce4619038a2cd7a48666449d7');
    localStorage.setItem('attestationAddress', '0xE49151151A55a84909e581066233de33f4d0f396');
    localStorage.setItem('complianceAddress', '0x28b0fe105D3A936eA72791d5730991df8A0e6863');
    localStorage.setItem('rwaAddress', '0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751');
}
/**
 * Circle Wallets integration (Developer-Controlled) — borrower onboarding without a seed phrase.
 * =================================================================================================
 *
 * WHY: The vault's real users (SME owners, RWA issuers) are often not crypto-native. Circle's
 * Developer-Controlled Wallets let us create and manage a wallet for each borrower server-side
 * and call the vault's functions directly via createContractExecutionTransaction — no MetaMask,
 * no seed phrase, no separate gas token to explain (Arc's gas *is* USDC anyway).
 *
 * STATUS: Architecture-level integration. The SDK calls, chain code, and parameter shapes below
 * match Circle's published documentation and npm package as of this writing, but this has NOT
 * been executed against a live Circle account in this environment (no network access here, and
 * no API key was available). Get your own CIRCLE_API_KEY + register an ENTITY_SECRET at
 * https://console.circle.com/signup before running this for real, and re-check the current docs
 * for any parameter changes.
 *
 * Docs:
 *   https://developers.circle.com/wallets/dev-controlled
 *   https://developers.circle.com/wallets/dev-controlled/onboard-users
 *   https://www.npmjs.com/package/@circle-fin/developer-controlled-wallets
 *
 * Install: npm install @circle-fin/developer-controlled-wallets
 */

const { initiateDeveloperControlledWalletsClient } = require('@circle-fin/developer-controlled-wallets');

const circleSdk = initiateDeveloperControlledWalletsClient({
  apiKey: process.env.CIRCLE_API_KEY,             // format: TEST_API_KEY:<id>:<secret> (or LIVE_API_KEY:...)
  entitySecret: process.env.CIRCLE_ENTITY_SECRET, // generate + register once via the SDK helper, see docs
});

const VAULT_ADDRESS = process.env.VAULT_ADDRESS;   // ArcRWASelfPayingVault deployment address
const ARC_TESTNET_CHAIN_CODE = 'ARC-TESTNET';      // Circle's chain code for Arc Testnet

/**
 * Step 1 — one-time setup: a wallet set groups every borrower wallet under one entity secret.
 */
async function createWalletSet() {
  const { data } = await circleSdk.createWalletSet({ name: 'ArcRWAVault Borrowers' });
  console.log('Wallet set created:', data.walletSet.id);
  return data.walletSet.id;
}

/**
 * Step 2 — onboard a new borrower: create their Arc Testnet wallet.
 * This developer-controlled version keeps custody with you (simpler for a hackathon demo).
 * For end-user self-custody instead, swap to Circle's User-Controlled Wallets + Web SDK
 * (email/social login + PIN) — see https://developers.circle.com/wallets/user-controlled/web-sdk
 */
async function onboardBorrower(walletSetId, borrowerLabel) {
  const { data } = await circleSdk.createWallets({
    walletSetId,
    blockchains: [ARC_TESTNET_CHAIN_CODE],
    accountType: 'SCA', // smart-contract account; 'EOA' also supported
    count: 1,
    metadata: [{ name: borrowerLabel }],
  });
  const wallet = data.wallets[0];
  console.log(`Wallet created for ${borrowerLabel}:`, wallet.address);
  return wallet;
}

/**
 * Step 3 — the borrower's Circle Wallet calls depositRWAAndBorrow directly. Circle abstracts the
 * ABI encoding, USDC-denominated gas, and signing — no ethers.js/viem required on the client.
 */
async function depositAndBorrowViaCircleWallet(walletId, collateralAmount, borrowAmount, attestationId) {
  const { data } = await circleSdk.createContractExecutionTransaction({
    walletId,
    contractAddress: VAULT_ADDRESS,
    abiFunctionSignature: 'depositRWAAndBorrow(uint256,uint256,uint64)',
    abiParameters: [collateralAmount, borrowAmount, attestationId],
    fee: { type: 'level', config: { feeLevel: 'MEDIUM' } },
  });
  console.log('Submitted depositRWAAndBorrow via Circle Wallet, tx id:', data.id);
  return data;
}

/**
 * Same pattern works for repay(), startSelfPayingStream(), or an ERC-20 approve() on the USDC
 * wrapper before repay — just change abiFunctionSignature + abiParameters.
 */
async function repayViaCircleWallet(walletId, amount) {
  const { data } = await circleSdk.createContractExecutionTransaction({
    walletId,
    contractAddress: VAULT_ADDRESS,
    abiFunctionSignature: 'repay(uint256)',
    abiParameters: [amount],
    fee: { type: 'level', config: { feeLevel: 'MEDIUM' } },
  });
  console.log('Submitted repay via Circle Wallet, tx id:', data.id);
  return data;
}

module.exports = {
  createWalletSet,
  onboardBorrower,
  depositAndBorrowViaCircleWallet,
  repayViaCircleWallet,
};
