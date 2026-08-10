import subprocess, os

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"
rwa = "0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("🔎 1.  address token USDC From the contract Vault:")
usdc_addr = run_cmd(f'cast call {vault} "usdc()(address)" --rpc-url {rpc}')
print(f"  • address USDC: {usdc_addr}")

print("\n⚡ 2. Cash charge USDC self Vault and charging/Approve token RWA user:")
#  1, USDC (6 decimal places) to itself Vault To secure a loan
run_cmd(f'cast send {usdc_addr} "mint(address,uint256)" {vault} 1000000000 --private-key {pk} --rpc-url {rpc}')

#  1 token RWA (1  ) to user   Approve to Vault
rwa_amount = "10000000000000000000" # 10 RWA
run_cmd(f'cast send {rwa} "mint(address,uint256)" {user} {rwa_amount} --private-key {pk} --rpc-url {rpc}')
run_cmd(f'cast send {rwa} "approve(address,uint256)" {vault} {rwa_amount} --private-key {pk} --rpc-url {rpc}')

print("\n🚀 3. Send transaction depositRWAAndBorrow...")
# 1 RWA collateral | 1 USDC loan (1_000_000) | ID Attestation: 17
cmd = f'cast send {vault} "depositRWAAndBorrow(uint256,uint256,uint64)" {rwa_amount} 1000000 17 --private-key {pk} --rpc-url {rpc}'
res = run_cmd(cmd)

print("\n--- The final result of the transaction ---")
print(res)
