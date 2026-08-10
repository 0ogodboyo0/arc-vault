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

print("🔍 1. Current inventory inquiry:")
print(f"   • Your Volt inventory: {get_bal(user)} RWA")
print(f"   • Treasury balance Vault: {get_bal(vault)} RWA")

print("\n⚡ 2. Depositing token‌and licensing...")
# Creating a token for the user Volt
run(f'cast send {token} "mint(address,uint256)" {user} 1000000000000000000000000 --private-key {pk} --rpc-url {rpc}')
# Making tokens for the treasury Vault
run(f'cast send {token} "mint(address,uint256)" {vault} 1000000000000000000000000 --private-key {pk} --rpc-url {rpc}')
# License to access the contract Vault
run(f'cast send {token} "approve(address,uint256)" {vault} 1000000000000000000000000 --private-key {pk} --rpc-url {rpc}')

print("\n✅ 3. Balance inquiry after charging:")
print(f"   • Your new Volt inventory: {get_bal(user)} RWA")
print(f"   • The new balance of the treasury Vault: {get_bal(vault)} RWA")

print("\n🧪 4. Implementation of direct test of deposit and loan receipt in the terminal...")
tx = run(f'cast send {vault} "depositAndBorrow(uint256,uint256,uint256)" 1000000000000000000 1000000000000000000 17 --private-key {pk} --rpc-url {rpc}')
if "status               1" in tx or "status               0x1" in tx:
    print("🎉 The transaction was successfully registered in the blockchain and the loan was received!")
else:
    print("Transaction result:")
    print(tx)
