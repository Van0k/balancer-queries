// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum ActionType {
    SWAP,
    DEPOSIT_SINGLE_TOKEN,
    WITHDRAW_SINGLE_TOKEN
}

struct PoolAction {
    ActionType actionType;
    IERC20 tokenIn;
    IERC20 tokenOut;
    uint256 amountIn;
}

interface IBalancerV3MultiActionQueries {
    function vault() external view returns (address);

    function queryActions(address pool, PoolAction[] calldata actions) external returns (uint256[] memory amountsOut);

    function executeActions(address pool, PoolAction[] calldata actions)
        external
        returns (uint256[] memory amountsOut);
}
