// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {IERC20, IERC20Metadata, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "./oracle.sol";
import {Pool} from "./Pool.sol";

// The Perp contract is used for creating and managing perpetual positions
contract Perp {
    using SafeERC20 for IERC20;

    //Define the types of positions that can be taken
    enum PositionType {
        Long,
        Short
    }

    //Structure to hold the details of a position
    struct Position {
        PositionType positionType; //Whether the position is long or short
        uint size; //The size of the position
        uint collateral; //The amount of collateral deposited
        uint openPrice; //The price at which the position was opened
        bool isOpen; //A flag to indicate if the position is open or closed
    }
    //References to the oracle for price feeds and the ERC20 asset used as collateral
    AggregatorV3Interface oracle;
    IERC20 asset;

    //Variables for protocol parameters
    uint8 public maxLeverage; //The maximum leverage allowed by the protocol
    Pool pool; //Reference to the associated Pool contract
    uint256 totalLiquidity; //Total liquidity available in the protocol
    uint256 reservedLiquidity; //Liquidity reserved for open positions

    //Mapping to keep track of each user's position
    mapping(address => Position) public positions;

    //Events to log actions taken within the contract
    event PositionOpened(
        address indexed trader,
        PositionType positionType,
        uint size,
        uint collateral,
        uint openPrice
    );

    // Constructor to set up the contract with necessary parameters
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

    // Function to open a new position
    function openPosition(
        uint256 _size,
        uint256 _collateral,
        PositionType _positionType
    ) public {
        // Validation checks for position creation.
        require(!positions[msg.sender].isOpen, "Position already open!");
        require(
            _size > 0 && _collateral > 0 && _collateral * maxLeverage >= _size,
            "Invalid inputs"
        );
        // Calculate the position's value using the current price from the oracle.
        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = _size * currentPrice;
        // Ensure there's enough liquidity to open the position.
        require(
            posValue <= totalLiquidity - reservedLiquidity,
            "Insufficient liquidity"
        );
        // Transfer collateral from the user to the contract.
        asset.safeTransferFrom(msg.sender, address(this), _collateral);
        // Create and store the new position.
        positions[msg.sender] = Position({
            positionType: _positionType,
            size: _size,
            collateral: _collateral,
            openPrice: currentPrice,
            isOpen: true
        });
        // Adjust the reserved liquidity.
        reservedLiquidity += posValue;
        // Emit an event to log the position opening.
        emit PositionOpened(
            msg.sender,
            _positionType,
            _size,
            _collateral,
            currentPrice
        );
    }

    // Update the protocol's liquidity based on changes in the pool
    function updateLiquidity() public {
        require(msg.sender == address(pool), "Not authorized");

        // Calculate the new liquidity amount.
        uint256 newPoolLiquidity = asset.balanceOf(address(pool));
        require(newPoolLiquidity > reservedLiquidity, "Liquidity in use");

        // Adjust totalLiquidity according to the liquidity change.
        int256 liquidityChange = int256(totalLiquidity) -
            int256(newPoolLiquidity);

        if (liquidityChange >= 0) {
            totalLiquidity += uint256(liquidityChange);
        } else {
            totalLiquidity -= uint256(-liquidityChange);
        }
    }

    // Function to increase the size of an existing position
    function increaseSize(uint256 amount) public {
        require(positions[msg.sender].isOpen == true, "Position not open!");

        Position memory oldPosition = positions[msg.sender];

        // Retrieve the current position and calculate its new value.
        uint256 currentPrice = getRealtimePrice();
        uint256 posValue = amount * currentPrice;

        // Ensure there's enough liquidity to increase the size.
        require(
            posValue <= totalLiquidity - reservedLiquidity,
            "Insufficient liquidity to increase the size"
        );

        uint256 newEntryPrice = ((oldPosition.size * oldPosition.openPrice) +
            (posValue)) / (oldPosition.size + amount);

        Position memory newPosition = Position({
            positionType: oldPosition.positionType,
            size: oldPosition.size + amount,
            collateral: oldPosition.collateral,
            openPrice: newEntryPrice,
            isOpen: oldPosition.isOpen
        });

        //Check to ensure that the position doesn't exceed maximum leverage
        require(
            oldPosition.collateral * maxLeverage >=
                ((oldPosition.size + amount) * newEntryPrice),
            "Exceeding Maximum Leverage"
        );

        positions[msg.sender] = newPosition;
        reservedLiquidity =
            reservedLiquidity -
            (oldPosition.size * oldPosition.openPrice) +
            ((oldPosition.size + amount) * newEntryPrice);
    }

    //Function to increase the collateral of an existing position
    function increaseCollateral(uint256 amount) public {
        //Validation check before increasing collateral
        require(positions[msg.sender].isOpen, "Position not open");
        require(amount > 0, "Amount must be greater than zero");
        // Transfer the additional collateral to the contract
        asset.safeTransferFrom(msg.sender, address(this), amount);
        // Update the position's collateral amount
        positions[msg.sender].collateral += amount;
    }

    //Helper function to get the real-time price from the oracle
    function getRealtimePrice() public view returns (uint256) {
        (, int256 intAnswer, , , ) = oracle.latestRoundData();

        //Return the price as a positive integer
        return uint256(intAnswer);
    }
}
