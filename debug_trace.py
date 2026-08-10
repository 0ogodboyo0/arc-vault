import subprocess, os

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"

print("📂 ۱. لیست فایل‌های پروژه:")
for root, dirs, files in os.walk("."):
    if ".git" in root or "node_modules" in root:
        continue
    for f in files:
        print(os.path.join(root, f))

print("\n🔍 ۲. ردیابی عمیق خطای شبکه (-vvvv Trace):")
cmd = f'cast call {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --from {user} --rpc-url {rpc} -vvvv'
res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout.strip()

print("\n--- خروجی ردیابی (Trace) ---")
print(res)
