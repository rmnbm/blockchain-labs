// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {AllInOneSolution} from "../src/AllInOneSolution.sol";
import {Evaluator} from "../src/Evaluator.sol";
import {MockUnderlying} from "../src/MockUnderlying.sol";

contract DeployAllInOne is Script {
    address constant EVALUATOR = 0x8cA1290223ae888507D6A4c875420D82BE235c3D;
    address constant MOCK_UNDERLYING = 0xd0FB68321b1D565a6b07992b264B787bB7A06273;

    function run() external returns (AllInOneSolution) {
        vm.startBroadcast();

        AllInOneSolution solution = new AllInOneSolution(
            Evaluator(payable(EVALUATOR)),
            MockUnderlying(MOCK_UNDERLYING)
        );

        vm.stopBroadcast();

        console.log("AllInOneSolution deployed at: ", address(solution));

        return solution;
    }
}