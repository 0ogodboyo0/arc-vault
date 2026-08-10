import os

path = "src/SelfPayingVault.sol"
if os.path.exists(path):
    print("=== محتوای قرارداد SelfPayingVault.sol ===")
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        print(f.read())
    print("==========================================")
else:
    print("❌ فایل پیدا نشد! لیست فایل‌های پوشه src:")
    print(os.listdir("src"))
