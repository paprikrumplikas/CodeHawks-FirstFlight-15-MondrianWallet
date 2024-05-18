// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract TargetContract {
    uint256 public storedValue;

    event ValueChanged(uint256 newValue);

    function setValue(uint256 newValue) external {
        storedValue = newValue;
        emit ValueChanged(newValue);
    }
}
