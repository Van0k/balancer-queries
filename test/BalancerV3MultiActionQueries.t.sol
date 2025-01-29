// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultExtension} from "@balancer-labs/v3-interfaces/contracts/vault/IVaultExtension.sol";
import {BalancerV3MultiActionQueries, ActionType, PoolAction} from "../src/BalancerV3MultiActionQueries.sol";

contract BalancerV3MultiActionQueriesTest is Test {
    BalancerV3MultiActionQueries public queries;
    address public vault;
    address public pool;
    IERC20[] public poolTokens;

    function setUp() public {
        vault = vm.envAddress("BALANCER_V3_VAULT");
        pool = vm.envAddress("BALANCER_V3_POOL");
        queries = new BalancerV3MultiActionQueries(vault);
        poolTokens = IVaultExtension(vault).getPoolTokens(pool);
        require(poolTokens.length >= 2, "Pool must have at least 2 tokens");
    }

    function test_querySwapAndDeposit() public {
        PoolAction[] memory actions = new PoolAction[](2);

        actions[0] =
            PoolAction({actionType: ActionType.SWAP, tokenIn: poolTokens[0], tokenOut: poolTokens[1], amountIn: 1e18});

        actions[1] = PoolAction({
            actionType: ActionType.DEPOSIT_SINGLE_TOKEN,
            tokenIn: poolTokens[0],
            tokenOut: IERC20(address(0)),
            amountIn: 1e18
        });

        uint256[] memory amountsOut = queries.queryActions(pool, actions);

        require(amountsOut.length == 2, "Should return 2 amounts");
        require(amountsOut[0] > 0, "Swap output should be non-zero");
        require(amountsOut[1] > 0, "BPT output should be non-zero");
    }
}
