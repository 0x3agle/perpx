// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, IERC20Metadata, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPerp {
    function updateLiquidity() external;
}

contract Pool is ERC4626 {
    error NotSupported();

    IERC20 _asset;
    address perp;

    constructor(IERC20 asset) ERC4626(asset) ERC20("perp", "perp") {
        _asset = asset;
        perp = msg.sender;
        asset.approve(msg.sender, type(uint256).max);
    }

    function deposit(uint256 assets, address receiver) public override(ERC4626) returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);
        IPerp(perp).updateLiquidity();
        return shares;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override(ERC4626) returns (uint256) {
        uint256 shares = super.withdraw(assets, receiver, owner);
        IPerp(perp).updateLiquidity();
        return shares;
    }

    function transferFrom(address, address, uint256) public pure override(IERC20, ERC20) returns (bool) {
        revert NotSupported();
    }

    function transfer(address, uint256) public pure override(IERC20, ERC20) returns (bool) {
        revert NotSupported();
    }

    function mint(uint256, address) public pure override(ERC4626) returns (uint256) {
        revert NotSupported();
    }

    function redeem(uint256, address, address) public pure override(ERC4626) returns (uint256) {
        revert NotSupported();
    }
}
