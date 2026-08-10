import subprocess

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"
usdc = "0x3600000000000000000000000000000000000000"
rwa = "0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("🔍 .  inventory‌I see:")
user_usdc = run_cmd(f'cast call {usdc} "balanceOf(address)(uint256)" {user} --rpc-url {rpc}')
vault_usdc = run_cmd(f'cast call {usdc} "balanceOf(address)(uint256)" {vault} --rpc-url {rpc}')
user_rwa = run_cmd(f'cast call {rwa} "balanceOf(address)(uint256)" {user} --rpc-url {rpc}')

print(f"  • inventory USDC user: {user_usdc}")
print(f"  • inventory USDC volt (Vault): {vault_usdc}")
print(f"  • inventory RWA user: {user_rwa}")

#  user USDC       to Vault deposit‌to ensure the liquidity of the loan
try:
    u_bal = int(user_usdc.split()[0])
    if u_bal >= 1000000:
        print("\n💸 2. Transfer 1 USDC to Vault To provide liquidity for loan payments...")
        run_cmd(f'cast send {usdc} "transfer(address,uint256)" {vault} 1000000 --private-key {pk} --rpc-url {rpc}')
    else:
        print("\n⚠️ inventory USDC user   Vault not enough.")
except Exception as e:
    print(f"   inventory: {e}")

print("\n🚀 3. Retry execution depositRWAAndBorrow...")
rwa_amount = "10000000000000000000" # 10 RWA
res = run_cmd(f'cast send {vault} "depositRWAAndBorrow(uint256,uint256,uint64)" {rwa_amount} 500000 17 --private-key {pk} --rpc-url {rpc}')

print("\n--- Transaction result ---")
print(res)
