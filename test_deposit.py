import subprocess, os

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("📖 1. Full function signature depositRWAAndBorrow:")
with open("src/SelfPayingVault.sol", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    print("".join(lines[207:235]))

print("\n⚡ 2. Charging the collateral token RWA and Approve:")
rwa = "0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"
rwa_amount = "10000000000000000000" # 10 RWA (18 decimals)

run_cmd(f'cast send {rwa} "mint(address,uint256)" {user} {rwa_amount} --private-key {pk} --rpc-url {rpc}')
run_cmd(f'cast send {rwa} "approve(address,uint256)" {vault} {rwa_amount} --private-key {pk} --rpc-url {rpc}')

print("\n🧪 3. Recall test depositRWAAndBorrow:")
# Argument query‌  and     ‌to be
