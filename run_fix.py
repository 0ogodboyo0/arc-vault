import subprocess

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"

# token‌identifications‌done
tokens = set(["0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"])

#       token‌Other possibilities (eg USDC)
for slot in range(10):
    cmd = f"cast storage {vault} {slot} --rpc-url {rpc}"
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    if len(res) >= 42:
        addr = "0x" + res[-40:]
        if addr != "0x0000000000000000000000000000000000000000" and addr.lower() != vault.lower():
            tokens.add(addr)

amount = "10000000000000000000000000" # 10 million tokens

print(f"🔍 token‌found‌done   Vault: {tokens}")

for t in tokens:
    print(f"\n⚡ Charging and setting the token {t}...")
    # 1. Charge your volt
    subprocess.run(f'cast send {t} "mint(address,uint256)" {user} {amount} --private-key {pk} --rpc-url {rpc}', shell=True)
    # 2. Charging contract treasury
    subprocess.run(f'cast send {t} "mint(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}', shell=True)
    # 3. Licensing Approve
    subprocess.run(f'cast send {t} "approve(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}', shell=True)

print("\n✅ Charging operation and Approve It ended successfully.")
