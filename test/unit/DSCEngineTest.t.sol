// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;

    address weth;
    address wethUsdPriceFeed;
    address usdIdrPriceFeed;

    address public user = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (wethUsdPriceFeed,, weth,, usdIdrPriceFeed,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
    }

    /////////////////
    // Price Tests //
    /////////////////

    function testGetIdrValue() public view {
        // Kita tes dengan 1 ETH
        uint256 ethAmount = 1e18;

        /**
         * LOGIKA PERHITUNGAN:
         * Di HelperConfig: ETH_USD = 2000e8 ($2,000)
         * Di HelperConfig: USD_IDR = 15000e8 (Rp15.000)
         * * Maka 1 ETH = 2000 * 15000 = Rp30.000.000
         * Dalam format 18 desimal: 30.000.000e18
         */
        uint256 expectedIdr = 30000000e18;

        // Panggil fungsi getIdrValue (pastikan nama fungsi di DSCEngine.sol adalah getIdrValue)
        uint256 actualIdr = dsce.getIdrValue(weth, ethAmount);

        assertEq(expectedIdr, actualIdr);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////
    function testRevertsIfCollateralZero() public {
      vm.startPrank(user);
      ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

      vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
      dsce.depositCollateral(weth, 0);
      vm.stopPrank();
    }
}
