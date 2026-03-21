// S// SPDX-License-Identifier: MIT

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

    ///////////////////////
    // State Variables   //
    ///////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    mapping(address token => address priceFeed) private sPriceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private sCollateralDeposited; // userToTokenToAmount
    mapping(address user => uint256 amountDscMinted) private sDSCMinted;
    address[] private sCollateralTokens;

    address weth;
    address wbtc;

    DecentralizedStableCoin private immutable iDsc;

    ///////////////////////
    // Events            //
    ///////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    ///////////////////////
    // Modifiers         //
    ///////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (sPriceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////////////
    // Functions         //
    ///////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // IDR Price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // For example ETH / IDR, BTC / IDR, etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            sPriceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            sCollateralTokens.push(tokenAddresses[i]);
        }
        iDsc = DecentralizedStableCoin(dscAddress);
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
        sDSCMinted[msg.sender] += amountDscToMint;
        // if they minted too much (Rp150.000, Rp100.000 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////////////////////////
    // Private & Internal View Functions  //
    ////////////////////////////////////////
    function _getAccountInformation(address user) private view returns (uint256 totalDscMinted, uint256 collateralValueInIdr) {
        totalDscMinted = sDSCMinted[user];
        collateralValueInIdr = getAccountCollateralValue(user);
    }

    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, then they can get liquidation
    */
    function _healthFactor(address user) private view returns(uint256) {
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInIdr) = _getAccountInformation(user);

    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check health factor (do they have enough collateral?)
        // 2. Revert if they don't

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
        AggregatorV3Interface priceFeed = AggregatorV3Interface(sPriceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = Rp.16.000.000
        // The returned value from CL will be 16.000.000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
