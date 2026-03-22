// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../src/DSCEngine.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        // 1. Sesuaikan urutan destructuring dengan struct NetworkConfig terbaru
        (
            address wethUsdPriceFeed, 
            address wbtcUsdPriceFeed, 
            address weth, 
            address wbtc, 
            address usdIdrPriceFeed, // <-- TAMBAHAN BARU DI SINI
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        
        // Catatan: Jika di file DecentralizedStableCoin.sol sebelumnya Anda memilih "Opsi 2" 
        // (meminta initialOwner), ubah baris di bawah ini menjadi: 
        // DecentralizedStableCoin dsc = new DecentralizedStableCoin(msg.sender);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        
        // 2. Masukkan usdIdrPriceFeed sebagai parameter ke-4
        DSCEngine dscEngine = new DSCEngine(
            tokenAddresses, 
            priceFeedAddresses, 
            address(dsc), 
            usdIdrPriceFeed // <-- TAMBAHAN BARU DI SINI
        );
        
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        
        return (dsc, dscEngine, helperConfig);
    }
}