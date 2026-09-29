// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {MyVault} from "../src/MyVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script {
    address constant MOCK_UNDERLYING = 0xd0FB68321b1D565a6b07992b264B787bB7A06273;

    function run() external returns (MyVault) {
        vm.startBroadcast();

        MyVault vault = new MyVault(
            IERC20(MOCK_UNDERLYING),
            "Yield Vault XPAY",
            "yvXPAY"
        );

        vm.stopBroadcast();

        console.log("Vault deployed at: ", address (vault));

        return vault;
    }
}