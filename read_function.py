import os

path = "src/SelfPayingVault.sol"
if os.path.exists(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    print("=== بدنه کامل تابع depositAndBorrow ===")
    printing = False
    count = 0
    for line in lines:
        if "depositAndBorrow" in line:
            printing = True
        if printing:
            print(line.rstrip())
            count += 1
            if count > 45: # چاپ ۴۵ خط بعد از شروع تابع
                break
