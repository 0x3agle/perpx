# `PerpX` Documentation

## Overview

The `PerpX` protocol serves as an advanced trading platform for users interested in taking leveraged long or short positions on various assets. It allows traders to interact with a decentralized market without owning the underlying asset directly. By using an external price feed oracle, the protocol ensures that the prices for assets are accurate and up to date. In addition to trading functionalities, the protocol includes features for liquidity providers to participate in the market by supplying liquidity.

## Dependencies

- **IERC20 Interface**: Provided by OpenZeppelin, this is a standard interface for ERC20 tokens, allowing the protocol to interact with any compliant token assets.
- **SafeERC20 Library**: This OpenZeppelin library provides safe methods for interacting with ERC20 tokens that correctly implement the IERC20 interface, guarding against reentrancy and other common issues.
- **AggregatorV3Interface Contract**: A custom interface for an external oracle that provides reliable price feeds for the protocol to use in its calculations.
- **Pool Contract**: A separate contract that manages the liquidity provisions, ensuring that liquidity can be added to or removed from the system in a controlled manner.

## Key Features

### Liquidity Provision

- **Deposit Liquidity**: Liquidity providers (LPs) can add liquidity to the `PerpX` pool. Deposits are made in the base asset, and LPs receive pool shares in return.
- **Withdraw Liquidity**: LPs can withdraw their provided liquidity along with any realized profits or losses based on the trader's performance.

### Trading

- **Leveraged Positions**: Users can open leveraged long or short positions, amplifying their exposure to price movements of the underlying asset.
- **Position Management**: Traders can increase the size of an open position or add additional collateral to avoid liquidation.
- **Closing Positions**: Traders can close their positions to capture their gains or limit losses.
- **Real-Time Pricing**: The `AggregatorV3Interface` oracle provides real-time price data, ensuring that all trading activities are based on the latest market prices.

### Risk Management

- **Liquidation**: The protocol includes a liquidation mechanism to close undercollateralized positions, protecting the system and LPs from excessive losses.

BTC Amount - 8 decimals
Collateral (USDC) - 18 decimals
SCALE = 8 decimals
