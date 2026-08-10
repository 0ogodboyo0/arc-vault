import subprocess, os, re

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("📖 ۱. خواندن سورس‌کد SelfPayingVault.sol...")
vault_path = "src/SelfPayingVault.sol"
if os.path.exists(vault_path):
    with open(vault_path, "r", encoding="utf-8", errors="ignore") as f:
        code = f.read()
        print("\n--- بخش مربوط به depositAndBorrow ---")
        lines = code.split('\n')
        for i, l in enumerate(lines):
            if "depositAndBorrow" in l:
                print("\n".join(lines[max(0, i-2):min(len(lines), i+35)]))
                break

print("\n⚡ ۲. شارژ سنگین موجودی USDC خودِ Vault (جهت تامین نقدینگی وام)...")
# پیدا کردن آدرس توکن MockUSDC از پروژه
usdc_addr = ""
for root, dirs, files in os.walk("."):
    for f in files:
        if "MockUSDC" in f:
            # سعی در استخراج آدرس یا ساخت توکن
            pass

# استعلام آدرس توکن RWA و USDC از قرارداد
rwa = run_cmd(f'cast call {vault} "rwaToken()(address)" --rpc-url {rpc}')
usdc = run_cmd(f'cast call {vault} "usdcToken()(address)" --rpc-url {rpc}')

if not rwa.startswith("0x") or len(rwa) != 42:
    rwa = "0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"

print(f"  • آدرس RWA Token: {rwa}")
print(f"  • آدرس USDC Token: {usdc}")

amount = "1000000000000000000000000000" # ۱,۰۰۰,۰۰۰,۰۰۰

print("\n🔑 ۳. شارژ و صدور مجوز (Mint & Approve)...")
# شارژ کاربر
run_cmd(f'cast send {rwa} "mint(address,uint256)" {user} {amount} --private-key {pk} --rpc-url {rpc}')
run_cmd(f'cast send {rwa} "approve(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')

# شارژ نقدینگی Vault برای پرداخت وام
if usdc.startswith("0x") and len(usdc) == 42 and usdc != "0x0000000000000000000000000000000000000000":
    run_cmd(f'cast send {usdc} "mint(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')
    run_cmd(f'cast send {usdc} "mint(address,uint256)" {user} {amount} --private-key {pk} --rpc-url {rpc}')
    run_cmd(f'cast send {usdc} "approve(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')

# همچنین شارژ توکن RWA برای خود Vault
run_cmd(f'cast send {rwa} "mint(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')

print("\n🧪 ۴. اجرا و دریافت وام...")
res = run_cmd(f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --private-key {pk} --rpc-url {rpc}')

print("\n--- خروجی تراکنش ---")
print(res)
