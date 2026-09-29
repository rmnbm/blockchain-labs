// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../interfaces/IExerciseSolution.sol";
import "./../interfaces/IFlashLoanSimpleReceiver.sol";
import "./../interfaces/IPoolExtended.sol";
import {
    AAVE_POOL_ADDRESS,
    WBTC_ADDRESS,
    AETHWBTC_ADDRESS,
    USDC_ADDRESS,
    VARIABLE_DEBT_USDC_ADDRESS
} from "./../Constants.sol";

/// @title LendingExerciseSolution
/// @notice Complete Aave integration solution for the lending workshop.
/// @dev The contract is intentionally parameterized so the deploy script can tune values to whatever
/// faucet balances are available on the student's wallet.
contract LendingExerciseSolution is IExerciseSolution, IFlashLoanSimpleReceiver {
    IERC20 public immutable wbtc;
    IERC20 public immutable aEthWbtc;
    IERC20 public immutable usdc;
    IERC20 public immutable variableDebtUsdc;
    IPoolExtended public immutable aavePool;
    address public immutable evaluator;
    address public immutable owner;

    uint256 public depositAmount;
    uint256 public borrowAmount;
    uint256 public repayAmount;
    uint256 public withdrawAmount;

    uint256 public constant FLASH_LOAN_AMOUNT = 1_000_000 * 1e6;
    uint256 private constant VARIABLE_RATE_MODE = 2;

    error NotOwner(address caller);
    error UnexpectedCallback(address caller);

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    constructor(
        address evaluatorAddress,
        uint256 depositAmount_,
        uint256 borrowAmount_,
        uint256 repayAmount_,
        uint256 withdrawAmount_
    ) {
        evaluator = evaluatorAddress;
        owner = msg.sender;
        aavePool = IPoolExtended(AAVE_POOL_ADDRESS);
        wbtc = IERC20(WBTC_ADDRESS);
        aEthWbtc = IERC20(AETHWBTC_ADDRESS);
        usdc = IERC20(USDC_ADDRESS);
        variableDebtUsdc = IERC20(VARIABLE_DEBT_USDC_ADDRESS);

        depositAmount = depositAmount_;
        borrowAmount = borrowAmount_;
        repayAmount = repayAmount_;
        withdrawAmount = withdrawAmount_;
    }

    function configureAmounts(
        uint256 depositAmount_,
        uint256 borrowAmount_,
        uint256 repayAmount_,
        uint256 withdrawAmount_
    ) external onlyOwner {
        depositAmount = depositAmount_;
        borrowAmount = borrowAmount_;
        repayAmount = repayAmount_;
        withdrawAmount = withdrawAmount_;
    }

    function depositSomeTokens() external override {
        uint256 amount = depositAmount;
        require(wbtc.balanceOf(address(this)) >= amount, "Missing WBTC balance");

        wbtc.approve(address(aavePool), amount);
        aavePool.supply(WBTC_ADDRESS, amount, address(this), 0);
    }

    function borrowSomeTokens() external override {
        aavePool.borrow(
            USDC_ADDRESS,
            borrowAmount,
            VARIABLE_RATE_MODE,
            0,
            address(this)
        );
    }

    function repaySomeTokens() external override {
        uint256 debt = variableDebtUsdc.balanceOf(address(this));
        uint256 amount = repayAmount;

        if (amount > debt) {
            amount = debt;
        }

        require(amount > 0, "No debt to repay");
        require(usdc.balanceOf(address(this)) >= amount, "Missing USDC balance");

        usdc.approve(address(aavePool), amount);
        aavePool.repay(USDC_ADDRESS, amount, VARIABLE_RATE_MODE, address(this));
    }

    function withdrawSomeTokens() external override {
        uint256 aTokenBalance = aEthWbtc.balanceOf(address(this));
        uint256 amount = withdrawAmount;

        if (amount > aTokenBalance) {
            amount = aTokenBalance;
        }

        require(amount > 0, "No collateral to withdraw");
        aavePool.withdraw(WBTC_ADDRESS, amount, address(this));
    }

    function doAFlashLoan() external override {
        aavePool.flashLoanSimple(
            evaluator,
            USDC_ADDRESS,
            FLASH_LOAN_AMOUNT,
            bytes(""),
            0
        );
    }

    function repayFlashLoan() external override {
        usdc.approve(address(aavePool), type(uint256).max);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address,
        bytes calldata
    ) external override returns (bool) {
        if (msg.sender != evaluator) {
            revert UnexpectedCallback(msg.sender);
        }

        require(asset == USDC_ADDRESS, "Unexpected flash-loan asset");
        require(amount == FLASH_LOAN_AMOUNT, "Unexpected flash-loan amount");
        require(
            usdc.balanceOf(address(this)) >= amount + premium,
            "Not enough USDC to repay flash loan"
        );

        usdc.approve(address(aavePool), amount + premium);
        return true;
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}
