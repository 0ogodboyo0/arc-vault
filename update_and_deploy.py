import subprocess, re

path = "src/SelfPayingVault.sol"

# ۱. خواندن و اصلاح منطق شرط وام فعال
with open(path, "r", encoding="utf-8") as f:
    code = f.read()

# جایگزینی شرط Revert با منطق افزایش وثیقه/وام
old_check = 'require(!loans[msg.sender].isActive, "active loan exists");'
new_logic = '''// اگر وام فعال بود، به همان پوزیشن قبلی اضافه می‌شود
        if (loans[msg.sender].isActive) {
            uint256 totalCollateral = loans[msg.sender].collateralAmount + collateralAmount;
            uint256 totalBorrow = loans[msg.sender].principal + usdcBorrowAmount;
            
            uint256 totalCollateralValue = (totalCollateral * collateralPriceUSDC) / COLLATERAL_DECIMALS;
            uint256 maxBorrowAllowed = (totalCollateralValue * maxLTVBps) / BPS_DENOMINATOR;
            require(totalBorrow <= maxBorrowAllowed, "exceeds max LTV");
            
            require(complianceRegistry.isEligible(msg.sender, usdcBorrowAmount), "compliance check failed");
            require(rwaToken.transferFrom(msg.sender, address(this), collateralAmount), "collateral transfer failed");
            
            loans[msg.sender].collateralAmount = totalCollateral;
            loans[msg.sender].principal = totalBorrow;
            
            require(usdc.transfer(msg.sender, usdcBorrowAmount), "USDC payout failed");
            return;
        }'''

if old_check in code:
    code = code.replace(old_check, new_logic)
    with open(path, "w", encoding="utf-8") as f:
        f.write(code)
    print("✅ منطق قرارداد با موفقیت اصلاح شد (پشتیبانی از Top-up/چندین واریز).")
else:
    print("⚠️ شرط قبلی پیدا نشد یا قبلاً تغییر کرده است.")

# ۲. دپلوی قرارداد جدید با forge
print("\n🚀 در حال دپلوی قرارداد جدید روی شبکه Arc...")
rpc = "https://rpc.testnet.arc.network"
pk = "0x5f05eb81bae0844e7d31569d1bac2f0aa730e362d233c2f1c98b188334553fbf"

deploy_cmd = f'forge create src/SelfPayingVault.sol:SelfPayingVault --rpc-url {rpc} --private-key {pk}'
res = subprocess.run(deploy_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

print("\n--- خروجی دپلوی ---")
print(res.stdout)
