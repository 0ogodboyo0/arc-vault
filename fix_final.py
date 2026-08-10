import subprocess

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"
token = "0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

def get_bal(addr):
    res = run(f'cast call {token} "balanceOf(address)(uint256)" {addr} --rpc-url {rpc}')
    try:
        val = int(res.split()[0])
        return val / 10**18
    except:
        return 0

print("🔍 ۱. استعلام موجودی فعلی:")
print(f"   • موجودی ولت شما: {get_bal(user)} RWA")
print(f"   • موجودی خزانه Vault: {get_bal(vault)} RWA")

print("\n⚡ ۲. در حال واریز توکن‌ها و صدور مجوز...")
# ساخت توکن برای ولت کاربر
run(f'cast send {token} "mint(address,uint256)" {user} 1000000000000000000000000 --private-key {pk} --rpc-url {rpc}')
# ساخت توکن برای خزانه Vault
run(f'cast send {token} "mint(address,uint256)" {vault} 1000000000000000000000000 --private-key {pk} --rpc-url {rpc}')
# مجوز دسترسی به قرارداد Vault
run(f'cast send {token} "approve(address,uint256)" {vault} 1000000000000000000000000 --private-key {pk} --rpc-url {rpc}')

print("\n✅ ۳. استعلام موجودی پس از شارژ:")
print(f"   • موجودی جدید ولت شما: {get_bal(user)} RWA")
print(f"   • موجودی جدید خزانه Vault: {get_bal(vault)} RWA")

print("\n🧪 ۴. اجرای تست مستقیم واریز و دریافت وام در ترمینال...")
tx = run(f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --private-key {pk} --rpc-url {rpc}')
if "status               1" in tx or "status               0x1" in tx:
    print("🎉 تراکنش با موفقیت کامل در بلاکچین ثبت و وام دریافت شد!")
else:
    print("نتیجه تراکنش:")
    print(tx)
