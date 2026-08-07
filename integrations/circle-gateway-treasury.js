/**
 * Circle Gateway integration — unified treasury liquidity for collected repayments.
 * =================================================================================================
 *
 * WHY: The vault's treasury address accumulates USDC from interest, manual repayments, and
 * soft-liquidation proceeds — all on Arc. Circle Gateway lets that treasury hold ONE unified
 * USDC balance that's instantly (<500ms) usable on any Gateway-supported chain (Arc Testnet is
 * one of them, alongside Ethereum Sepolia, Base Sepolia, and others), instead of manually
 * bridging or pre-positioning funds per chain before an off-ramp partner or investor payout.
 *
 * STATUS: Architecture-level integration, same caveat as the Wallets script — the deposit-contract
 * call and general deposit -> unified-balance -> burn-intent -> attestation -> mint flow below
 * match Circle's published Gateway docs, but the exact REST host/path and EIP-712 field names
 * were not independently executed against a live Gateway account in this environment. Confirm the
 * current API base URL and burn-intent payload shape against the docs before running this live.
 *
 * Docs:
 *   https://developers.circle.com/gateway/concepts/technical-guide
 *   https://developers.circle.com/gateway/howtos/create-unified-usdc-balance
 */

const { ethers } = require('ethers');

const GATEWAY_API_BASE = 'https://gateway-api.circle.com'; // confirm exact host in current docs
const GATEWAY_WALLET_ABI = ['function deposit(address token, uint256 amount) external'];

/**
 * Step 1 — after settleStream/repay/autoNettingRepay move USDC into the treasury address, deposit
 * it into the Gateway Wallet contract on Arc Testnet. This is deliberately NOT a plain ERC-20
 * transfer: Gateway requires the deposit() call so its off-chain service can credit the unified
 * balance once the deposit is finalized on-chain.
 */
async function depositTreasuryIntoGateway(treasurySigner, gatewayWalletAddress, usdcAddress, amount) {
  const gatewayWallet = new ethers.Contract(gatewayWalletAddress, GATEWAY_WALLET_ABI, treasurySigner);
  const tx = await gatewayWallet.deposit(usdcAddress, amount);
  await tx.wait();
  console.log(`Deposited ${amount} USDC into Gateway from treasury, tx: ${tx.hash}`);
  return tx.hash;
}

/**
 * Step 2 — check the unified balance across every chain the treasury has deposited into, via
 * Gateway's /v1/balances endpoint.
 */
async function getUnifiedBalance(apiKey, treasuryAddress) {
  const res = await fetch(`${GATEWAY_API_BASE}/v1/balances?address=${treasuryAddress}`, {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  const balances = await res.json();
  console.log('Unified USDC balance across chains:', balances);
  return balances;
}

/**
 * Step 3 — move a portion of treasury USDC to another chain (e.g. because an off-ramp partner or
 * an investor payout rail only operates on Base) WITHOUT bridging: sign a burn intent, submit it
 * to Circle's Gateway API for a signed attestation, then submit that attestation to the Gateway
 * Minter contract on the destination chain to mint.
 *
 * NOTE: the exact EIP-712 domain/types for the burn intent must be pulled from the current Gateway
 * docs — the shape below illustrates the fields involved, not a verified-working payload.
 */
async function routeTreasuryToDestinationChain({
  treasurySigner,
  apiKey,
  sourceDomain,
  destinationDomain,
  amount,
  recipient,
}) {
  const burnIntent = {
    sourceDomain,
    destinationDomain,
    amount,
    recipient,
    depositor: await treasurySigner.getAddress(),
  };

  // Placeholder domain/types — replace with the exact EIP-712 struct from current Gateway docs.
  const eip712Domain = { name: 'CircleGateway', version: '1' };
  const eip712Types = {
    BurnIntent: [
      { name: 'sourceDomain', type: 'uint32' },
      { name: 'destinationDomain', type: 'uint32' },
      { name: 'amount', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'depositor', type: 'address' },
    ],
  };
  const signature = await treasurySigner.signTypedData(eip712Domain, eip712Types, burnIntent);

  const res = await fetch(`${GATEWAY_API_BASE}/v1/transfer`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ burnIntent, signature }),
  });
  const attestation = await res.json();
  console.log('Gateway attestation received — submit this to the destination Gateway Minter contract:', attestation);
  return attestation;
}

module.exports = {
  depositTreasuryIntoGateway,
  getUnifiedBalance,
  routeTreasuryToDestinationChain,
};
