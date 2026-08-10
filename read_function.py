import os

path = "src/SelfPayingVault.sol"
if os.path.exists(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    print("=== The full body of the function depositAndBorrow ===")
    printing = False
    count = 0
    for line in lines:
        if "depositAndBorrow" in line:
            printing = True
        if printing:
            print(line.rstrip())
            count += 1
            if count > 45: # Print 45 lines after the start of the function
                break
