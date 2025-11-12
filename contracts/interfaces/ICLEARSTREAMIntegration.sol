// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Errors {
    // General errors
    error ZeroAddress();
    error ZeroAmount();
    error InvalidInput();
    error NotAuthorized();
    
    // Token errors
    error TokensLocked();
    error TransferRestricted();
    error InvalidPartition();
    
    // Compliance errors
    error NotVerified();
    error NotAccredited();
    error NotQIB();
    error AlreadyVerified();
    error InvalidKYCData();
    
    // Offering errors
    error OfferingLimitExceeded();
    error InvalidOfferingType();
    error NonAccreditedLimitExceeded();
    
    // Chainlink errors
    error InvalidRequestId();
    error OracleError();
    error InsufficientLINK();
    
    // CSA Derivatives errors
    error InvalidUTI();
    error InvalidDate();
    error InvalidNotionalAmount();
    error InvalidCurrency();
    error InvalidCollateral();
    error InvalidValuation();
    error DerivativeAlreadyReported();
    error DerivativeNotFound();
    error InvalidPosition();
    error InvalidUnderlyingDerivative();
    
    // Price feed errors
    error InvalidPrice();
    error PriceFeedError();
    error StalePrice();
    
    // IPFS errors
    error InvalidIPFSCID();
    
    // Clearstream errors
    error SettlementNotFound();
    error InvalidSettlementStatus();
    error NoClearstreamAccount();
    error InsufficientAvailableBalance();
    error InvalidISIN();
    error InvalidCSDAccount();
    
    // Registry errors
    error InvalidLEI();
    error InvalidUPI();
    
    // Test function errors (for development only)
    error TestFunctionDisabled();
}