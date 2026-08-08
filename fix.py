import re

# Fix 1: SelfPayingVault.sol — settleStream must capture elapsed time BEFORE _accrueInterest
# resets loan.lastAccrual, otherwise elapsed is always 0 and the stream never pulls anything.
with open('src/SelfPayingVault.sol', 'r') as f:
    vault = f.read()

old_vault = '''    function settleStream(address borrower) public whenNotPaused nonReentrant {
        LoanPosition storage loan = loans[borrower];
        require(loan.isActive, "no active loan");
        _accrueInterest(loan);

        if (loan.flowRate == 0 || loan.principal == 0) return;

        uint256 elapsed = block.timestamp - loan.lastAccrual;
        uint256 due = loan.flowRate * elapsed;'''

new_vault = '''    function settleStream(address borrower) public whenNotPaused nonReentrant {
        LoanPosition storage loan = loans[borrower];
        require(loan.isActive, "no active loan");

        uint256 elapsed = block.timestamp - loan.lastAccrual; // capture before _accrueInterest resets it
        _accrueInterest(loan);

        if (loan.flowRate == 0 || loan.principal == 0) return;

        uint256 due = loan.flowRate * elapsed;'''

assert old_vault in vault, "PATTERN NOT FOUND in SelfPayingVault.sol -- aborting, no changes made"
vault = vault.replace(old_vault, new_vault)
with open('src/SelfPayingVault.sol', 'w') as f:
    f.write(vault)
print("SelfPayingVault.sol patched OK")

# Fix 2: test file — move rwa.approve() before vm.expectEmit() so the Approval event doesn't
# sit between the expectation and the actual EligibilityChecked event.
with open('test/SelfPayingVault.t.sol', 'r') as f:
    test = f.read()

old_test = '''    function test_EligibilityCheckEmitsAuditEvent() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.expectEmit(true, false, false, true, address(compliance));
        emit EligibilityChecked(borrower, 600e6, true);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);
        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();
    }'''

new_test = '''    function test_EligibilityCheckEmitsAuditEvent() public {
        uint64 id = _attestBorrower();
        _kyc(ComplianceRegistry.AccreditationTier.Retail);

        vm.startPrank(borrower);
        rwa.approve(address(vault), 1 ether);

        vm.expectEmit(true, false, false, true, address(compliance));
        emit EligibilityChecked(borrower, 600e6, true);

        vault.depositRWAAndBorrow(1 ether, 600e6, id);
        vm.stopPrank();
    }'''

assert old_test in test, "PATTERN NOT FOUND in test file -- aborting, no changes made"
test = test.replace(old_test, new_test)
with open('test/SelfPayingVault.t.sol', 'w') as f:
    f.write(test)
print("test/SelfPayingVault.t.sol patched OK")
