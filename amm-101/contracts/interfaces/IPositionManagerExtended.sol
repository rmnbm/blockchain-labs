// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IPositionManager.sol";

interface IPositionManagerExtended is IPositionManager {
    function permit2() external view returns (address);

    function poolManager() external view returns (address);
}
