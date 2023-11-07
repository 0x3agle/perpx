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

    uint128 public constant SCALE = 1e8;

    AggregatorV3Interface oracle;
    IERC20 asset;
    Pool public pool;
    uint8 public maxLeverage;
    uint256 totalLiquidity; //Total liquidity available in the protocol
    uint256 reservedLiquidity; //Liquidity reserved for open positions

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

    function openPosition(
        uint256 _size,
        uint256 _collateral,
        PositionType _positionType
    ) public {
        require(!positions[msg.sender].isOpen, "Position already open!");
        require(
            _size > 0 && _collateral > 0 && _collateral * maxLeverage >= _size,
            "Invalid inputs"
        );

        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = (_size * currentPrice) / SCALE;
        // Ensure there's enough liquidity to open the position.
        require(
            posValue <= totalLiquidity - reservedLiquidity,
            "Insufficient liquidity"
        );

        asset.safeTransferFrom(msg.sender, address(this), _collateral);

        positions[msg.sender] = Position({
            positionType: _positionType,
            size: _size,
            collateral: _collateral,
            openPrice: currentPrice,
            isOpen: true
        });

        reservedLiquidity += posValue;
    }

    function increaseSize(uint256 amount) public {
        require(positions[msg.sender].isOpen == true, "Position not open!");

        Position memory oldPosition = positions[msg.sender];

        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = (amount * currentPrice) / SCALE;

        require(
            posValue <= totalLiquidity - reservedLiquidity,
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
        reservedLiquidity =
            reservedLiquidity -
            (oldPosition.size * oldPosition.openPrice) +
            ((oldPosition.size + amount) * newEntryPrice);
    }

    function increaseCollateral(uint256 amount) public {
        require(positions[msg.sender].isOpen, "Position not open");
        require(amount > 0, "Amount must be greater than zero");

        asset.safeTransferFrom(msg.sender, address(this), amount);

        positions[msg.sender].collateral += amount;
    }

    function closePosition() public {
        Position memory pos = positions[msg.sender];
        require(pos.isOpen == true, "Position not open!");

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
        reservedLiquidity -= posValue;

        delete positions[msg.sender];
    }

    function liquidate(address user) public returns (uint256 amountLiquidated) {
        Position memory pos = positions[user];
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
            reservedLiquidity -= posValue;
            delete positions[user];
            return amountToLiquidate;
        }
        return 0;
    }

    /////////// Helper Functions ///////////////////////

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    function getRealtimePrice() public view returns (uint256) {
        (, int256 intAnswer, , , ) = oracle.latestRoundData();

        return uint256(intAnswer);
    }

    function updateLiquidity() public {
        require(msg.sender == address(pool), "Not authorized");

        uint256 newPoolLiquidity = asset.balanceOf(address(pool));
        require(newPoolLiquidity > reservedLiquidity, "Liquidity in use");

        int256 liquidityChange = int256(newPoolLiquidity) -
            int256(totalLiquidity);

        if (liquidityChange >= 0) {
            totalLiquidity += uint256(liquidityChange);
        } else {
            totalLiquidity -= uint256(-liquidityChange);
        }
    }
}
