// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IClaimableERC20 is IERC20 {
    function claimTokens() external returns (uint256);
}
