import os, subprocess

vault = "0x6f29286af2134afce4619038a2cd7a48666449d7"
attestation = "0xE49151151A55a84909e581066233de33f4d0f396"
compliance = "0x28b0fe105D3A936eA72791d5730991df8A0e6863"
rwa = "0x7306e00a86a1ceebeb99645ab7c9f5ef019d8751"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return res.stdout.strip()

print("📝 ۱. ذخیره مقادیر پیش‌فرض در فایل‌های فرانت‌اند...")

# ۱. تزریق اسکریپت مقداردهی اولیه در index.html
if os.path.exists("index.html"):
    with open("index.html", "r", encoding="utf-8", errors="ignore") as f:
        html_content = f.read()
    
    init_script = f"""
<script>
// Default Contract Addresses
localStorage.setItem('arc_vault_addr', '{vault}');
localStorage.setItem('arc_attestation_addr', '{attestation}');
localStorage.setItem('arc_compliance_addr', '{compliance}');
localStorage.setItem('arc_rwa_addr', '{rwa}');
localStorage.setItem('vaultAddress', '{vault}');
localStorage.setItem('attestationAddress', '{attestation}');
localStorage.setItem('complianceAddress', '{compliance}');
localStorage.setItem('rwaAddress', '{rwa}');
</script>
"""
    if "localStorage.setItem('vaultAddress'" not in html_content:
        if "</head>" in html_content:
            html_content = html_content.replace("</head>", f"{init_script}\n</head>")
        else:
            html_content = init_script + html_content
            
        with open("index.html", "w", encoding="utf-8") as f:
            f.write(html_content)
        print("  • آدرس‌ها با موفقیت در index.html ثبت شدند.")

# ۲. تزریق متغیرها در تمامی فایل‌های JS
for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".js"):
            file_path = os.path.join(root, file)
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                js_content = f.read()
            
            header = f"""
// Default contract constants
if (!localStorage.getItem('vaultAddress')) {{
    localStorage.setItem('vaultAddress', '{vault}');
    localStorage.setItem('attestationAddress', '{attestation}');
    localStorage.setItem('complianceAddress', '{compliance}');
    localStorage.setItem('rwaAddress', '{rwa}');
}}
"""
            if "localStorage.setItem('vaultAddress'" not in js_content:
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(header + js_content)
                print(f"  • فایل {file_path} بروزرسانی شد.")

print("\n🚀 ۲. ارسال تغییرات به گیت‌هاب...")
run_cmd("git add .")
run_cmd('git commit -m "Fix: Auto load default contract addresses"')
push_res = run_cmd("git push origin main")
print(push_res)
