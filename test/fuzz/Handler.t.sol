// SPDX-License-Identifier: MIT

// Handler is going to narrow down the way we call function

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
  DSCEngine dsce;
  DecentralizedStableCoin dsc;

  ERC20Mock weth;
  ERC20Mock wbtc;

  MockV3Aggregator ethUsdPriceFeed;

  uint256 private constant MAX_DEPOSIT_SIZE = type(uint96).max;
  
  uint256 public timesMintIsCalled;

  constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
    dsce = _engine;
    dsc = _dsc;

    address[] memory collateralTokens = dsce.getCollateralTokens();
    weth = ERC20Mock(collateralTokens[0]);
    wbtc = ERC20Mock(collateralTokens[1]);

    ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
  }

  function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    
    vm.startPrank(msg.sender);
    collateral.mint(msg.sender, amountCollateral);
    collateral.approve(address(dsce), amountCollateral);
    dsce.depositCollateral(address(collateral), amountCollateral);
    vm.stopPrank();
  }

  function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

    uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(msg.sender, address(collateral));

    if (maxCollateralToRedeem == 0) {
      return;
    }

    amountCollateral = bound(amountCollateral, 1, maxCollateralToRedeem);

    vm.startPrank(msg.sender);
    dsce.redeemCollateral(address(collateral), amountCollateral);
    vm.stopPrank();
  }

  function mintDsc (uint256 amount) public {
    (uint256 totalDscMinted, uint256 collateralValueInIdr) = dsce.getAccountInformation(msg.sender);

    uint256 maxDscMintableValue = (collateralValueInIdr / 2);
    if (totalDscMinted >= maxDscMintableValue) {
      return;
    }

    uint256 maxDscToMint = maxDscMintableValue - totalDscMinted;

    if (maxDscToMint == 0) {
      return;
    }

    amount = bound(amount, 1, maxDscToMint);


    vm.startPrank(msg.sender);
    dsce.mintDsc(amount);
    vm.stopPrank();

    timesMintIsCalled++;
  }

  function updateCollateralPrice(uint96 newPrice) public {
    int256 newPriceInt = int256(uint256(newPrice));
    ethUsdPriceFeed.updateAnswer(newPriceInt);
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