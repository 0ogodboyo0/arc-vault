import subprocess, glob, re, os

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

print("🔍 ۱. اسکن شبکه و جداسازی قراردادهای واقعی از آدرس‌های نامعتبر...")

candidates = set(["0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"])

for f in glob.glob("**/*.*", recursive=True):
    if os.path.isfile(f) and f.endswith((".json", ".js", ".sol")):
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                addrs = re.findall(r'0x[a-fA-F0-9]{40}', file.read())
                for a in addrs:
                    candidates.add(a)
        except Exception:
            pass

valid_tokens = set()
for addr in candidates:
    if addr.lower() == vault.lower() or addr.startswith("0x0000000000000000000000000000"):
        continue
    code = run(f'cast code {addr} --rpc-url {rpc}')
    if code and code != "0x" and len(code) > 10:
        print(f"  ✅ قرارداد معتبر روی شبکه یافت شد: {addr}")
        valid_tokens.add(addr)

amount = "1000000000000000000000000" # ۱,۰۰۰,۰۰۰ توکن

print("\n⚡ ۲. شارژ و صدور مجوز (Approve)...")
for t in valid_tokens:
    print(f"   • در حال تنظیم توکن {t}...")
    run(f'cast send {t} "mint(address,uint256)" {user} {amount} --private-key {pk} --rpc-url {rpc}')
    run(f'cast send {t} "mint(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')
    run(f'cast send {t} "approve(address,uint256)" {vault} {amount} --private-key {pk} --rpc-url {rpc}')

print("\n🧪 ۳. تست دریافت وام...")
res = run(f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --private-key {pk} --rpc-url {rpc}')

if "status               1" in res or "status               0x1" in res:
    print("🎉 تراکنش دریافت وام با موفقیت کامل انجام شد!")
else:
    print("نتیجه تراکنش:")
    print(res)
