// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Errors
 * @dev Custom errors for gas-efficient error handling
 */
library Errors {
    // General errors
    error ZeroAddress();
    error ZeroAmount();
    error InvalidInput();
    error Unauthorized();
    
    // Token issuance errors
    error InvalidInvestor();
    error InvalidIPFSCID();
    error AlreadyVerified();
    error InvalidRequestId();
    error InvalidIssuance();
    
    // Compliance errors
    error NotVerified();
    error NotAccredited();
    error NotQIB();
    error TokensLocked();
    error InvalidOfferingType();
    error RegCFLimitExceeded();
    error RegCFInvestmentTooLarge();
    
    // Derivatives errors
    error InvalidUTI();
    error InvalidDate();
    error InvalidCurrency();
    error InvalidNotionalAmount();
    error DerivativeAlreadyReported();
    error DerivativeNotFound();
    error InvalidCounterparty();
    error InvalidCollateral();
    error InvalidValuation();
    error InvalidPosition();
    error InvalidUnderlyingDerivative();
    
    // Price feed errors
    error InvalidPrice();
    error StalePrice();
    error PriceFeedError();
    
    // Registry errors
    error InvalidLEI();
    error InvalidUPI();
    error RegistryNotFound();
    
    // Corporate action errors
    error InvalidSecurity();
    error ActionAlreadyProcessed();
    error InvalidActionType();
    error InvalidActionAmount();
    error InvalidSplitRatio();
    
    // Transfer errors
    error TransferFailed();
    error InsufficientBalance();
    error ComplianceCheckFailed();
}

