import os

print("📂 لیست تمام توابع موجود در پوشه src:")
for root, dirs, files in os.walk("src"):
    for f in files:
        if f.endswith(".sol"):
            path = os.path.join(root, f)
            print(f"\n📄 فایل: {path}")
            with open(path, "r", encoding="utf-8", errors="ignore") as file:
                for line_num, line in enumerate(file, 1):
                    if "function " in line:
                        print(f"  Line {line_num:3d}: {line.strip()}")

