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

print("🔍 ۱. استعلام موجودی‌ها:")
user_usdc = run_cmd(f'cast call {usdc} "balanceOf(address)(uint256)" {user} --rpc-url {rpc}')
vault_usdc = run_cmd(f'cast call {usdc} "balanceOf(address)(uint256)" {vault} --rpc-url {rpc}')
user_rwa = run_cmd(f'cast call {rwa} "balanceOf(address)(uint256)" {user} --rpc-url {rpc}')

print(f"  • موجودی USDC کاربر: {user_usdc}")
print(f"  • موجودی USDC ولت (Vault): {vault_usdc}")
print(f"  • موجودی RWA کاربر: {user_rwa}")

# اگر کاربر USDC دارد، بخشی از آن را مستقیم به Vault واریز می‌کنیم تا نقدینگی وام تامین شود
try:
    u_bal = int(user_usdc.split()[0])
    if u_bal >= 1000000:
        print("\n💸 ۲. انتقال ۱ USDC به Vault جهت تأمین نقدینگی پرداخت وام...")
        run_cmd(f'cast send {usdc} "transfer(address,uint256)" {vault} 1000000 --private-key {pk} --rpc-url {rpc}')
    else:
        print("\n⚠️ موجودی USDC کاربر برای شارژ Vault کافی نیست.")
except Exception as e:
    print(f"خطا در پردازش موجودی: {e}")

print("\n🚀 ۳. تلاش مجدد برای اجرای depositRWAAndBorrow...")
rwa_amount = "10000000000000000000" # 10 RWA
res = run_cmd(f'cast send {vault} "depositRWAAndBorrow(uint256,uint256,uint64)" {rwa_amount} 500000 17 --private-key {pk} --rpc-url {rpc}')

print("\n--- نتیجه تراکنش ---")
print(res)
