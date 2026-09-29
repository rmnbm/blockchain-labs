// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyCryptoZoo.sol";

interface IEvaluator {
    function submitExercice(address) external;
    function ex1_testERC721() external;
    function ex2a_getAnimalToCreateAttributes() external;
    function ex2b_testDeclaredAnimal(uint animalNumber) external;
    function ex3_testRegisterBreeder() external;
    function ex4_testDeclareAnimal() external;
    function ex5_declareDeadAnimal() external;
    function ex6a_auctionAnimal_offer() external;
    function ex6b_auctionAnimal_buy(uint256) external;
    function readName(address) external view returns (string memory);
    function readLegs(address) external view returns (uint256);
    function readSex(address) external view returns (uint256);
    function readWings(address) external view returns (bool);
}

interface IEvaluator2 {
    function submitExercice(address) external;
    function ex7a_breedAnimalWithParents(uint parent1, uint parent2) external;
    function ex7b_offerAnimalForReproduction() external;
    function ex7c_payForReproduction(uint animalAvailableForReproduction) external;
}

contract SolveTD is Script {
    address constant EVALUATOR_ADDR = 0xa39ac9c5eF0582f5D0b21770e34c4c54d6e46Fa6;
    address constant EVALUATOR2_ADDR = 0xB6C6cf310456Bd0dEE01162A9150EC7ccA146936;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Your Contract
        MyCryptoZoo myZoo = new MyCryptoZoo();
        console.log("Deployed MyCryptoZoo at:", address(myZoo));

        // 2. Submit to Evaluator 1
        IEvaluator evaluator = IEvaluator(EVALUATOR_ADDR);
        evaluator.submitExercice(address(myZoo));
        console.log("Submitted to Evaluator 1");

        // --- Exercise 1 ---
        uint256 t1 = myZoo.declareAnimal(1, 4, false, "Genesis");
        // FIX: Use transferFrom instead of safeTransferFrom
        myZoo.transferFrom(deployerAddress, EVALUATOR_ADDR, t1);
        evaluator.ex1_testERC721();
        console.log("Passed Ex1");

        // --- Exercise 2 ---
        evaluator.ex2a_getAnimalToCreateAttributes();
        string memory name = evaluator.readName(deployerAddress);
        uint256 legs = evaluator.readLegs(deployerAddress);
        uint256 sex = evaluator.readSex(deployerAddress);
        bool wings = evaluator.readWings(deployerAddress);

        uint256 t2 = myZoo.declareAnimal(sex, legs, wings, name);
        // FIX: Use transferFrom instead of safeTransferFrom
        myZoo.transferFrom(deployerAddress, EVALUATOR_ADDR, t2);
        evaluator.ex2b_testDeclaredAnimal(t2);
        console.log("Passed Ex2");

        // --- Exercise 3 ---
        evaluator.ex3_testRegisterBreeder();
        console.log("Passed Ex3");

        // --- Exercise 4 ---
        evaluator.ex4_testDeclareAnimal();
        console.log("Passed Ex4");

        // --- Exercise 5 ---
        evaluator.ex5_declareDeadAnimal();
        console.log("Passed Ex5");

        // --- Exercise 6 ---
        evaluator.ex6a_auctionAnimal_offer();
        
        uint256 tSale = myZoo.declareAnimal(1, 4, false, "ForSale");
        myZoo.offerForSale(tSale, 0.0001 ether);
        evaluator.ex6b_auctionAnimal_buy(tSale);
        console.log("Passed Ex6");

        // -----------------------
        // --- Evaluator 2 ---
        // -----------------------
        IEvaluator2 evaluator2 = IEvaluator2(EVALUATOR2_ADDR);
        evaluator2.submitExercice(address(myZoo));
        console.log("Submitted to Evaluator 2");

        // --- Exercise 7a ---
        uint256 p1 = myZoo.declareAnimal(1, 4, false, "Parent1");
        uint256 p2 = myZoo.declareAnimal(0, 4, true, "Parent2");
        // FIX: Use transferFrom instead of safeTransferFrom
        myZoo.transferFrom(deployerAddress, EVALUATOR2_ADDR, p1);
        myZoo.transferFrom(deployerAddress, EVALUATOR2_ADDR, p2);
        
        evaluator2.ex7a_breedAnimalWithParents(p1, p2);
        console.log("Passed Ex7a");

        // --- Exercise 7b ---
        evaluator2.ex7b_offerAnimalForReproduction();
        console.log("Passed Ex7b");

        // --- Exercise 7c ---
        uint256 myStud = myZoo.declareAnimal(1, 4, true, "MyStud");
        uint256 reproPrice = 0.0001 ether;
        myZoo.offerForReproduction(myStud, reproPrice);
        
        // Fund Evaluator so it can pay us
        (bool success,) = EVALUATOR2_ADDR.call{value: 0.001 ether}(""); 
        require(success, "Failed to fund Evaluator");

        evaluator2.ex7c_payForReproduction(myStud);
        console.log("Passed Ex7c");

        vm.stopBroadcast();
    }
}