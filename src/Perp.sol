// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "./MockOracle.sol";
import {Pool} from "./Pool.sol";
import "./lib/helpers.sol";

//  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄       ▄
// ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌     ▐░▌
// ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀█░▌ ▐░▌   ▐░▌
// ▐░▌       ▐░▌▐░▌          ▐░▌       ▐░▌▐░▌       ▐░▌  ▐░▌ ▐░▌
// ▐░█▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄▄▄█░▌   ▐░▐░▌
// ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌    ▐░▌
// ▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀█░█▀▀ ▐░█▀▀▀▀▀▀▀▀▀    ▐░▌░▌
// ▐░▌          ▐░▌          ▐░▌     ▐░▌  ▐░▌            ▐░▌ ▐░▌
// ▐░▌          ▐░█▄▄▄▄▄▄▄▄▄ ▐░▌      ▐░▌ ▐░▌           ▐░▌   ▐░▌
// ▐░▌          ▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░▌          ▐░▌     ▐░▌
//  ▀            ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀  ▀            ▀       ▀

contract Perp {
    using SafeERC20 for IERC20;

    error NotEnoughLiquidity();
    error PositionNotOpen();
    error PositionAlreadyOpen();

    AggregatorV3Interface oracle;
    IERC20 asset;
    Pool public pool;
    uint8 public maxLeverage;

    uint public constant SCALE = 1e8;
    uint openShortInUSD;
    uint openLongInUSD;
    uint openShortInBTC;
    uint openLongInBTC;

    mapping(address => Position) public positions;

    constructor(address _oracle, address _asset, uint8 _maxLeverage) {
        require(
            _oracle != address(0) && _asset != address(0),
            "Invalid address"
        );
        oracle = AggregatorV3Interface(_oracle);
        asset = IERC20(_asset);
        maxLeverage = _maxLeverage;
        pool = new Pool(asset);
    }

    /////////// User Functions ///////////////////////

    function openPosition(
        uint256 _size,
        uint256 _collateral,
        PositionType _positionType
    ) public {
        if (positions[msg.sender].isOpen) {
            revert PositionAlreadyOpen();
        }
        require(
            _size > 0 && _collateral > 0 && _collateral * maxLeverage >= _size,
            "Invalid inputs"
        );

        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = (_size * currentPrice) / SCALE;
        // Ensure there's enough liquidity to open the position.
        if (posValue > getAvailableLiquidity()) {
            revert NotEnoughLiquidity();
        }

        asset.safeTransferFrom(msg.sender, address(this), _collateral);

        positions[msg.sender] = Position({
            positionType: _positionType,
            size: _size,
            collateral: _collateral,
            openPrice: currentPrice,
            isOpen: true
        });

        if (_positionType == PositionType.Long) {
            openLongInBTC += _size;
            openLongInUSD += posValue;
        } else {
            openShortInBTC += _size;
            openShortInUSD += posValue;
        }
    }

    function increaseSize(uint256 amount) public {
        if (!positions[msg.sender].isOpen) {
            revert PositionNotOpen();
        }

        Position memory oldPosition = positions[msg.sender];

        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = (amount * currentPrice) / SCALE;

        require(
            posValue <= getAvailableLiquidity(),
            "Insufficient liquidity to increase the size"
        );

        uint256 newEntryPrice = (((oldPosition.size * oldPosition.openPrice) /
            SCALE) + (posValue)) / (oldPosition.size + amount);

        require(
            oldPosition.collateral * maxLeverage >=
                ((oldPosition.size + amount) * newEntryPrice),
            "Exceeding Maximum Leverage"
        );

        Position memory newPosition = Position({
            positionType: oldPosition.positionType,
            size: oldPosition.size + amount,
            collateral: oldPosition.collateral,
            openPrice: newEntryPrice,
            isOpen: oldPosition.isOpen
        });
        positions[msg.sender] = newPosition;

        if (oldPosition.positionType == PositionType.Long) {
            openLongInBTC += amount;
            openLongInUSD =
                openLongInUSD -
                (oldPosition.size * oldPosition.openPrice) +
                ((oldPosition.size + amount) * newEntryPrice);
        } else {
            openShortInBTC += amount;
            openShortInUSD =
                openShortInUSD -
                (oldPosition.size * oldPosition.openPrice) +
                ((oldPosition.size + amount) * newEntryPrice);
        }
    }

    function increaseCollateral(uint256 amount) public {
        if (!positions[msg.sender].isOpen) {
            revert PositionNotOpen();
        }
        require(amount > 0, "Amount must be greater than zero");

        asset.safeTransferFrom(msg.sender, address(this), amount);

        positions[msg.sender].collateral += amount;
    }

    function closePosition() public {
        Position memory pos = positions[msg.sender];
        if (!pos.isOpen) {
            revert PositionNotOpen();
        }

        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = (pos.size * pos.openPrice) / SCALE;
        uint256 currentPosValue = (pos.size * currentPrice) / SCALE;
        int256 valueChange = int256(currentPosValue) - int256(posValue);

        if (pos.positionType == PositionType.Long) {
            if (valueChange >= 0) {
                //In case of positive PnL
                asset.safeTransferFrom(
                    address(pool),
                    msg.sender,
                    uint256(valueChange)
                );
                asset.safeTransfer(msg.sender, pos.collateral);
            } else {
                //In case of negative Pnl
                uint256 loss = pos.collateral > uint256(-valueChange)
                    ? pos.collateral - uint256(-valueChange)
                    : pos.collateral;
                asset.safeTransfer(address(pool), loss);

                uint256 remainingCollateral = pos.collateral > loss
                    ? pos.collateral - loss
                    : 0;
                if (remainingCollateral > 0) {
                    asset.safeTransfer(msg.sender, remainingCollateral);
                }
            }
        } else {
            if (valueChange <= 0) {
                //In case of positive PnL
                asset.safeTransferFrom(
                    address(pool),
                    msg.sender,
                    uint256(-valueChange)
                );
                asset.safeTransfer(msg.sender, pos.collateral);
            } else {
                //In case of negative Pnl
                uint256 loss = pos.collateral > uint256(valueChange)
                    ? pos.collateral - uint256(valueChange)
                    : pos.collateral;
                asset.safeTransfer(address(pool), loss);

                uint256 remainingCollateral = pos.collateral > loss
                    ? pos.collateral - loss
                    : 0;
                if (remainingCollateral > 0) {
                    asset.safeTransfer(msg.sender, remainingCollateral);
                }
            }
        }
        if (pos.positionType == PositionType.Long) {
            openLongInBTC -= pos.size;
            openLongInUSD -= posValue;
        } else {
            openShortInBTC -= pos.size;
            openShortInUSD -= posValue;
        }

        delete positions[msg.sender];
    }

    function liquidate(address user) public returns (uint256 amountLiquidated) {
        Position memory pos = positions[user];
        if (!pos.isOpen) {
            revert PositionNotOpen();
        }
        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = (pos.size * pos.openPrice) / SCALE;
        uint256 currentPosValue = (pos.size * currentPrice) / SCALE;
        int256 valueChange = int256(currentPosValue) - int256(posValue);
        if (
            (pos.positionType == PositionType.Long && valueChange < 0) ||
            (pos.positionType == PositionType.Short && valueChange > 0)
        ) {
            uint256 loss = uint256(abs(valueChange));
            uint256 amountToLiquidate = loss > pos.collateral
                ? pos.collateral
                : loss;
            if (amountToLiquidate > 0) {
                asset.safeTransfer(address(pool), amountToLiquidate);
            }
            if (loss < pos.collateral) {
                asset.safeTransfer(user, pos.collateral - loss);
            }

            if (pos.positionType == PositionType.Long) {
                openLongInBTC -= pos.size;
                openLongInUSD -= posValue;
            } else {
                openShortInBTC -= pos.size;
                openShortInUSD -= posValue;
            }
            delete positions[user];
            return amountToLiquidate;
        }
        return 0;
    }

    /////////// Helper Functions ///////////////////////

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    //Totals the open interest of all open LONG & SHORT positions and compares with Pool balance to get avaialable liquidity
    function getAvailableLiquidity() public view returns (uint) {
        uint poolBalance = asset.balanceOf(address(pool));
        uint currentPrice = getRealtimePrice();

        uint totalOpenInterest = ((openLongInBTC + openShortInBTC) *
            currentPrice) / SCALE;
        uint cappedPoolBalance = (poolBalance * 80) / 100; //Liquidity Pool capped at 80% utilization

        if (totalOpenInterest < cappedPoolBalance) {
            return cappedPoolBalance - totalOpenInterest;
        } else {
            return 0;
        }
    }

    function getRealtimePrice() public view returns (uint256) {
        (, int256 intAnswer, , , ) = oracle.latestRoundData();

        return uint256(intAnswer);
    }

    function checkLiquidity() public view {
        require(msg.sender == address(pool), "Not authorized");
        uint availableLiquidity = getAvailableLiquidity();
        if (availableLiquidity == 0) {
            revert NotEnoughLiquidity();
        }
    }
}
