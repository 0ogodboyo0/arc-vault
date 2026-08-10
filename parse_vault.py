import os

path = "src/SelfPayingVault.sol"
if os.path.exists(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    print("=== 1. Definition variables‌been on top of the contract ===")
    for i in range(min(50, len(lines))):
        if any(kw in lines[i] for kw in ["IERC20", "address", "uint256", "ISuperfluid", "IRWA"]):
            print(f"Line {i+1}: {lines[i].strip()}")
            
    print("\n=== 2. The full body of the function depositAndBorrow ===")
    start = False
    brace_count = 0
    for i, line in enumerate(lines):
        if "function depositAndBorrow" in line:
            start = True
        if start:
            print(f"Line {i+1}: {line.rstrip()}")
            brace_count += line.count('{') - line.count('}')
            if brace_count == 0 and "function" not in line:
                break
else:
    print("❌ File not found!")
