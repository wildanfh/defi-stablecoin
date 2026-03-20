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

contract DSCEngine {
  function depositCollateralAndMintDsc() external {}

  function depositCollateral() external {}

  function redeemCollateralForDsc() external {}

  function redeemCollateral() external {}

  function mintDsc() external {}

  function burnDsc() external {}

  function liquidate() external {}

  function getHealthFactor() external view {}
}