// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Errors {
    // General errors
    error ZeroAddress();
    error ZeroAmount();
    error InvalidInput();
    error NotAuthorized();
    error Paused();
    
    // Compliance errors
    error TransferNotCompliant();
    error InvalidInvestorStatus();
    error InvalidLEI();
    error InvalidUPI();
    error InvalidISIN();
    error AlreadyVerified();
    
    // CSA Derivatives errors
    error InvalidUTI();
    error InvalidDate();
    error InvalidNotionalAmount();
    error InvalidCurrency();
    error InvalidCounterparty();
    error InvalidProductType();
    
    // Clearstream errors
    error InvalidISINCode();
    error InvalidSettlementDate();
    error InvalidParticipant();
    error SettlementFailed();
    
    // Fineract errors
    error ClientNotSynced();
    error InvalidFineractConfig();
    error InvalidClientId();
    error InvalidOfficeId();
    error TransactionNotSynced();
    error InvalidPaymentType();
    error InvalidCurrencyCode();
    
    // Token errors
    error TransferLocked();
    error InsufficientBalance();
    error TransferToZeroAddress();
    error InvalidPartition();
    
    // Oracle errors
    error StalePrice();
    error InvalidOracleResponse();
    error InsufficientLink();
    
    // Multi-signature errors
    error InsufficientSignatures();
    error ApprovalExpired();
    error AlreadySigned();
    error NotASigner();
    
    // Dividend errors
    error InvalidDividendCycle();
    error DividendAlreadyClaimed();
    error InvalidRecordDate();
    error DividendNotDistributed();
    error InvalidIPFSCID();
    
    // DPO Global errors
    error InvalidChain();
    error SwapFailed();
    error NotWhitelisted();
    
    // Sanctions errors
    error SanctionedAddress();
    error ScreeningFailed();
    
    // State channel errors
    error InvalidChannel();
    error ChannelExpired();
    error InvalidSignature();
    
    // Corporate action errors
    error InvalidCorporateAction();
    error ActionAlreadyExecuted();
    error InvalidEntitlementRatio();
}