// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//Define the types of positions that can be taken
enum PositionType {
    Long,
    Short
}
struct Position {
    PositionType positionType;
    uint256 size;
    uint256 collateral;
    uint256 openPrice; //The price at which the position was opened
    bool isOpen; //A flag to indicate if the position is open or closed
}
