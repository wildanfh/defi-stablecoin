// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Wildanf
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == Rp1 peg.
 * This stablecoin has the properties:
 * - Exogeneus Collateral
 * - Dollar Pegge
 * - Algorithmically Stable
 *
 * It is similiar to DAI if DAI had no governance, no fees, and was only backed by wETH and wBTC.
 *
 * Our DSC system should always be "overcollateralized. At no point, should the value of all collateral <= the IDR backed value of all the DSC"
 *
 * @notice This contract is the core of th DSC System. It handles all the logic for mining and redeeming DSC, as well as depositing & Withdrwing collateral.
 * @notice This contract is VERY loosely based on the MakerDao DSS. (DAI) system.
 */

contract DSCEngine is ReentrancyGuard {
    ///////////////////////
    // Errors            //
    ///////////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    ///////////////////////
    // State Variables   //
    ///////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private sPriceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private sCollateralDeposited; // userToTokenToAmount
    mapping(address user => uint256 amountDscMinted) private sDscMinted;
    address[] private sCollateralTokens;

    address weth;
    address wbtc;

    DecentralizedStableCoin private immutable I_DSC;
    
    // Variabel baru untuk Chainlink USD/IDR Price Feed
    AggregatorV3Interface private sUsdIdrPriceFeed; 

    ///////////////////////
    // Events            //
    ///////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    ///////////////////////
    // Modifiers         //
    ///////////////////////
    modifier moreThanZero(uint256 amount) {
        _moreThanZero(amount);
        _;
    }

    modifier isAllowedToken(address token) {
        _isAllowedToken(token);
        _;
    }

    ///////////////////////
    // Functions         //
    ///////////////////////
    constructor(
        address[] memory tokenAddresses, 
        address[] memory priceFeedAddresses, 
        address dscAddress, 
        address usdIdrPriceFeedAddress // <-- Parameter baru ditambahkan di sini
    ) {
        // IDR Price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // For example ETH / USD, BTC / USD, etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            sPriceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            sCollateralTokens.push(tokenAddresses[i]);
        }
        I_DSC = DecentralizedStableCoin(dscAddress);
        
        // Inisialisasi kontrak oracle USD/IDR
        sUsdIdrPriceFeed = AggregatorV3Interface(usdIdrPriceFeedAddress);
    }

    ////////////////////////
    // External Functions //
    ////////////////////////
    function depositCollateralAndMintDsc() external {}

    /*
     * @notice follows CEI pattern
     * @param tokenCollateralAddress the address of the token to deposit as collateral
     * @param  amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        sCollateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        if (!success) {
          revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    /*
    * @notice follows CEI
    * @param amountDscToMint The amount of decentralized stablcoin to mint
    * @notice they must have more collateral value than the minimum threshold
    */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        // Checks/Effects
        sDscMinted[msg.sender] += amountDscToMint;
        
        // Interactions
        bool minted = I_DSC.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
        
        // Cek Health Factor di akhir setelah token benar-benar di-mint
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////////////////////////
    // Private & Internal Functions       //
    ////////////////////////////////////////
    
    // Internal functions for modifiers to save gas
    function _moreThanZero(uint256 amount) internal pure {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
    }

    function _isAllowedToken(address token) internal view {
        if (sPriceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
    }

    function _getAccountInformation(address user) private view returns (uint256 totalDscMinted, uint256 collateralValueInIdr) {
        totalDscMinted = sDscMinted[user];
        collateralValueInIdr = getAccountCollateralValue(user);
    }

    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, then they can get liquidation
    */
    function _healthFactor(address user) private view returns(uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInIdr) = _getAccountInformation(user);
        
        // Return max if no DSC minted (prevent divide by zero)
        if (totalDscMinted == 0) return type(uint256).max;

        uint256 collateralAdjustedForThreshold = (collateralValueInIdr * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    // 1. Check health factor (do they have enough collateral?)
    // 2. Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////
    // Public & External View Functions   //
    ////////////////////////////////////////
    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInIdr) {
        // loop thorugh each collateral token, get the amount they have deposited, and map it to the price, to get the IDR value
        for(uint256 i = 0; i < sCollateralTokens.length; i++) {
            address token = sCollateralTokens[i];
            uint256 amount = sCollateralDeposited[user][token];
            totalCollateralValueInIdr += getIdrValue(token, amount);
        }
        return totalCollateralValueInIdr;
    }

    function getIdrValue(address token, uint256 amount) public view returns(uint256) {
        // 1. Dapatkan harga Token ke USD (misal: ETH/USD) -> 8 desimal
        AggregatorV3Interface tokenUsdFeed = AggregatorV3Interface(sPriceFeeds[token]);
        (,int256 tokenUsdPrice,,,) = tokenUsdFeed.latestRoundData();

        // 2. Dapatkan harga USD ke IDR -> 8 desimal
        (,int256 usdIdrPrice,,,) = sUsdIdrPriceFeed.latestRoundData();

        // 3. Kalikan keduanya dan bagi dengan 1e8 untuk menjaga presisi tetap 8 desimal.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 tokenIdrPrice = (uint256(tokenUsdPrice) * uint256(usdIdrPrice)) / 1e8;

        // 4. Hitung total nilai (kalikan dengan amount dan bawa ke presisi 18 desimal)
        return ((tokenIdrPrice * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}