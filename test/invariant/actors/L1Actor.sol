// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Dove } from "../../../src/L1/Dove.sol";
import { L1Router } from "../../../src/L1/L1Router.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

contract L1Actor is StdUtils {

    Dove public dove;
    L1Router public router;

    constructor (address _dove, address _router) {
        dove = Dove(_dove);
        router = L1Router(_router);
    }

    function deposit(
        uint256 _amountADesired,
        uint256 _amountBDesired
    ) external {
        uint256 _maxA = ERC20Mock(dove.token0()).balanceOf(address(this));
        uint256 _maxB = ERC20Mock(dove.token0()).balanceOf(address(this));
        uint256 boundedDesiredA = bound(_amountADesired, 1001, _maxA);
        uint256 boundedDesiredB = bound(_amountBDesired, 1001, _maxB);

        (uint256 _amountMinA, uint256 _amountMinB, uint256 liquidity) = 
            router.quoteAddLiquidity(dove.token0(), dove.token1(), boundedDesiredA, boundedDesiredB);

        router.addLiquidity(
            dove.token0(),
            dove.token1(),
            boundedDesiredA,
            boundedDesiredB,
            _amountMinA,
            _amountMinB,
            address(this),
            type(uint256).max
        );
    }

    function withdraw(
        uint256 liquidity
    ) external {
        uint256 boundedLiquidity = bound(liquidity, 0, ERC20Mock(address(dove)).balanceOf(address(this)));

        (uint256 _amount0Min, uint256 _amount1Min) = 
            router.quoteRemoveLiquidity(dove.token0(), dove.token1(), boundedLiquidity);

        dove.approve(address(router), type(uint256).max);
        router.removeLiquidity(
            dove.token0(),
            dove.token1(),
            boundedLiquidity,
            _amount0Min,
            _amount1Min,
            address(this),
            block.timestamp + 1
        );
    }
}