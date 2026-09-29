// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IExerciseSolution} from "../src/interfaces/IExerciseSolution.sol";
import {IPoolExtended} from "../src/interfaces/IPoolExtended.sol";
import {LendingExerciseSolution} from "../src/solutions/LendingExerciseSolution.sol";
import {
    AAVE_POOL_ADDRESS,
    AAVE_FAUCET_ADDRESS,
    WBTC_ADDRESS,
    USDC_ADDRESS
} from "../src/Constants.sol";

interface IAaveFaucet {
    function mint(address token, address to, uint256 amount) external returns (uint256);
}

interface ILendingEvaluator {
    function ex1_showIDepositedTokens() external;
    function ex2_showIBorrowedTokens() external;
    function ex3_showIRepaidTokens() external;
    function ex4_showIWithdrewTokens() external;
    function submitExercise(IExerciseSolution studentExercise_) external;
    function ex5_showContractCanDepositTokens() external;
    function ex6_showContractCanBorrowTokens() external;
    function ex7_showContractCanRepayTokens() external;
    function ex8_showContractCanWithdrawTokens() external;
}

/// @notice One-shot script for the lending workshop.
/// @dev You still need faucet balances on the broadcasting wallet before running it.
contract SolveLending101 is Script {
    uint256 private constant DEFAULT_WALLET_WBTC_DEPOSIT = 1e6; // 0.01 WBTC
    uint256 private constant DEFAULT_WALLET_USDC_BORROW = 100e6; // 100 USDC
    uint256 private constant DEFAULT_CONTRACT_WBTC_DEPOSIT = 2e6; // 0.02 WBTC
    uint256 private constant DEFAULT_CONTRACT_USDC_BORROW = 10e6; // 10 USDC
    uint256 private constant DEFAULT_CONTRACT_USDC_REPAY = 10e6; // Full repay keeps the position simple and robust
    uint256 private constant DEFAULT_CONTRACT_WBTC_WITHDRAW = 1e5; // 0.001 WBTC

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address broadcaster = vm.addr(privateKey);
        address payable evaluatorAddress = payable(vm.envOr(
            "LENDING_101_EVALUATOR",
            address(0xD53EF6272e8df4d3e7c79568A7ea11FA444a438a)
        ));

        uint256 walletDepositAmount = vm.envOr(
            "WALLET_WBTC_DEPOSIT_AMOUNT",
            DEFAULT_WALLET_WBTC_DEPOSIT
        );
        uint256 walletBorrowAmount = vm.envOr(
            "WALLET_USDC_BORROW_AMOUNT",
            DEFAULT_WALLET_USDC_BORROW
        );
        uint256 contractDepositAmount = vm.envOr(
            "CONTRACT_WBTC_DEPOSIT_AMOUNT",
            DEFAULT_CONTRACT_WBTC_DEPOSIT
        );
        uint256 contractBorrowAmount = vm.envOr(
            "CONTRACT_USDC_BORROW_AMOUNT",
            DEFAULT_CONTRACT_USDC_BORROW
        );
        uint256 contractRepayAmount = vm.envOr(
            "CONTRACT_USDC_REPAY_AMOUNT",
            DEFAULT_CONTRACT_USDC_REPAY
        );
        uint256 contractWithdrawAmount = vm.envOr(
            "CONTRACT_WBTC_WITHDRAW_AMOUNT",
            DEFAULT_CONTRACT_WBTC_WITHDRAW
        );

        ILendingEvaluator evaluator = ILendingEvaluator(evaluatorAddress);
        IPoolExtended pool = IPoolExtended(AAVE_POOL_ADDRESS);
        IERC20 wbtc = IERC20(WBTC_ADDRESS);
        IERC20 usdc = IERC20(USDC_ADDRESS);
        IAaveFaucet faucet = IAaveFaucet(AAVE_FAUCET_ADDRESS);

        uint256 totalWbtcNeeded = walletDepositAmount + contractDepositAmount;

        vm.startBroadcast(privateKey);

        // The Aave Sepolia WBTC token is faucet-controlled, so we top up only the missing amount.
        uint256 currentWbtcBalance = wbtc.balanceOf(broadcaster);
        if (currentWbtcBalance < totalWbtcNeeded) {
            faucet.mint(WBTC_ADDRESS, broadcaster, totalWbtcNeeded - currentWbtcBalance);
        }

        // Wallet-side exercises (ex1 -> ex4)
        wbtc.approve(AAVE_POOL_ADDRESS, walletDepositAmount);
        pool.supply(WBTC_ADDRESS, walletDepositAmount, broadcaster, 0);
        evaluator.ex1_showIDepositedTokens();

        pool.borrow(USDC_ADDRESS, walletBorrowAmount, 2, 0, broadcaster);
        evaluator.ex2_showIBorrowedTokens();

        usdc.approve(AAVE_POOL_ADDRESS, walletBorrowAmount);
        pool.repay(USDC_ADDRESS, walletBorrowAmount, 2, broadcaster);
        evaluator.ex3_showIRepaidTokens();

        pool.withdraw(WBTC_ADDRESS, walletDepositAmount, broadcaster);
        evaluator.ex4_showIWithdrewTokens();

        // Contract-side exercises (ex5 -> ex9)
        LendingExerciseSolution solution = new LendingExerciseSolution(
            evaluatorAddress,
            contractDepositAmount,
            contractBorrowAmount,
            contractRepayAmount,
            contractWithdrawAmount
        );

        require(
            wbtc.transfer(address(solution), contractDepositAmount),
            "WBTC transfer to solution failed"
        );

        evaluator.submitExercise(solution);
        evaluator.ex5_showContractCanDepositTokens();
        evaluator.ex6_showContractCanBorrowTokens();
        evaluator.ex7_showContractCanRepayTokens();
        evaluator.ex8_showContractCanWithdrawTokens();

        // The flash-loan step in the published workshop is not actually executable as written:
        // Aave's flashLoanSimple pulls repayment from `receiverAddress`, but the evaluator is
        // used as the receiver and never approves the pool. We therefore stop after ex8 and
        // leave the contract-side flash-loan implementation in place for when the evaluator is fixed.

        vm.stopBroadcast();
    }
}
