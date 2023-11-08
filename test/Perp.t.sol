// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/Perp.sol";
import "src/MockOracle.sol";
import "src/Pool.sol";
import "src/lib/helpers.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract PerpXTest is Test {
    Perp perp;
    MockV3Aggregator oracle;
    ERC20Mock usd;
    Pool pool;

    address public alice; // Long Trader
    address public bob; // Short Trader
    address public charlie; //Liquidity provider 1
    address public dave; //Liquidity provider 2

    function setUp() public {
        //Create Addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        dave = makeAddr("dave");

        //Environment Setup
        usd = new ERC20Mock(); //Asset that is deposited by LPs + Collateral provided by traders
        oracle = new MockV3Aggregator(18, 3500e18); // 1 BTC = 3500 USD
        perp = new Perp(address(oracle), address(usd), 10);
        pool = perp.pool();

        //Add funds to addresses
        usd.mint(alice, 50000e18);
        usd.mint(bob, 50000e18);
        usd.mint(charlie, 50000e18);
        usd.mint(dave, 50000e18);
    }

    /**
     * @dev
     * Provide liquidity
     */
    function test_ProvideLiquidity() public {
        uint256 charlieShares = _provideLiquidity(charlie, 5000e18);
        uint256 daveShares = _provideLiquidity(dave, 5000e18);
        assert(charlieShares == 5000e18);
        assert(daveShares == 5000e18);
    }

    function _provideLiquidity(
        address user,
        uint256 amount
    ) internal returns (uint256 shares) {
        vm.startPrank(user);
        usd.approve(address(pool), amount);
        shares = pool.deposit(amount, user);
        vm.stopPrank();
    }

    /**
     * @dev
     * Open a position
     *      Can open a position if enough liquidity & Collateral
     *      Cannot open a position if not enough liquidity
     *      Cannot open a position if not enough collateral
     */
    function test_openPosition_enoughCollateral() public {
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Alice opens a Long with size of 5 BTC
        vm.startPrank(alice);
        usd.approve(address(perp), 2000e18);
        perp.openPosition(5e8, 2000e18, PositionType.Long);
        vm.stopPrank();
        (
            PositionType positionType,
            uint256 size,
            uint256 collateral,
            uint256 openPrice,
            bool isOpen
        ) = perp.positions(address(alice));

        assert(positionType == PositionType.Long);
        assert(size == 5e8);
        assert(collateral == 2000e18);
        assert(openPrice == 3500e18);
        assert(isOpen == true);

        // string memory posType = uint(positionType) == 0 ? "Long" : "Short";
        // console.log("Position Type: %s", posType);
        // console.log("Position Size: %s BTC", size / 1e8);
        // console.log("Collateral Size: %s USDC", collateral / 1e18);
        // console.log("Opening price of position: %s USDC", openPrice / 1e18);
        // console.log("Position Value: %s USDC", (size * openPrice) / 1e26);
        // console.log("Is position open: %s", isOpen);
    }

    function test_openPosition_notEnoughCollateral() public {
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Alice opens a Long with size of 5 BTC but does not provide enough collateral
        vm.startPrank(alice);
        usd.approve(address(perp), 1000e18);
        vm.expectRevert();
        perp.openPosition(5e8, 2000e18, PositionType.Long);
        vm.stopPrank();
    }

    function test_openPosition_notEnoughLiquidity() public {
        //Add liquidity to Pool
        _provideLiquidity(charlie, 500e18);

        //Alice opens a Long with size of 5 BTC but does not provide enough collateral
        vm.startPrank(alice);
        usd.approve(address(perp), 1000e18);
        vm.expectRevert();
        perp.openPosition(5e8, 2000e18, PositionType.Long);
        vm.stopPrank();
    }

    /**
     * @dev
     * Add more collateral
     */

    function test_addCollateral() public {
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Alice opens a Long with size of 5 BTC
        vm.startPrank(alice);
        usd.approve(address(perp), 5000e18);
        perp.openPosition(5e8, 2000e18, PositionType.Long);

        //Alice increases the collateral by 1000 USD
        perp.increaseCollateral(1000e18);
        vm.stopPrank();

        (, , uint256 collateral, , ) = perp.positions(address(alice));

        assert(collateral == 3000e18);
    }

    /**
     * @dev
     * Withdraw liquidity
     *      Can withdraw unreserved liquidity
     *      Cannot withdraw reserved liquidity
     */

    function test_canWithdrawAvailableLiquidity() public {
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Alice opens a Long with size of 5 BTC
        vm.startPrank(alice);
        usd.approve(address(perp), 2000e18);
        perp.openPosition(5e8, 2000e18, PositionType.Long);
        vm.stopPrank();

        assert(usd.balanceOf(charlie) == 0);
        vm.prank(charlie);
        pool.withdraw(50000e18, charlie, charlie);
        //assert(usd.balanceOf(charlie) == 50000e18);
    }

    function test_cannotWithdrawReservedLiquidity() public {
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Alice opens a Long with size of 5 BTC
        vm.startPrank(alice);
        usd.approve(address(perp), 8000e18);
        perp.openPosition(20e8, 8000e18, PositionType.Long);
        vm.stopPrank();

        vm.prank(charlie);
        vm.expectRevert();
        pool.withdraw(50000e18, charlie, charlie);
    }

    /**
     * @dev
     * Close position
     *       Long -> +PnL
     *       Long -> -PnL
     *       Short -> +PnL
     *       Short -> -PnL
     */

    function test_LongPositivePnL() public {
        uint prevBal = usd.balanceOf(alice);
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Alice opens a Long with size of 5 BTC
        vm.startPrank(alice);
        usd.approve(address(perp), 5000e18);
        perp.openPosition(5e8, 2000e18, PositionType.Long);

        //Price of BTC increases by 20%
        oracle.updateAnswer(4200e18);

        //Alice closes her position to realise the profit
        perp.closePosition();
        uint newBal = usd.balanceOf(alice);
        assert(newBal > prevBal);
    }

    function test_LongNegativePnL() public {
        uint prevBal = usd.balanceOf(alice);
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Alice opens a Long with size of 5 BTC
        vm.startPrank(alice);
        usd.approve(address(perp), 5000e18);
        perp.openPosition(5e8, 2000e18, PositionType.Long);

        //Price of BTC decreases by ~8%
        oracle.updateAnswer(3200e18);

        //Alice closes her position and is in loss
        perp.closePosition();
        uint newBal = usd.balanceOf(alice);
        assert(newBal < prevBal);
    }

    function test_ShortPositivePnL() public {
        uint prevBal = usd.balanceOf(bob);
        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Bob opens a Short with size of 5 BTC
        vm.startPrank(bob);
        usd.approve(address(perp), 5000e18);
        perp.openPosition(5e8, 2000e18, PositionType.Short);

        //Price of BTC decreases
        oracle.updateAnswer(3300e18);

        //Bob closes his position to realise the profit
        perp.closePosition();
        uint newBal = usd.balanceOf(bob);
        assert(newBal > prevBal);
    }

    function test_ShortNegativePnL() public {
        uint prevBal = usd.balanceOf(bob);

        //Add liquidity to Pool
        _provideLiquidity(charlie, 50000e18);
        _provideLiquidity(dave, 50000e18);

        //Bob opens a Short with size of 5 BTC
        vm.startPrank(bob);
        usd.approve(address(perp), 5000e18);
        perp.openPosition(5e8, 2000e18, PositionType.Short);

        //Price of BTC increases
        oracle.updateAnswer(3700e18);

        //Bob closes his position and is in loss
        perp.closePosition();
        uint newBal = usd.balanceOf(bob);
        assert(newBal < prevBal);
    }
}
