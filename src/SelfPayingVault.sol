// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ArcRWASelfPayingVault is ReentrancyGuard {
    address public owner;
    IERC20 public immutable usdc;
    IERC20 public immutable rwaToken;
    uint256 public collateralPriceUSDC;
    
    struct Loan { uint256 collateral; uint256 principal; uint256 flowRate; uint64 lastAccrual; bool active; }
    mapping(address => Loan) public loans;

    constructor(address _usdc, address _rwa, uint256 _price) {
        owner = msg.sender; usdc = IERC20(_usdc); rwaToken = IERC20(_rwa); collateralPriceUSDC = _price;
    }

    function depositAndBorrow(uint256 amountRWA, uint256 amountUSDC) external nonReentrant {
        require(rwaToken.transferFrom(msg.sender, address(this), amountRWA), "Transfer failed");
        loans[msg.sender] = Loan(amountRWA, amountUSDC, 0, uint64(block.timestamp), true);
        require(usdc.transfer(msg.sender, amountUSDC), "USDC failed");
    }
}
