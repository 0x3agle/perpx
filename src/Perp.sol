// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20, IERC20Metadata, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "./oracle.sol";

contract Pool {
    address oracle;

    constructor(address _oracle) {
        oracle = _oracle;
    }

    function openPosition(uint256 size, uint256 collateral) public {}

    function increaseSize(uint256 positionId, uint256 amount) public {}

    function increaseCollateral(uint256 positionId, uint256 amount) public {}

    function getRealtimePrice()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (
            roundId,
            answer,
            startedAt,
            updatedAt,
            answeredInRound
        ) = AggregatorV3Interface(oracle).latestRoundData();
    }
}
