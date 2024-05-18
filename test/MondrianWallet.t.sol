// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {console, Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MondrianWallet} from "../src/MondrianWallet.sol";
import {MockEntryPoint} from "../src/mocks/MockEntryPoint.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IEntryPoint} from "accountabstraction/contracts/interfaces/IEntryPoint.sol";

import {TargetContract} from "../src/TargetContract.sol";
import {IERC20Errors} from "@openzeppelin/contracts//interfaces/draft-IERC6093.sol";

import {UserOperationLib, PackedUserOperation} from "../src/MondrianWallet.sol";

contract MondrianTest is Test {
    //using UserOperationLib for PackedUserOperation;

    MondrianWallet wallet;

    MockEntryPoint entryPoint;
    MockERC20 erc20;
    IEntryPoint iEntryPoint;

    //Prank Addresses
    address user1;

    function setUp() public {
        entryPoint = new MockEntryPoint();
        wallet = new MondrianWallet(address(entryPoint));
        erc20 = new MockERC20();

        user1 = makeAddr("user1");
        vm.deal(user1, 10 ether);
    }

    function testWallet() public {
        iEntryPoint = wallet.getEntryPoint();
        assertEq(address(iEntryPoint), address(entryPoint));
    }

    function testAddDeposit() public {
        vm.prank(user1);
        wallet.addDeposit{value: 5 ether}();
        console.log("Mondrian Wallet Balance is:", address(wallet).balance);
        console.log("IEntryPoint Balance is:", address(entryPoint).balance);
    }

    // @audit OK
    function testWalletOwnerCallsExecute() public {
        address walletOwner = makeAddr("walletOwner");
        // user sets up a Mondrian Wallet
        vm.prank(walletOwner);
        MondrianWallet mondrian;
        mondrian = new MondrianWallet(address(entryPoint));

        // Prepare the data to call setValue on the TargetContract
        TargetContract target;
        target = new TargetContract();
        uint256 msgValue = 0;
        uint256 newValue = 42;
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", newValue);

        // Call the execute function on the MondrianWallet
        vm.prank(walletOwner);
        mondrian.execute(address(target), msgValue, data);
    }

    // @note @audit OK
    function testExecuteFails() public {
        address walletOwner = makeAddr("walletOwner");
        // user sets up a Mondrian Wallet
        vm.prank(walletOwner);
        MondrianWallet mondrian;
        mondrian = new MondrianWallet(address(entryPoint));

        // Prepare the data to call to the transfer() function on the MockERC20 contract
        address target = address(erc20);
        address transferTo = makeAddr("transferTo");
        uint256 amount = 1e18;
        uint256 msgValue = 0;
        bytes memory data;

        vm.prank(walletOwner);
        erc20.approve(address(mondrian), amount);

        console.log("walletOwner balance: ", erc20.balanceOf(walletOwner));
        console.log("Mondiran wallet balance: ", erc20.balanceOf(address(mondrian)));
        console.log("Mondrian allowance: ", erc20.allowance(walletOwner, address(mondrian)));

        // @note IN THE FUNCTION SIGNATURE DO NOT PLACE A SPACE AFTER THE COMMA
        data = abi.encodeWithSignature("transfer(address,uint256)", transferTo, amount);

        // Call the execute function on the MondrianWallet
        // Expect the call to revert with the specific error message
        vm.prank(walletOwner);
        bytes memory expectedRevertReason =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(mondrian), 0, amount);
        //  @note the line above is functionally equivalent to the line with @> below.
        // abi.encodeWithSelector uses the function selector directly.
        // This directly provides the 4-byte function selector for the custom error.
        // This method is more explicit and avoids potential errors in the function signature string.

        // @> abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", walletOwner, 0, amount);
        // abi.encodeWithSignature derives the function selector from the provided function signature string.
        // This method is more readable but requires the function signature string to be exactly correct, including spacing.

        vm.expectRevert(expectedRevertReason);
        mondrian.execute(target, msgValue, data);
    }

    // add import: import {UserOperationLib, PackedUserOperation} from "../src/MondrianWallet.sol";
    // add using:     using UserOperationLib for PackedUserOperation;
    // @audit bug
    function testMissingSignatureValidation() public {
        address nonOwner = makeAddr("nonOwner");

        // user sets up a Mondrian Wallet
        address owner = makeAddr("owner");
        vm.prank(owner);
        MondrianWallet mondrianWallet;
        mondrianWallet = new MondrianWallet(address(entryPoint));

        // Prepare the data to call mint on the MockERC20 contract
        bytes memory data = abi.encodeWithSignature("mint()");

        // Pack gas limits
        bytes32 packedGasLimits = packGasLimits(1000000, 100000);
        // Pack gas fees
        bytes32 packedGasFees = packGasFees(tx.gasprice, tx.gasprice);

        // Prepare the UserOperation - mondrianWallet will mint ERC20
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(mondrianWallet),
            nonce: 0, // this field is used to prevent replay attacks
            initCode: "", // if the sender address (the account that is initiating the operation) does not exist, the blockchain will use the initCode to deploy a new contract at the sender address. This new contract will act as the user's account.
            callData: abi.encodeWithSelector(mondrianWallet.execute.selector, address(erc20), 0, data),
            accountGasLimits: packedGasLimits,
            preVerificationGas: 21000,
            gasFees: packedGasFees,
            paymasterAndData: "",
            signature: new bytes(65) // @note placeholder, will be updated at line userOp.signature = abi.encodePacked(r, s, v);
        });

        // Non-owner signs the UserOperation with
        // signature field of UserOp (UserOp.signature) is populated here
        bytes32 userOpHash = keccak256(abi.encode(userOp));
        //(uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(owner)), userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(nonOwner)), userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        // Prepare UserOperation array
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        // ops[1] = userOp; // if this is added, trx will revert with error: FailedOp(1, "AA25 invalid account nonce")

        // @note if trying to make the call on the EntryPoint instance, i.e.
        // entryPoint.handleOps(ops, payable(owner)); an error would be thrown:
        // Invalid implicit conversion from struct PackedUserOperation[] memory to struct PackedUserOperation[] memory requested.

        // In IEntryPoint:         function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;
        // In MockEntryPoint:      function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;

        // While the function signatures are identical, using the IEntryPoint interface directly ensures strict adherence to the expected type and memory layout, thus avoiding potential type mismatch issues.
        iEntryPoint = mondrianWallet.getEntryPoint();
        iEntryPoint.handleOps(ops, payable(owner));

        // Verify that the tokens were minted correctly
        uint256 balance = erc20.balanceOf(address(mondrianWallet));
        assertEq(balance, erc20.AMOUNT());
    }

    function packGasLimits(uint256 callGasLimit, uint256 verificationGasLimit) internal pure returns (bytes32) {
        return bytes32((callGasLimit << 128) | verificationGasLimit);
    }

    function packGasFees(uint256 maxFeePerGas, uint256 maxPriorityFeePerGas) internal pure returns (bytes32) {
        return bytes32((maxFeePerGas << 128) | maxPriorityFeePerGas);
    }

    // @audit bug
    function testNoNftIsMinted() public {
        // user sets up a Mondrian Wallet
        address owner = makeAddr("owner");
        vm.prank(owner);
        MondrianWallet mondrianWallet;
        mondrianWallet = new MondrianWallet(address(entryPoint));

        bytes memory expectedRevertReason = abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0);

        //vm.expectRevert(expectedRevertReason);
        string memory art = mondrianWallet.tokenURI(0);
        //console.log("Art: ", art);

        uint256 balanceMW = mondrianWallet.balanceOf(address(mondrianWallet));
        uint256 balanceOwner = mondrianWallet.balanceOf(owner);

        console.log("Mondrian wallet balance: ", balanceMW);
        console.log("Owner balance: ", balanceOwner);
    }

    function testWhereDoesRefundGo() public {
        // user sets up a Mondrian Wallet
        address owner = makeAddr("owner");
        vm.prank(owner);
        MondrianWallet mondrianWallet;
        mondrianWallet = new MondrianWallet(address(entryPoint));

        // owner deposits eth to the entryPoint for its MondrianWallet account
        deal(owner, 10 ether);
        vm.prank(owner);
        mondrianWallet.addDeposit{value: 10 ether}();
        console.log("IEntryPoint Balance is:", address(entryPoint).balance);

        // Prepare the data to call mint on the MockERC20 contract
        bytes memory data = abi.encodeWithSignature("mint()");

        bytes32 packedGasLimits = packGasLimits(1000000, 100000);
        bytes32 packedGasFees = packGasFees(tx.gasprice, tx.gasprice);

        // Prepare the UserOperation - mondrianWallet will mint ERC20
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(mondrianWallet),
            nonce: 0, // this field is used to prevent replay attacks
            initCode: "", // if the sender address (the account that is initiating the operation) does not exist, the blockchain will use the initCode to deploy a new contract at the sender address. This new contract will act as the user's account.
            callData: abi.encodeWithSelector(mondrianWallet.execute.selector, address(erc20), 0, data),
            accountGasLimits: packedGasLimits,
            preVerificationGas: 21000,
            gasFees: packedGasFees,
            paymasterAndData: "",
            signature: new bytes(65) // @note placeholder, will be updated at line userOp.signature = abi.encodePacked(r, s, v);
        });

        // Non-owner signs the UserOperation with
        // signature field of UserOp (UserOp.signature) is populated here
        bytes32 userOpHash = keccak256(abi.encode(userOp));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(owner)), userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        // Prepare UserOperation array
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        // ops[1] = userOp; // if this is added, trx will revert with error: FailedOp(1, "AA25 invalid account nonce")

        // @note if trying to make the call on the EntryPoint instance, i.e.
        // entryPoint.handleOps(ops, payable(owner)); an error would be thrown:
        // Invalid implicit conversion from struct PackedUserOperation[] memory to struct PackedUserOperation[] memory requested.

        // In IEntryPoint:         function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;
        // In MockEntryPoint:      function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;

        // While the function signatures are identical, using the IEntryPoint interface directly ensures strict adherence to the expected type and memory layout, thus avoiding potential type mismatch issues.
        iEntryPoint = mondrianWallet.getEntryPoint();
        iEntryPoint.handleOps(ops, payable(owner));

        console.log("IEntryPoint Balance is:", address(entryPoint).balance);
    }
}
