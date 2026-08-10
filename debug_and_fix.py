import subprocess, glob, re, os

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

print("🔍 ۱. استخراج آدرس‌های توکن از فایل‌های پروژه...")
tokens = set(["0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"])

for f in glob.glob("**/*.sol", recursive=True):
    if os.path.isfile(f):
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
                addrs = re.findall(r'0x[a-fA-F0-9]{40}', content)
                for a in addrs:
                    if a.lower() != vault.lower():
                        tokens.add(a)
        except Exception:
            pass

print(f"توکن‌های پیدا شده: {tokens}")

amount_18 = "1000000000000000000000000" # ۱,۰۰۰,۰۰۰ توکن

print("\n⚡ ۲. شارژ و صدور مجوز (Approve) برای تمام توکن‌ها...")
for token in tokens:
    run(f'cast send {token} "mint(address,uint256)" {user} {amount_18} --private-key {pk} --rpc-url {rpc}')
    run(f'cast send {token} "mint(address,uint256)" {vault} {amount_18} --private-key {pk} --rpc-url {rpc}')
    run(f'cast send {token} "approve(address,uint256)" {vault} {amount_18} --private-key {pk} --rpc-url {rpc}')

print("\n🧪 ۳. ارسال تراکنش دریافت وام (depositAndBorrow)...")
# اجرای تراکنش با ۱ واحد وثیقه و ۱ واحد وام (اعشار ۶ برای USDC)
tx_cmd = f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000 17 --private-key {pk} --rpc-url {rpc}'
res = run(tx_cmd)

if "status               1" in res or "status               0x1" in res:
    print("🎉 تراکنش دریافت وام با موفقیت کامل انجام شد!")
else:
    print("⚠️ تست با ۶ اعشار رد شد، تست با ۱۸ اعشار...")
    tx_cmd_18 = f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --private-key {pk} --rpc-url {rpc}'
    res_18 = run(tx_cmd_18)
    if "status               1" in res_18 or "status               0x1" in res_18:
        print("🎉 تراکنش دریافت وام با موفقیت کامل انجام شد!")
    else:
        print("نتیجه تراکنش:")
        print(res_18)
