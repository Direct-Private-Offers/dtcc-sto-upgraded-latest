// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICLEARSTREAMIntegration
 * @dev Combined Error Library and Interface for Clearstream DVP Settlement
 */
interface ICLEARSTREAMIntegration {
    
    // --- Events (The missing pieces required by DTCCCompliantSTO) ---
    event ClearstreamConfigured(bytes20 indexed csdAccount, string isin, uint256 timestamp);
    event ClearstreamAccountLinked(address indexed investor, bytes20 csdAccount, uint256 timestamp);
    event IssuanceRecorded(address indexed investor, uint256 amount, bytes32 tradeId, uint256 timestamp);
    event ClearstreamSettlementInitiated(bytes32 indexed settlementId, bytes32 tradeReference, address buyer, address seller, uint256 quantity, uint256 timestamp);
    event ClearstreamSettlementConfirmed(bytes32 indexed settlementId, bytes32 instructionReference, uint256 timestamp);
    event ClearstreamSettlementCompleted(bytes32 indexed settlementId, uint256 timestamp);
    event ClearstreamConfigUpdated(bytes20 newCsdAccount, uint256 settlementCycle, uint256 timestamp);
    event ISINWhitelisted(string isin, uint256 timestamp);
    event ClearstreamTransferValidated(bytes32 indexed settlementId, address from, address to, uint256 amount, uint256 timestamp);
    event ClearstreamInstructionsGenerated(bytes32 indexed settlementId, bytes32 deliveryId, bytes32 receiptId, uint256 timestamp);
    event ClearstreamPositionUpdated(bytes20 indexed account, string isin, uint256 newPosition, uint256 timestamp);

    // --- Custom Errors (Moved from Library to Interface for better compatibility) ---
    error ZeroAddress();
    error ZeroAmount();
    error InvalidInput();
    error NotAuthorized();
    error TokensLocked();
    error TransferRestricted();
    error InvalidPartition();
    error NotVerified();
    error NotAccredited();
    error NotQIB();
    error AlreadyVerified();
    error InvalidKYCData();
    error OfferingLimitExceeded();
    error InvalidOfferingType();
    error NonAccreditedLimitExceeded();
    error InvalidRequestId();
    error OracleError();
    error InsufficientLINK();
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
    error InvalidPrice();
    error PriceFeedError();
    error StalePrice();
    error InvalidIPFSCID();
    error SettlementNotFound();
    error InvalidSettlementStatus();
    error NoClearstreamAccount();
    error InsufficientAvailableBalance();
    error InvalidISIN();
    error InvalidCSDAccount();
    error InvalidLEI();
    error InvalidUPI();
    error TestFunctionDisabled();
}
