// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, IERC20Metadata, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is ERC4626 {
    error NotSupported();

    constructor(IERC20 usdc) ERC4626(usdc) ERC20("perp", "perp") {}

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override(IERC20, ERC20) returns (bool) {
        revert NotSupported();
    }

    function transfer(
        address,
        uint256
    ) public pure override(IERC20, ERC20) returns (bool) {
        revert NotSupported();
    }

    function mint(
        uint256,
        address
    ) public pure override(ERC4626) returns (uint256) {
        revert NotSupported();
    }

    function redeem(
        uint256,
        address,
        address
    ) public pure override(ERC4626) returns (uint256) {
        revert NotSupported();
    }
}
