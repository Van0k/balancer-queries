// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultMain} from "@balancer-labs/v3-interfaces/contracts/vault/IVaultMain.sol";
import {IVaultExtension} from "@balancer-labs/v3-interfaces/contracts/vault/IVaultExtension.sol";
import {RevertCodec} from "@balancer-labs/v3-solidity-utils/contracts/helpers/RevertCodec.sol";
import "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import "./interfaces/IBalancerV3MultiActionQueries.sol";

/**
 * @title BalancerV3MultiActionQueries
 * @notice Contract for querying sequences of actions in Balancer V3 pools
 */
contract BalancerV3MultiActionQueries is IBalancerV3MultiActionQueries {
    address public immutable vault;

    constructor(address _vault) {
        vault = _vault;
    }

    /**
     * @notice Query a sequence of actions on a Balancer V3 pool
     * @param pool The pool address to query
     * @param actions Array of actions to simulate
     * @return amountsOut Array of output amounts for each action
     */
    function queryActions(address pool, PoolAction[] calldata actions) external returns (uint256[] memory amountsOut) {
        bytes memory data = abi.encodeCall(this.executeActions, (pool, actions));

        try IVaultExtension(vault).quoteAndRevert(data) {
            revert("Query did not revert");
        } catch (bytes memory revertData) {
            bytes memory decodedData = RevertCodec.catchEncodedResult(revertData);
            return abi.decode(decodedData, (uint256[]));
        }
    }

    /**
     * @notice Find the index of a token in the pool's token array
     * @param tokens Array of pool tokens
     * @param token Token to find
     * @return Index of the token in the array
     */
    function _findTokenIndex(IERC20[] memory tokens, IERC20 token) internal pure returns (uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                return i;
            }
        }
        revert("Token not found in pool");
    }

    /**
     * @notice Callback function executed by the vault during query
     * @param pool The pool to execute actions on
     * @param actions Array of actions to execute
     * @return amountsOut Array of output amounts for each action
     */
    function executeActions(address pool, PoolAction[] calldata actions)
        external
        returns (uint256[] memory amountsOut)
    {
        require(msg.sender == vault, "Unauthorized");

        amountsOut = new uint256[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            PoolAction calldata action = actions[i];

            if (action.actionType == ActionType.SWAP) {
                (,, uint256 amountOut) = IVaultMain(vault).swap(
                    VaultSwapParams({
                        kind: SwapKind.EXACT_IN,
                        pool: pool,
                        tokenIn: action.tokenIn,
                        tokenOut: action.tokenOut,
                        amountGivenRaw: action.amountIn,
                        limitRaw: 0,
                        userData: ""
                    })
                );
                amountsOut[i] = amountOut;
            } else if (action.actionType == ActionType.DEPOSIT_SINGLE_TOKEN) {
                IERC20[] memory tokens = IVaultExtension(vault).getPoolTokens(pool);
                uint256 tokenIndex = _findTokenIndex(tokens, action.tokenIn);

                uint256[] memory maxAmountsIn = new uint256[](tokens.length);
                maxAmountsIn[tokenIndex] = action.amountIn;

                (, uint256 bptAmountOut,) = IVaultMain(vault).addLiquidity(
                    AddLiquidityParams({
                        pool: pool,
                        to: address(this),
                        maxAmountsIn: maxAmountsIn,
                        minBptAmountOut: 0,
                        kind: AddLiquidityKind.UNBALANCED,
                        userData: ""
                    })
                );
                amountsOut[i] = bptAmountOut;
            } else if (action.actionType == ActionType.WITHDRAW_SINGLE_TOKEN) {
                IERC20[] memory tokens = IVaultExtension(vault).getPoolTokens(pool);
                uint256 tokenIndex = _findTokenIndex(tokens, action.tokenOut);

                uint256[] memory minAmountsOut = new uint256[](tokens.length);

                (, uint256[] memory tokensOut,) = IVaultMain(vault).removeLiquidity(
                    RemoveLiquidityParams({
                        pool: pool,
                        from: address(this),
                        maxBptAmountIn: action.amountIn,
                        minAmountsOut: minAmountsOut,
                        kind: RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN,
                        userData: ""
                    })
                );
                amountsOut[i] = tokensOut[tokenIndex];
            }
        }

        return amountsOut;
    }
}
