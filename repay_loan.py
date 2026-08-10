import subprocess

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"
usdc = "0x3600000000000000000000000000000000000000"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("🔎 ۱. استعلام amount of debt فعلی (اصل + profit accrued)...")
debt_raw = run_cmd(f'cast call {vault} "currentDebt(address)(uint256)" {user} --rpc-url {rpc}')
print(f"  • amount of debt: {debt_raw}")

# اگر مقدار بدهی دریافت شد، همان مقدار یا بیشتر جهت اطmayنان approve may‌to be
debt = int(debt_raw.split()[0]) if debt_raw and debt_raw.split()[0].isdigit() else 1000000

print("\n🔑 2. giving permission (Approve) USDC to contract Vault...")
run_cmd(f'cast send {usdc} "approve(address,uint256)" {vault} {debt} --private-key {pk} --rpc-url {rpc}')

print("\n💸 3. Implementation of the loan settlement function (repay)...")
res = run_cmd(f'cast send {vault} "repay(uint256)" {debt} --private-key {pk} --rpc-url {rpc}')

print("\n--- Settlement transaction output ---")
print(res)

print("\n🔍 4. Query the status of the loan again:")
loan_status = run_cmd(f'cast call {vault} "getLoan(address)((uint256,uint256,uint64,uint64,int96,bool))" {user} --rpc-url {rpc}')
print(f"  • current situation: {loan_status}")
