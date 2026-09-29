// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/Evaluator.sol";
import "../src/Solution.sol";

contract SolveTD is Script {
    
    // Sepolia Address
    address constant EVALUATOR_ADDR = 0x05A644d6d9BBd85861ff927245aaC13bd56e6d57;

    function run() external {

        vm.startBroadcast();

        Evaluator evaluator = Evaluator(payable(EVALUATOR_ADDR));
        address monWallet = msg.sender;

        //setup
        evaluator.ex0_setupProject();
        console.log("Ex0 Valide");

        //ex1
        
        evaluator.ex1_getTickerAndSupply();
        string memory name = evaluator.readTicker(monWallet);
        string memory symbol = evaluator.readTicker(monWallet);
        uint256 supply = evaluator.readSupply(monWallet);
        console.log("Ticker recupere:", symbol);

        
        ExerciceSolution myToken = new ExerciceSolution(name, symbol, supply);
        console.log("Token deploye a:", address(myToken));

        //ex2
        evaluator.submitExercice(myToken);
        evaluator.ex2_testErc20TickerAndSupply();
        console.log("Ex2 Valide");

        //ex3
        myToken.setWhitelist(address(evaluator), true);
        evaluator.ex3_testGetToken();
        console.log("Ex3 Valide");

        //ex4
        myToken.setTier(address(evaluator), 1);
        evaluator.ex4_testBuyToken();
        console.log("Ex4 Valide");

        //ex5
        myToken.setWhitelist(address(evaluator), false);
        evaluator.ex5_testDenyListing();
        console.log("Ex5 Valide");

        //ex6
        myToken.setWhitelist(address(evaluator), true);
        evaluator.ex6_testAllowListing();
        console.log("Ex6 Valide");

        //ex7
        myToken.setWhitelist(address(evaluator), false);
        myToken.setTier(address(evaluator), 0); 
        evaluator.ex7_testDenyListing();
        console.log("Ex7 Valide");

        //ex8
        myToken.setWhitelist(address(evaluator), true);
        myToken.setTier(address(evaluator), 1);
        evaluator.ex8_testTier1Listing();
        console.log("Ex8 Valide");

        //ex9
        myToken.setTier(address(evaluator), 2);
        evaluator.ex9_testTier2Listing();
        console.log("Ex9 Valide");

        
        vm.stopBroadcast();
    }
}