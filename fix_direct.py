import subprocess

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("🔍 ۱. خواندن آدرس توکن‌های ثبت‌شده مستقیم از داخل قرارداد Vault...")

# دریافت آدرس توکن‌ها از روی توابع خواندنی قرارداد
rwa = run_cmd(f'cast call {vault} "rwaToken()(address)" --rpc-url {rpc}')
usdc = run_cmd(f'cast call {vault} "usdcToken()(address)" --rpc-url {rpc}')
asset = run_cmd(f'cast call {vault} "asset()(address)" --rpc-url {rpc}')

print(f"   • توکن RWA: {rwa}")
print(f"   • توکن USDC: {usdc}")
print(f"   • توکن Asset: {asset}")

tokens = set()
for t in [rwa, usdc, asset]:
    if t and t.startswith("0x") and len(t) == 42 and t != "0x0000000000000000000000000000000000000000":
        tokens.add(t)

# توکن پیش‌فرض
tokens.add("0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751")

amount = "1000000000000000000000000" # ۱,۰۰۰,۰۰۰ توکن

print("\n⚡ ۲. شارژ و Approve توکن‌های اصلی...")
for t in tokens:
    print(f"   • در حال تنظیم توکن: {t}")
    run_cmd(f'cast send {t} "mint(address,uint256)" {user} {amount} --private-key {pk} --rpc-url {rpc}')
    run_cmd(f'cast send {t} "mint(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')
    run_cmd(f'cast send {t} "approve(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')

print("\n🧪 ۳. تست اجرای depositAndBorrow...")
output = run_cmd(f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --private-key {pk} --rpc-url {rpc}')

print("\n--- خروجی تراکنش شبکه ---")
print(output)
