// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "lib/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "lib/forge-std/src/Test.sol";

contract MockERC20 is ERC20 {
    uint256 public constant AMOUNT = 1e18;

    constructor() ERC20("Mock ERC20", "MERC") {}

    function mint() external {
        _mint(msg.sender, AMOUNT);
        console.log("Minted", AMOUNT, "tokens to", msg.sender);
    }

    function transfer(address to, uint256 value) public virtual override returns (bool) {
        console.log("Entering transfer function");
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
}
