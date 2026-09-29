// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IExerciceSolution.sol";

contract Evaluator {
    function ex0_setupProject() external {}
    function ex1_getTickerAndSupply() external {}
    function readTicker(address student) external view returns (string memory) { return ""; }
    function readSupply(address student) external view returns (uint256) { return 0; }
    function submitExercice(IExerciceSolution studentExercice) external {}
    function ex2_testErc20TickerAndSupply() external {}
    function ex3_testGetToken() external {}
    function ex4_testBuyToken() external {}
    function ex5_testDenyListing() external {}
    function ex6_testAllowListing() external {}
    function ex7_testDenyListing() external {}
    function ex8_testTier1Listing() external {}
    function ex9_testTier2Listing() external {}
    function ex10_allInOne() external {}
}
