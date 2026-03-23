// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {DSCEngine} from "src/DSCEngine.sol";

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

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (wethUsdPriceFeed,, weth,, usdIdrPriceFeed,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses; // Gunakan satu nama yang konsisten

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(usdIdrPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);

        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc), address(0));
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

    function testGetTokenAmountFromIdr() public view {
        // Ini mensimulasikan nilai Rp 1.500.000 (tulis dalam 18 desimal / ether)
        uint256 idrAmount = 1500000 ether;

        // Rp 1.500.000 / Rp 30.000.000 (Harga 1 ETH) = 0.05 ETH
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = dsce.getTokenAmountFromIdr(weth, idrAmount);

        assertEq(expectedWeth, actualWeth);
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

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(randToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    // 1. Test mengecek apakah data per-token benar
    function testCanDepositCollateralAndCheckBalance() public depositedCollateral {
        // Karena kita pakai modifier 'depositedCollateral', di titik ini user SUDAH deposit 10 ether WETH.

        // Cek saldo user menggunakan fungsi external view yang baru saja kita buat
        uint256 userBalance = dsce.getCollateralBalanceOfUser(user, weth);

        // Pastikan saldonya benar-benar 10 ether
        assertEq(userBalance, AMOUNT_COLLATERAL);
    }

    // 2. Test mengecek apakah total akun (mint & nilai jaminan) ter-update
    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInIdr) = dsce.getAccountInformation(user);

        // Dapatkan jumlah token dari nilai IDR tersebut
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromIdr(weth, collateralValueInIdr);

        // Pastikan DSC yang di-mint adalah 0 (karena kita baru deposit, belum mint)
        assertEq(totalDscMinted, 0);
        // Pastikan jumlah token yang dideposit sesuai
        assertEq(AMOUNT_COLLATERAL, expectedDepositedAmount);
    }
}
