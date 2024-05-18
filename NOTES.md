1. Info on ERC-4337:
   1. https://www.youtube.com/watch?v=OwppworJGzs
   2. https://cointelegraph.com/learn/account-abstraction-guide-to-ethereums-erc-4337-standard
   3. https://medium.com/@0xasdf_eth/a-complete-guide-on-account-abstraction-b885542e7552
   4. https://www.argent.xyz/blog/wtf-is-account-abstraction/

2. To log raw bytes, use                 
`console.logBytes(result); // Log raw result for debugging`

3. It's possible that the issue was related to a caching or state problem within Foundry, which sometimes can be resolved by rebuilding or recompiling the project. Here are a few potential reasons why the issue might have resolved itself:
   - Recompilation and Caching: Sometimes, changes in the codebase are not fully picked up due to caching mechanisms. A complete rebuild can often clear these caches and ensure that the latest code is being executed.
   - State Reset: Running the tests repeatedly and making modifications can sometimes lead to an inconsistent state. Restarting the testing environment can reset the state and resolve such issues.
   - Incremental Compilation Issues
To resolve this, run:
`forge clean`
`forge build`


4.      bytes memory expectedRevertReason =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(mondrian), 0, amount);
        //  @note the line above is functionally equivalent to the line with @> below.
        // abi.encodeWithSelector uses the function selector directly.
        // This directly provides the 4-byte function selector for the custom error.
        // This method is more explicit and avoids potential errors in the function signature string.

        // @> abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", walletOwner, 0, amount);
        // abi.encodeWithSignature derives the function selector from the provided function signature string.
        // This method is more readable but requires the function signature string to be exactly correct, including spacing.


5. The PackedUserOperation struct you're using is a more compact representation of a user operation. Here’s how you can structure the values for accountGasLimits and gasFees:

accountGasLimits: This typically packs multiple gas limit values into a single bytes32 field. For example, it might include the callGasLimit and verificationGasLimit.
gasFees: This field typically packs gas fee values such as maxFeePerGas and maxPriorityFeePerGas.


6. The current MondrianWallet.sol relies on ECDSA signatures for validating UserOperations.
ECDSA signatures require a private key, which is typically associated with an EOA.
Therefore, without modification, you cannot sign a UserOperation without an EOA. The validation logic requires a signature generated from a private key (EOA).


7. n your specific case with MondrianWallet, the validateUserOp function is being implemented to match the declaration in the IAccount interface. Here’s why you need to use override:
Key Points:
Interface Implementation: When implementing an interface, you need to indicate that the function is intended to fulfill the contract's interface requirement. This is done using the override keyword.
Compiler Check: The override keyword ensures that the Solidity compiler checks that the function signature matches the one declared in the interface. This helps catch errors early and ensures that your contract correctly implements the interface.


8. To get a full coverage report on which lines were covered and which not:
   1. `forge coverage --report lcov`
   2. `genhtml -o coverage lcov.info`
   3. locate coverage folder
      1. Locate index.html
      2. right clivk -> open with live server





