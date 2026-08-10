import subprocess, os

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"

print("📄 ۱. نمایش سورس‌کد تابع depositAndBorrow:")
for root, dirs, files in os.walk("."):
    if "cache" in root or "out" in root:
        continue
    for f in files:
        if f.endswith(".sol"):
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8", errors="ignore") as file:
                content = file.read()
                if "depositAndBorrow" in content:
                    print(f"\n--- فایل: {path} ---")
                    lines = content.split('\n')
                    for i, line in enumerate(lines):
                        if "depositAndBorrow" in line:
                            print("\n".join(lines[max(0, i-2):min(len(lines), i+35)]))
                            break

print("\n🔍 ۲. استخراج علت دقیق Revert از شبکه (Dry-Run):")
cmd = f'cast call {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --from {user} --rpc-url {rpc}'
res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout.strip()

print("نتیجه اجرای خشک:")
print(res)
