# `PerpX` Documentation

## Overview

- The `PerpX` protocol serves as an advanced trading platform for users interested in taking leveraged long or short positions on various assets. It allows traders to interact with a decentralized market without owning the underlying asset directly.
- By using an external price feed oracle, the protocol ensures that the prices for assets are accurate and up to date.
- In addition to trading functionalities, the protocol includes features for liquidity providers to participate in the market by supplying liquidity.

## Dependencies

- **IERC20 Interface**: Provided by OpenZeppelin, this is a standard interface for ERC20 tokens, allowing the protocol to interact with any compliant token assets.
- **SafeERC20 Library**: This OpenZeppelin library provides safe methods for interacting with ERC20 tokens that correctly implement the IERC20 interface, guarding against reentrancy and other common issues.
- **AggregatorV3Interface Contract**: A custom interface for an external oracle that provides reliable price feeds for the protocol to use in its calculations.
- **Pool Contract**: A separate contract that manages the liquidity provisions, ensuring that liquidity can be added to or removed from the system in a controlled manner.

## Contracts

### Perp.sol

Here's a brief explanation of its functionality:

1. **Contract Initialization**: The `Perp` contract initializes with references to an Oracle and an Asset (presumably a token) along with a maximum leverage value. It also creates a `Pool` contract instance that handles liquidity.

2. **Opening Positions**: Users can open long or short positions by specifying the size and collateral. The position size cannot exceed the collateral times the maximum leverage. When a position is opened, the appropriate amount of the asset is transferred from the user to the contract and recorded.

3. **Increasing Position Size**: Users can increase the size of an existing position, recalculating the entry price and ensuring that the increased position doesn't exceed the maximum leverage.

4. **Increasing Collateral**: Users can add more collateral to their position.

5. **Closing Positions**: Users can close their positions, realizing any profits or losses. If the position is in profit, funds are transferred from the pool to the user; if in loss, funds are transferred from the user to the pool. Afterwards, the open interest is updated, and the position is deleted.

6. **Liquidation**: Any account can trigger a liquidation on a position if it's undercollateralized due to market movements. The position is closed, with the asset being transferred to the pool and the user, depending on the remaining collateral after covering the loss.

7. **Available Liquidity**: This is calculated by taking the pool's balance and adjusting for the unrealized PnL (profit and loss) of all open positions. Negative open interest implies overall profit, which increases available liquidity. Positive open interest implies overall loss, which may decrease available liquidity.

## Note

1. Decimals
   1. **BTC (Index Token)** = 8 decimals
   2. **USD (Asset & Collateral)** = 18 decimals
2. The Liquidity Pool is capped at **max utilization of 80%**. In simple terms, if the liquidity pool has `$100`, the `TotalOpenInterest (Long + Short)` cannot be more than `$80`.
