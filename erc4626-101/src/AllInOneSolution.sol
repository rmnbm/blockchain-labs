// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAllInOneSolution} from "./IAllInOneSolution.sol";
import {Evaluator} from "./Evaluator.sol";
import {MockUnderlying} from "./MockUnderlying.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MyVault} from "./MyVault.sol";
import {IExerciceSolution} from "./IExerciceSolution.sol";


contract AllInOneSolution is IAllInOneSolution {
    Evaluator public evaluator;
    MockUnderlying public underlying;

    constructor(Evaluator _evaluator, MockUnderlying _underlying) {
        evaluator = _evaluator;
        underlying = _underlying;
    }


    function completeWorkshop() external {
        evaluator.ex1_getVaultParameters();

        string memory assignedName = evaluator.readName(address(this));
        string memory assignedSymbol = evaluator.readSymbol(address(this));

        MyVault vault = new MyVault(IERC20(address(underlying)), assignedName, assignedSymbol);

        evaluator.submitExercice(IExerciceSolution(address(vault)));

        evaluator.ex2_testVaultDeployment();

        evaluator.ex3_testDeposit();
        evaluator.ex4_testMint();
        evaluator.ex5_testWithdraw();
        evaluator.ex6_testRedeem();
        evaluator.ex7_testPreviewConsistency();
        evaluator.ex8_testYield();
        evaluator.ex9_testMaxFunctions();
    }

    function run() external {
        evaluator.ex10_allInOne();
    }
}