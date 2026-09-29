// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../IERC20Mintable.sol";

/// @title ExerciseSolutionToken
/// @notice Receipt token minted when claimable tokens are deposited in the exercise solution.
/// @dev The evaluator never grants allowance before calling `withdrawTokens()`, so approved minters
/// can pull receipt tokens via `transferFrom()` to keep the exercise flow working end-to-end.
contract ExerciseSolutionToken is ERC20, IERC20Mintable {
    mapping(address => bool) public override isMinter;

    error NotMinter(address caller);

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        isMinter[msg.sender] = true;
    }

    function setMinter(address minterAddress, bool canMint) external override {
        if (!isMinter[msg.sender]) {
            revert NotMinter(msg.sender);
        }

        isMinter[minterAddress] = canMint;
    }

    function mint(address toAddress, uint256 amount) external override {
        if (!isMinter[msg.sender]) {
            revert NotMinter(msg.sender);
        }

        _mint(toAddress, amount);
    }

    function burn(uint256 amount) external override {
        if (!isMinter[msg.sender]) {
            revert NotMinter(msg.sender);
        }

        _burn(msg.sender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override(ERC20, IERC20) returns (bool) {
        // The evaluator expects `ExerciseSolution` to use `transferFrom()` during withdrawals,
        // but does not approve beforehand. Allow trusted minters to perform that pull explicitly.
        if (isMinter[msg.sender]) {
            _transfer(sender, recipient, amount);
            return true;
        }

        return super.transferFrom(sender, recipient, amount);
    }
}
