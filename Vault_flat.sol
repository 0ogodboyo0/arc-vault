// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// src/SelfPayingVault.sol

/// @dev Minimal ERC20 interface. USDC on Arc Testnet is available at the fixed system address
///      0x3600000000000000000000000000000000000000 with 6 decimals (native gas uses 18 decimals —
///      do not confuse the two). See https://docs.arc.io/arc/references/contract-addresses
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IAttestationSource {
    function isValid(uint64 id, address subject) external view returns (bool);
}

/// @dev Non-view by design: ComplianceRegistry.isEligible emits an on-chain audit event on every
///      call, which is what makes an off-chain "audit dashboard" possible without extra infra.
interface IComplianceRegistry {
    function isEligible(address subject, uint256 loanValueUSDC) external returns (bool);
}

/// @title ArcRWASelfPayingVault
/// @notice RWA-collateralized USDC lending vault for Arc Testnet with attestation-gated borrowing,
///         a self-contained continuous ("stream-style") repayment mechanism, and an AI Risk Guard
///         role for emergency repayment / soft liquidation (auto-netting).
/// @dev Superfluid has no confirmed deployment on Arc Testnet, so continuous repayment is
///      implemented natively here as a pull-based flow: the borrower authorizes a flowRate
///      (USDC per second) and approves the vault to pull USDC; `settleStream` (callable by
///      anyone — borrower, keeper, or the AI agent) advances the debt by elapsed time * flowRate.
///      This can be swapped for real Superfluid CFA calls later without changing external
///      function signatures used by the frontend.
contract ArcRWASelfPayingVault {
    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    address public owner;
    address public aiRiskAgent;
    address public treasury; // receives collateral seized during soft liquidation

    IERC20 public immutable usdc;          // Arc Testnet USDC ERC20 wrapper, 6 decimals
    IERC20 public immutable rwaToken;      // tokenized RWA collateral, 18 decimals
    IAttestationSource public attestationSource;
    IComplianceRegistry public complianceRegistry;

    bool public paused;
    bool private _locked; // reentrancy guard

    /// @notice USDC value of 1 whole (1e18) collateral token, expressed in USDC's 6-decimal units.
    uint256 public collateralPriceUSDC;

    /// @notice Max loan-to-value in basis points (e.g. 6000 = 60%).
    uint256 public maxLTVBps = 6000;

    /// @notice Annualized simple interest rate in basis points (e.g. 800 = 8% APR).
    uint256 public interestRateBps = 800;

    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant YEAR_SECONDS = 365 days;
    uint256 private constant COLLATERAL_DECIMALS = 1e18;

    struct LoanPosition {
        uint256 collateralAmount;   // 18 decimals (rwaToken)
        uint256 principal;          // outstanding debt incl. accrued interest, 6 decimals (USDC)
        uint64 attestationId;
        uint64 lastAccrual;         // last timestamp interest/stream was settled
        uint256 flowRate;           // authorized USDC-per-second stream rate, 6 decimals
        bool isActive;
    }

    mapping(address => LoanPosition) public loans;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event OwnerUpdated(address indexed newOwner);
    event AIAgentUpdated(address indexed newAgent);
    event TreasuryUpdated(address indexed newTreasury);
    event PausedSet(bool paused);
    event ParamsUpdated(uint256 maxLTVBps, uint256 interestRateBps);
    event PriceUpdated(uint256 newPrice);
    event AttestationSourceUpdated(address indexed newSource);
    event ComplianceRegistryUpdated(address indexed newRegistry);

    event LoanOpened(address indexed borrower, uint256 collateral, uint256 usdcBorrowed, uint64 attestationId);
    event StreamRateSet(address indexed borrower, uint256 flowRate);
    event StreamSettled(address indexed borrower, uint256 amountPulled, uint256 remainingPrincipal);
    event ManualRepayment(address indexed borrower, uint256 amount, uint256 remainingPrincipal);
    event LoanClosed(address indexed borrower, uint256 collateralReturned);
    event EmergencyRepaymentTriggered(address indexed borrower, uint256 amountRepaid);
    event SoftLiquidationExecuted(address indexed borrower, uint256 collateralSeized, uint256 debtReduced);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyAIAgent() {
        require(msg.sender == aiRiskAgent, "only AI risk agent");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "reentrancy");
        _locked = true;
        _;
        _locked = false;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(
        address _usdc,
        address _rwaToken,
        address _attestationSource,
        address _complianceRegistry,
        address _aiRiskAgent,
        address _treasury,
        uint256 _initialCollateralPriceUSDC
    ) {
        require(_usdc != address(0) && _rwaToken != address(0), "zero token address");
        require(_attestationSource != address(0), "zero attestation source");
        require(_complianceRegistry != address(0), "zero compliance registry");
        require(_aiRiskAgent != address(0) && _treasury != address(0), "zero role address");

        owner = msg.sender;
        usdc = IERC20(_usdc);
        rwaToken = IERC20(_rwaToken);
        attestationSource = IAttestationSource(_attestationSource);
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        aiRiskAgent = _aiRiskAgent;
        treasury = _treasury;
        collateralPriceUSDC = _initialCollateralPriceUSDC;
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    function setAIAgent(address newAgent) external onlyOwner {
        require(newAgent != address(0), "zero agent");
        aiRiskAgent = newAgent;
        emit AIAgentUpdated(newAgent);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "zero treasury");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function setAttestationSource(address newSource) external onlyOwner {
        require(newSource != address(0), "zero source");
        attestationSource = IAttestationSource(newSource);
        emit AttestationSourceUpdated(newSource);
    }

    function setComplianceRegistry(address newRegistry) external onlyOwner {
        require(newRegistry != address(0), "zero registry");
        complianceRegistry = IComplianceRegistry(newRegistry);
        emit ComplianceRegistryUpdated(newRegistry);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedSet(_paused);
    }

    function setRiskParams(uint256 _maxLTVBps, uint256 _interestRateBps) external onlyOwner {
        require(_maxLTVBps > 0 && _maxLTVBps <= BPS_DENOMINATOR, "bad LTV");
        require(_interestRateBps <= 5000, "rate too high"); // sanity cap at 50% APR
        maxLTVBps = _maxLTVBps;
        interestRateBps = _interestRateBps;
        emit ParamsUpdated(_maxLTVBps, _interestRateBps);
    }

    /// @notice Owner-set price feed. Replace with a real oracle (Chainlink/Pyth) when available on Arc.
    function setCollateralPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "zero price");
        collateralPriceUSDC = newPrice;
        emit PriceUpdated(newPrice);
    }

    // ---------------------------------------------------------------------
    // Core: open loan
    // ---------------------------------------------------------------------

    /// @notice Deposit attested RWA collateral and borrow USDC against it.
    function depositRWAAndBorrow(
        uint256 collateralAmount,
        uint256 usdcBorrowAmount,
        uint64 attestationId
    ) external whenNotPaused nonReentrant {
        // If the loan was active, it will be added to the previous position‌to be
        if (loans[msg.sender].isActive) {
            uint256 totalCollateral = loans[msg.sender].collateralAmount + collateralAmount;
            uint256 totalBorrow = loans[msg.sender].principal + usdcBorrowAmount;
            
            uint256 totalCollateralValue = (totalCollateral * collateralPriceUSDC) / COLLATERAL_DECIMALS;
            uint256 maxBorrowAllowed = (totalCollateralValue * maxLTVBps) / BPS_DENOMINATOR;
            require(totalBorrow <= maxBorrowAllowed, "exceeds max LTV");
            
            require(complianceRegistry.isEligible(msg.sender, usdcBorrowAmount), "compliance check failed");
            require(rwaToken.transferFrom(msg.sender, address(this), collateralAmount), "collateral transfer failed");
            
            loans[msg.sender].collateralAmount = totalCollateral;
            loans[msg.sender].principal = totalBorrow;
            
            require(usdc.transfer(msg.sender, usdcBorrowAmount), "USDC payout failed");
            return;
        }
        require(collateralAmount > 0 && usdcBorrowAmount > 0, "zero amount");
        require(attestationSource.isValid(attestationId, msg.sender), "invalid attestation");

        uint256 collateralValue = (collateralAmount * collateralPriceUSDC) / COLLATERAL_DECIMALS;
        uint256 maxBorrow = (collateralValue * maxLTVBps) / BPS_DENOMINATOR;
        require(usdcBorrowAmount <= maxBorrow, "exceeds max LTV");
        require(complianceRegistry.isEligible(msg.sender, usdcBorrowAmount), "compliance check failed");

        // Pull collateral into the vault BEFORE releasing funds (checks-effects-interactions).
        require(rwaToken.transferFrom(msg.sender, address(this), collateralAmount), "collateral transfer failed");

        loans[msg.sender] = LoanPosition({
            collateralAmount: collateralAmount,
            principal: usdcBorrowAmount,
            attestationId: attestationId,
            lastAccrual: uint64(block.timestamp),
            flowRate: 0,
            isActive: true
        });

        require(usdc.transfer(msg.sender, usdcBorrowAmount), "USDC payout failed");

        emit LoanOpened(msg.sender, collateralAmount, usdcBorrowAmount, attestationId);
    }

    // ---------------------------------------------------------------------
    // Core: continuous ("stream") repayment
    // ---------------------------------------------------------------------

    /// @notice Borrower authorizes a continuous USDC-per-second repayment rate.
    /// @dev Borrower must separately `approve` this contract on the USDC token for the stream
    ///      to be pullable by `settleStream`.
    function startSelfPayingStream(uint256 flowRatePerSecond) external whenNotPaused {
        LoanPosition storage loan = loans[msg.sender];
        require(loan.isActive, "no active loan");
        _accrueInterest(loan);
        loan.flowRate = flowRatePerSecond;
        emit StreamRateSet(msg.sender, flowRatePerSecond);
    }

    /// @notice Advance a borrower's stream: pulls elapsed_time * flowRate USDC toward their debt.
    ///         Callable by anyone (borrower, a keeper bot, or the AI agent) — this is what makes
    ///         repayment "automatic" without the borrower needing to send transactions.
    function settleStream(address borrower) public whenNotPaused nonReentrant {
        LoanPosition storage loan = loans[borrower];
        require(loan.isActive, "no active loan");

        uint256 elapsed = block.timestamp - loan.lastAccrual; // capture before _accrueInterest resets it
        _accrueInterest(loan);

        if (loan.flowRate == 0 || loan.principal == 0) return;

        uint256 due = loan.flowRate * elapsed;
        if (due == 0) return;

        uint256 amountToPull = due > loan.principal ? loan.principal : due;

        // Cap to borrower's actual USDC balance so a failed transferFrom can't brick settlement.
        uint256 borrowerBalance = usdc.balanceOf(borrower);
        if (amountToPull > borrowerBalance) {
            amountToPull = borrowerBalance;
        }

        if (amountToPull > 0) {
            require(usdc.transferFrom(borrower, address(this), amountToPull), "stream pull failed");
            loan.principal -= amountToPull;
        }

        loan.lastAccrual = uint64(block.timestamp);
        emit StreamSettled(borrower, amountToPull, loan.principal);

        if (loan.principal == 0) {
            _closeLoan(borrower, loan);
        }
    }

    /// @notice Direct one-off repayment by the borrower (in addition to, or instead of, streaming).
    function repay(uint256 amount) external whenNotPaused nonReentrant {
        LoanPosition storage loan = loans[msg.sender];
        require(loan.isActive, "no active loan");
        _accrueInterest(loan);
        require(amount > 0, "zero amount");

        uint256 amountToApply = amount > loan.principal ? loan.principal : amount;
        require(usdc.transferFrom(msg.sender, address(this), amountToApply), "repay transfer failed");
        loan.principal -= amountToApply;

        emit ManualRepayment(msg.sender, amountToApply, loan.principal);

        if (loan.principal == 0) {
            _closeLoan(msg.sender, loan);
        }
    }

    // ---------------------------------------------------------------------
    // AI Risk Guard
    // ---------------------------------------------------------------------

    /// @notice AI agent pulls available external USDC from the borrower to cover risk exposure.
    function emergencyRiskRepayment(address borrower, uint256 repayAmount)
        external
        onlyAIAgent
        whenNotPaused
        nonReentrant
    {
        LoanPosition storage loan = loans[borrower];
        require(loan.isActive, "no active loan");
        _accrueInterest(loan);
        require(repayAmount > 0, "zero amount");

        uint256 amountToApply = repayAmount > loan.principal ? loan.principal : repayAmount;
        require(usdc.transferFrom(borrower, address(this), amountToApply), "emergency transfer failed");
        loan.principal -= amountToApply;

        emit EmergencyRepaymentTriggered(borrower, amountToApply);

        if (loan.principal == 0) {
            _closeLoan(borrower, loan);
        }
    }

    /// @notice Soft liquidation: seize collateral worth exactly the debt being cleared (no penalty
    ///         beyond fair value), send it to treasury, and reduce the borrower's debt by the same
    ///         USDC-equivalent value. Any remaining collateral stays with the borrower's position.
    /// @param rwaToDeduct amount of collateral (18 decimals) the AI agent proposes to seize.
    function autoNettingRepay(address borrower, uint256 rwaToDeduct)
        external
        onlyAIAgent
        whenNotPaused
        nonReentrant
    {
        LoanPosition storage loan = loans[borrower];
        require(loan.isActive, "no active loan");
        _accrueInterest(loan);
        require(rwaToDeduct > 0 && rwaToDeduct <= loan.collateralAmount, "bad collateral amount");

        uint256 seizedValue = (rwaToDeduct * collateralPriceUSDC) / COLLATERAL_DECIMALS;
        uint256 debtReduction = seizedValue > loan.principal ? loan.principal : seizedValue;

        // If the requested seizure is worth more than the debt, only seize the proportional amount.
        uint256 actualSeized = seizedValue > 0
            ? (rwaToDeduct * debtReduction) / seizedValue
            : rwaToDeduct;

        loan.collateralAmount -= actualSeized;
        loan.principal -= debtReduction;

        require(rwaToken.transfer(treasury, actualSeized), "seize transfer failed");

        emit SoftLiquidationExecuted(borrower, actualSeized, debtReduction);

        if (loan.principal == 0) {
            _closeLoan(borrower, loan);
        }
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    function _accrueInterest(LoanPosition storage loan) internal {
        if (!loan.isActive || loan.principal == 0) {
            loan.lastAccrual = uint64(block.timestamp);
            return;
        }
        uint256 elapsed = block.timestamp - loan.lastAccrual;
        if (elapsed == 0) return;

        uint256 interest = (loan.principal * interestRateBps * elapsed) / (BPS_DENOMINATOR * YEAR_SECONDS);
        if (interest > 0) {
            loan.principal += interest;
        }
        loan.lastAccrual = uint64(block.timestamp);
    }

    function _closeLoan(address borrower, LoanPosition storage loan) internal {
        uint256 remainingCollateral = loan.collateralAmount;
        loan.isActive = false;
        loan.collateralAmount = 0;
        loan.flowRate = 0;

        if (remainingCollateral > 0) {
            require(rwaToken.transfer(borrower, remainingCollateral), "collateral return failed");
        }
        emit LoanClosed(borrower, remainingCollateral);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function getLoan(address borrower) external view returns (LoanPosition memory) {
        return loans[borrower];
    }

    /// @notice Debt including interest accrued since last settlement, without mutating state.
    function currentDebt(address borrower) external view returns (uint256) {
        LoanPosition memory loan = loans[borrower];
        if (!loan.isActive || loan.principal == 0) return loan.principal;
        uint256 elapsed = block.timestamp - loan.lastAccrual;
        uint256 interest = (loan.principal * interestRateBps * elapsed) / (BPS_DENOMINATOR * YEAR_SECONDS);
        return loan.principal + interest;
    }

    function healthFactorBps(address borrower) external view returns (uint256) {
        LoanPosition memory loan = loans[borrower];
        if (!loan.isActive || loan.principal == 0) return type(uint256).max;
        uint256 collateralValue = (loan.collateralAmount * collateralPriceUSDC) / COLLATERAL_DECIMALS;
        // health = (collateralValue * maxLTVBps / principal), 10000 = exactly at liquidation threshold
        return (collateralValue * maxLTVBps) / loan.principal;
    }
}

