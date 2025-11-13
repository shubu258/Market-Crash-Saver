// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MarketInvest} from "../src/MarketInvest.sol";

contract MarketInvest is Test {
    MarketInvest public counter;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }

    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Counter.sol";

contract CounterTest is Test {
    Counter counter;

    function setUp() public {
        counter = new Counter();
    }

    // 👉 You will write your tests here

    function testIncrement() public {
        assertEq(counter.count(), 0);
        counter.increment();
        assertEq(counter.count(), 1);
    } 


    funcation testDecrement() public {

        counter.set(2);

        counter.decrement();
        assertEq(counter.count(), 1);
    }

    function testrevert() public {
        assertEq(counter.count(), 0);

        vm.expectRevert("underflow");
        counter.decrement();
    }

}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank bank;
    address user = address(1);
    address user2 = address(2);

    function setUp() public {
        bank = new Bank();
        deal(user, 10 ether);
        deal(user2, 10 ether);
    }

    // write tests here

    function testDeposit() public {
        vm.prank(user);

        vm.expectEmit(true, treue , false, true);
        emit deposit(user, 1 ether);

        bank.deposit{value: 1 ether}();

        assertEq(bank.balances(user), 1 ether);
    }

    function testZeroRevert() public {

        vm.prank(user);

        vm.expectRevert("sero value");
        bank.deposit{value: 0 ether}; 

    }

    function testWithdraw() public {

        deal(user, 5 ether);

        vm.prank(user);
        bank.deposit{value: 2 ether}();
        uint256 userbalance = user.balance();
        
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit withdraw(user, 1ether);

        bank.withdraw{1 ether}();

        assertEq(bank.balances(user), before + 1 ether);
    }

    function testwithdrawrevert() public {
        deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert("underflow");
        bank.withdraw{1 ether}(); 
    }

    function testDepositMultipleUser() public {
        deal(user, 2 ether);
        vm.prank(user);
        bank.deposit{value : 1 ether}();
        assertEq(bank.balances(user), 1 ether);

        deal(user2, 2 ether);
        vm.prank(user2);
        bank.deposit{value: 1 ether}();
        assertEq(bank.balances(user2), 1 ether);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    Vault vault;
    address owner = address(this);
    address user = address(0x1);

    function setUp() public {
        vault = new Vault();
        deal(address(this), 10 ether);
        deal(user, 10 ether);
    }

    // Your tests here

    function userWithdraw() public {
        vm.prank(user, 1 ether);
        vm.expectRevert(notOwner.selector);
        valut.withdraw(1 ether);
    }

    function testWithdrawLocked() public {
        address user = owner;
        vm.prank(user);

        vault.deposit{value : 1 ether}();

        vm.expectRevert(WithdrawLocked.selector);
        vault.withdraw(1 ether);
    }

    function testWithdrawSuccess() public {
        vm.prank(owner);
        vault.deposit{value: 5 ether}();
        uint256 before = owner.balance();

        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(owner);
        vault.withdraw(3 ether);

        assertEq(owner.balance(), before + 3 ether);
        assertEq(vault.balance(), 2 ether);
    }

    function testAnyonePay() public {

        vm.prank(user);
        vault.deposit{value: 1 ether}();
        assertEq(vault.balance(), 1 ether);
        uint256 before = vault.balance();


        vm.prank(user2);
        vault.deposit{value: 1 ether}();
        assertEq(vault.balance(), before + 1 ether);
    }
}













// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenVault.sol";

// Mock ERC20 (very simple)
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
    function approve(address spender, uint256 amount) external returns (bool) {
        return true;
    }
}

// Mock Oracle
contract MockOracle {
    uint256 public price = 600;
    function setPrice(uint256 p) external {
        price = p;
    }
    function getPrice() external view returns (uint256) {
        return price;
    }
}

contract TokenVaultTest is Test {
    TokenVault vault;
    MockERC20 token;
    MockOracle oracle;

    address user = address(1);
    address user2 = address(2);
    address owner;

    function setUp() public {
        owner = address(this);

        token = new MockERC20();
        oracle = new MockOracle();

        vault = new TokenVault(address(token), address(oracle));

        // Give user tokens
        token.mint(user, 1000 ether);
        token.mint(user2, 1000 ether);
    }

    // -------------------------
    // YOUR TESTS START HERE
    // -------------------------

    // example:
    // function testDepositSuccess() public {
    //     ...
    // }
    function testDepositSuccess() public {
        vm.prank(user);
        token.approve{address(vault), 100 ether};

        oracle.setPrice(600);
        
        uint256 before = vault.balances();
        vm.prank(user);
        vault.deposit{100 ether}();
        assertEq(vault.balances(user), before + 100 ether);

        assertEq(token.balanceOf(address(vault)), 100 ether);
        assertEq(token.balanceOf(user), 900 ether);
    }

    function testDepositPriceReverts() public {

        set.oracle(400);

        vm.prank(user);
        expectRevert("price too low");
        vault.deposit{value: 50 ether}();
    }

    function testWithdrawBeforeLockReverts() public {
        vm.prank(owner);
        vault.setLockTime(1000);

        vm.prank(user);
        token.approve(address(vault), 100 ether);

        vm.prank(user);
        vault.deposit(100 ether);
        assertEq(vault.balances(user), 100);
        
        vm.warp(block.timestamp + 10);

        vm.prank(user);
        vm.expectRevert(LockActive.selector);
        vault.withdraw(100 ether);

    }

    function testWithdrawSufficientBalance() public {

        vm.prank(user);
        token.approve(address(vault), 100 ether);

        vm.prank(user);
        vault.deposit(50 ether);

        vm.warp(block.timestamp + 10000);
        vm.expectRevert(InsufficientBalance.selector);
        vault.withdraw(100 ether); 
    }

    function testWithdrawSuccess() public {

        vm.prank(user);
        token.approve(address(vault), 1000 ether);

        vm.prank(user);
        vault.deposit( 200 ether);
        assertEq(vault.balance(user), 200);

        vm.prank(owner);
        vault.setLockTime( 1 day);
        
        uint256 before = vault.balances();
        vm.warp(block.timestamp + 1 day + 1 );

        vm.prank(user);
        vault.withdraw( 100 ether);
        assertEq(token.balance(user), before + 100 ether);

    }



}


}
