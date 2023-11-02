// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// import "forge-std/Test.sol";
// import "src/EGLX.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// contract EGLXTest is Test {
//     EGLX perp;
//     ERC20Mock usdc;

//     address alice;
//     address bob;

//     function setUp() public {
//         usdc = new ERC20Mock();
//         perp = new EGLX(IERC20(address(usdc)));

//         alice = makeAddr("alice");
//         bob = makeAddr("bob");

//         usdc.mint(alice, 5e18);
//         usdc.mint(bob, 6e18);
//     }

//     function _provideLiquidity(
//         address user,
//         uint256 amount
//     ) internal returns (uint256) {
//         vm.startPrank(user);
//         usdc.approve(address(perp), amount);
//         perp.deposit(amount, user);
//         vm.stopPrank();
//     }

//     function test_ProvideLiquidity() public {
//         _provideLiquidity(alice, 5e18);
//     }
// }
