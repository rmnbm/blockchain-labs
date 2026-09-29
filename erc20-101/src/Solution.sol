// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IExerciceSolution.sol";

contract ExerciceSolution is ERC20, IExerciceSolution {
    mapping(address => bool) public override isCustomerWhiteListed;
    mapping(address => uint256) public override customerTierLevel;
    address public owner;

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) ERC20(name_, symbol_) {
        owner = msg.sender;
        _mint(msg.sender, initialSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function symbol() public view override(ERC20, IExerciceSolution) returns (string memory) {
        return super.symbol();
    }

    function setWhitelist(address customer, bool isWhitelisted) external onlyOwner {
        isCustomerWhiteListed[customer] = isWhitelisted;
    }

    function setTier(address customer, uint256 tier) external onlyOwner {
        customerTierLevel[customer] = tier;
    }

    function getToken() external override returns (bool) {
        require(isCustomerWhiteListed[msg.sender], "Address not whitelisted");
        _mint(msg.sender, 100 ether); 
        return true;
    }

    function buyToken() external payable override returns (bool) {
        require(isCustomerWhiteListed[msg.sender], "Address not whitelisted");
        uint256 tier = customerTierLevel[msg.sender];
        require(tier > 0, "Tier level too low");

        uint256 amount = msg.value;
        if (tier == 2) {
            amount = amount * 2;
        }
        _mint(msg.sender, amount);
        return true;
    }
}
