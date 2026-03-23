// SPDX-License-Identifier: MIT

// Handler is going to narrow down the way we call function

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract Handler is Test {
  DSCEngine dsce;
  DecentralizedStableCoin dsc;

  ERC20Mock weth;
  ERC20Mock wbtc;

  constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
    dsce = _engine;
    dsc = _dsc;

    address[] memory collateralTokens = dsce.getCollateralTokens();
    weth = ERC20Mock(collateralTokens[0]);
    wbtc = ERC20Mock(collateralTokens[1]);
  }

  function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    amountCollateral = bound(amountCollateral, 1, type(uint96).max);

    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    
    vm.startPrank(msg.sender);
    collateral.mint(msg.sender, amountCollateral);
    collateral.approve(address(dsce), amountCollateral);
    dsce.depositCollateral(address(collateral), amountCollateral);
    vm.stopPrank();
  }

  // Helper Functions
  function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
    if (collateralSeed % 2 == 0) {
      return weth;
    } else {
      return wbtc;
    }
  }
}