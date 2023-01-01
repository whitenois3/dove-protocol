// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;


import {ERC20} from "solmate/tokens/ERC20.sol";
import {Pair} from "./Pair.sol";
import {L2Factory} from "./L2Factory.sol";

contract L2Router {

    struct route {
        address from;
        address to;
    }

    L2Factory public immutable factory;
    bytes32 immutable pairCodeHash;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'BaseV1Router: EXPIRED');
        _;
    }

    constructor(address _factory) {
        factory = L2Factory(_factory);
        pairCodeHash = factory.pairCodeHash();
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'BaseV1Router: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'BaseV1Router: ZERO_ADDRESS');
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount) {
        address pair = factory.getPair(tokenIn, tokenOut);
        amount = Pair(pair).getAmountOut(amountIn, tokenIn);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, route[] memory routes) public view returns (uint[] memory amounts) {
        require(routes.length >= 1, 'BaseV1Router: INVALID_PATH');
        amounts = new uint[](routes.length+1);
        amounts[0] = amountIn;
        for (uint i = 0; i < routes.length; i++) {
            address pair = factory.getPair(routes[i].from, routes[i].to);
            if (factory.isPair(pair)) {
                amounts[i+1] = Pair(pair).getAmountOut(amounts[i], routes[i].from);
            }
        }
    }

    function isPair(address pair) external view returns (bool) {
        return factory.isPair(pair);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, route[] memory routes, address _to) internal virtual {
        for (uint i = 0; i < routes.length; i++) {
            (address token0,) = sortTokens(routes[i].from, routes[i].to);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = routes[i].from == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < routes.length - 1 ? factory.getPair(routes[i+1].from, routes[i+1].to) : _to;
            Pair(factory.getPair(routes[i].from, routes[i].to)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        route[] memory routes = new route[](1);
        routes[0].from = tokenFrom;
        routes[0].to = tokenTo;
        amounts = getAmountsOut(amountIn, routes);
        require(amounts[amounts.length - 1] >= amountOutMin, 'BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        _safeTransferFrom(
            routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]
        );
        _swap(amounts, routes, to);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsOut(amountIn, routes);
        require(amounts[amounts.length - 1] >= amountOutMin, 'BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        _safeTransferFrom(
            routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]
        );
        _swap(amounts, routes, to);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(ERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}