import re

file_path = "index.html"
with open(file_path, "r", encoding="utf-8") as f:
    html = f.read()

# ۱. اصلاح فراخوانی‌های ذخیره‌سازی به localStorage استاندارد
html = re.sub(r'await\s+window\.storage\.set', 'localStorage.setItem', html)
html = re.sub(r'await\s+window\.storage\.get', 'localStorage.getItem', html)
html = re.sub(r'window\.storage\.set', 'localStorage.setItem', html)
html = re.sub(r'window\.storage\.get', 'localStorage.getItem', html)

# ۲. تزریق تابع اصلاح‌شده ثبت Attestation و واریز وثیقه جهت جلوگیری از خطای Revert
fix_script = """
<script>
// کد اصلاحی برای تعامل با قراردادهای Arc Testnet
async function issueAttestFix() {
    try {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const signer = provider.getSigner();
        const address = await signer.getAddress();
        const attestationAddr = "0xe49151151a55a84909e581066233de33f4d0f396";
        const abi = ["function issueAttestation(address subject, bytes32 dataHash, uint64 validUntil) public returns (uint256)"];
        const contract = new ethers.Contract(attestationAddr, abi, signer);
        
        const tx = await contract.issueAttestation(
            address,
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            1893456000
        );
        alert("تراکنش ثبت Attestation ارسال شد. لطفاً منتظر تایید بمانید...");
        await tx.wait();
        alert("Attestation با موفقیت ثبت شد!");
        window.location.reload();
    } catch (err) {
        alert("خطا در ثبت Attestation: " + (err.reason || err.message));
    }
}
</script>
"""

if "issueAttestFix" not in html:
    html = html.replace("</head>", fix_script + "\n</head>")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(html)

print("فایل index.html با موفقیت ویرایش شد.")
