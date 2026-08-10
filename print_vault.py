import os

path = "src/SelfPayingVault.sol"
if os.path.exists(path):
    print("=== Content of the contract SelfPayingVault.sol ===")
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        print(f.read())
    print("==========================================")
else:
    print("❌ File not found! File list‌folders src:")
    print(os.listdir("src"))
