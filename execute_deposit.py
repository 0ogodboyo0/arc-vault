import subprocess, os

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"
rwa = "0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("🔎 ۱. استخراج آدرس توکن USDC از قرارداد Vault:")
usdc_addr = run_cmd(f'cast call {vault} "usdc()(address)" --rpc-url {rpc}')
print(f"  • آدرس USDC: {usdc_addr}")

print("\n⚡ ۲. شارژ نقدینگی USDC خودِ Vault و شارژ/Approve توکن RWA کاربر:")
# شارژ ۱,۰۰۰ USDC (۶ رقم اعشار) به خود Vault برای تامین وام
run_cmd(f'cast send {usdc_addr} "mint(address,uint256)" {vault} 1000000000 --private-key {pk} --rpc-url {rpc}')

# شارژ ۱۰ توکن RWA (۱۸ رقم اعشار) به کاربر و دادن Approve به Vault
rwa_amount = "10000000000000000000" # 10 RWA
run_cmd(f'cast send {rwa} "mint(address,uint256)" {user} {rwa_amount} --private-key {pk} --rpc-url {rpc}')
run_cmd(f'cast send {rwa} "approve(address,uint256)" {vault} {rwa_amount} --private-key {pk} --rpc-url {rpc}')

print("\n🚀 ۳. ارسال تراکنش depositRWAAndBorrow...")
# ۱۰ RWA وثیقه | ۱ USDC وام (1_000_000) | شناسه Attestation: 17
cmd = f'cast send {vault} "depositRWAAndBorrow(uint256,uint256,uint64)" {rwa_amount} 1000000 17 --private-key {pk} --rpc-url {rpc}'
res = run_cmd(cmd)

print("\n--- نتیجه نهایی تراکنش ---")
print(res)
