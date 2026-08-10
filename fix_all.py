import glob, re, subprocess

rpc = "https://rpc.testnet.arc.network"
vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"
user = "0x99fd2d64e7c59697dd001189e5c4d970320cca44"

def run(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.stdout.strip()

print("🔍 در حال اسکن پروژه و استخراج آدرس توکن‌ها...")

found_addresses = set(["0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"])

# ۱. استخراج تمام آدرس‌های توکن از فایل‌های پروژه
for f_path in glob.glob("**/*.*", recursive=True):
    if f_path.endswith((".sol", ".js", ".html", ".json")):
        try:
            with open(f_path, "r", encoding="utf-8", errors="ignore") as f:
                addrs = re.findall(r'0x[a-fA-F0-9]{40}', f.read())
                for a in addrs:
                    if a.lower() != vault.lower():
                        found_addresses.add(a)
        except Exception:
            pass

# ۲. فراخوانی توکن‌های مرتبط با قرارداد Vault
getters = ["rwaToken", "usdcToken", "usdc", "borrowToken", "stablecoin", "token", "rwa", "collateralToken", "asset"]
for g in getters:
    sig = g + "()(address)"
    cmd = 'cast call ' + vault + ' "' + sig + '" --rpc-url ' + rpc
    res = run(cmd)
    if res and res.startswith("0x") and len(res) == 42 and res != "0x0000000000000000000000000000000000000000":
        print("✅ توکن پیدا شد (" + g + "): " + res)
        found_addresses.add(res)

amount = "1000000000000000000000000" # ۱,۰۰۰,۰۰۰ توکن

print("\n⚡ در حال شارژ حساب‌ها...")
for addr in found_addresses:
    cmd_user = 'cast send ' + addr + ' "mint(address,uint256)" ' + user + ' ' + amount + ' --private-key ' + pk + ' --rpc-url ' + rpc
    res_user = run(cmd_user)
    if "status" in res_user:
        print("✔️ توکن " + addr + " برای ولت شما شارژ شد.")
        cmd_vault = 'cast send ' + addr + ' "mint(address,uint256)" ' + vault + ' ' + amount + ' --private-key ' + pk + ' --rpc-url ' + rpc
        run(cmd_vault)
        print("✔️ توکن " + addr + " برای خزانه Vault شارژ شد.")

print("\n🎉 تمام توکن‌ها با موفقیت شارژ شدند.")
