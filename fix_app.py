import re

file_path = "index.html"
with open(file_path, "r", encoding="utf-8") as f:
    html = f.read()

# 1. Modify the call‌storage‌making to localStorage Standard
html = re.sub(r'await\s+window\.storage\.set', 'localStorage.setItem', html)
html = re.sub(r'await\s+window\.storage\.get', 'localStorage.getItem', html)
html = re.sub(r'window\.storage\.set', 'localStorage.setItem', html)
html = re.sub(r'window\.storage\.get', 'localStorage.getItem', html)

# 2. Injection correction function‌registered Attestation and depositing a deposit to avoid mistakes Revert
fix_script = """
<script>
// Fixed code to interact with contracts Arc Testnet
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
        alert("Registration transaction Attestation sent Please wait for confirmation...");
        await tx.wait();
        alert("Attestation Successfully registered!");
        window.location.reload();
    } catch (err) {
        alert("Error in registration Attestation: " + (err.reason || err.message));
    }
}
</script>
"""

if "issueAttestFix" not in html:
    html = html.replace("</head>", fix_script + "\n</head>")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(html)

print("file index.html Edited successfully.")
