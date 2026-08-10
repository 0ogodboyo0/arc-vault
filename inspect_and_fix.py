import subprocess, glob, os, re

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("🔍 1. Scan and extract related codes depositAndBorrow...")
for root, dirs, files in os.walk("."):
    if "cache" in root or "out" in root:
        continue
    for f in files:
        if f.endswith(".sol"):
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8", errors="ignore") as file:
                content = file.read()
                if "depositAndBorrow" in content:
                    print(f"\n📄 file: {path}")
                    lines = content.split('\n')
                    for i, l in enumerate(lines):
                        if "function depositAndBorrow" in l:
                            print("\n".join(lines[i:min(len(lines), i+30)]))
                            break

print("\n🔍 .   token‌from the contract Vault...")
getters = ["rwaToken", "usdcToken", "rwa", "usdc", "asset"]
tokens = set()

for g in getters:
    out = run_cmd(f'cast call {vault} "{g}()(address)" --rpc-url {rpc}')
    if out.startswith("0x") and len(out) == 42 and out != "0x0000000000000000000000000000000000000000":
        print(f"  • {g}: {out}")
        tokens.add(out)

tokens.add("0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751")

print("\n⚡ 3. charging and Approve token‌I see...")
amount = "1000000000000000000000000"
for t in tokens:
    run_cmd(f'cast send {t} "mint(address,uint256)" {user} {amount} --private-key {pk} --rpc-url {rpc}')
    run_cmd(f'cast send {t} "mint(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')
    run_cmd(f'cast send {t} "approve(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')

print("\n🧪 4. Implementation test depositAndBorrow with ID‌different...")
for att in [17, 18, 1, 0]:
    print(f"\n--- test with Attestation ID = {att} ---")
    cmd = f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 {att} --private-key {pk} --rpc-url {rpc}'
    res = run_cmd(cmd)
    if "status               1" in res or "status               0x1" in res:
        print(f"🎉 The transaction was completed successfully! Attestation ID: {att}")
        break
    else:
        print(res)
