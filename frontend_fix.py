with open('index.html', 'r') as f:
    content = f.read()

old1 = """    $('depositHint').textContent = eligible
      ? 'وثیقه/وام باید در سقف LTV و سقف tier (' + (TIER_NAMES[tierNum] || '') + ') باشد.'
      : 'ابتدا باید KYC شوید تا بتوانید وام بگیرید.';
  } catch (e) {"""

new1 = """    $('depositHint').textContent = eligible
      ? 'وثیقه/وام باید در سقف LTV و سقف tier (' + (TIER_NAMES[tierNum] || '') + ') باشد.'
      : 'ابتدا باید KYC شوید تا بتوانید وام بگیرید.';

    const attIdCheck = $('inAttestationId').value.trim();
    if (attIdCheck) {
      const { attestation } = contracts();
      const validAtt = await attestation.isValid(BigInt(attIdCheck), userAddress);
      $('statAttestation').textContent = validAtt ? ('#' + attIdCheck + ' معتبر ✓') : ('#' + attIdCheck + ' نامعتبر');
    }
  } catch (e) {"""

assert old1 in content, "PATTERN 1 NOT FOUND -- aborting"
content = content.replace(old1, new1)

old2 = """$('btnSelfAttest').addEventListener('click', async () => {
  if (!signer) return toast('اول کیف‌پول را وصل کن.');
  const { attestation } = contracts();
  const hash = ethers.keccak256(ethers.toUtf8Bytes('demo-asset-' + Date.now()));
  await runTx('Self-attest', () => attestation.attest(userAddress, hash, 31536000n));
});"""

new2 = """$('btnSelfAttest').addEventListener('click', async () => {
  if (!signer) return toast('اول کیف‌پول را وصل کن.');
  const { attestation } = contracts();
  const hash = ethers.keccak256(ethers.toUtf8Bytes('demo-asset-' + Date.now()));
  const receipt = await runTx('Self-attest', () => attestation.attest(userAddress, hash, 31536000n));
  try {
    for (const log of receipt.logs) {
      try {
        const parsed = attestation.interface.parseLog(log);
        if (parsed && parsed.name === 'AttestationIssued') {
          $('inAttestationId').value = parsed.args.id.toString();
          toast('Attestation ID شما: ' + parsed.args.id.toString());
          refreshAll();
          break;
        }
      } catch (e) { /* not this event, skip */ }
    }
  } catch (e) { /* non-fatal: id just won't auto-fill */ }
});"""

assert old2 in content, "PATTERN 2 NOT FOUND -- aborting"
content = content.replace(old2, new2)

with open('index.html', 'w') as f:
    f.write(content)
print("index.html patched OK (both fixes applied)")
