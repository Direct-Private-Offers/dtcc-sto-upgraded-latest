// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICLEARSTREAMIntegration
 * @dev Combined Interface for Clearstream DVP Settlement with all required structs
 */
interface ICLEARSTREAMIntegration {
    
    // ========================================
    // Enums
    // ========================================
    
    enum ClearstreamSettlementStatus {
        PENDING,
        INSTRUCTED,
        CONFIRMED,
        SETTLED,
        FAILED,
        CANCELLED
    }
    
    enum ClearstreamInstructionType {
        DELIVERY,
        RECEIPT,
        PAYMENT,
        RECEIVE_FUNDS
    }
    
    enum ClearstreamInstructionStatus {
        PENDING,
        SENT_TO_CSD,
        CONFIRMED_BY_CSD,
        EXECUTED,
        REJECTED,
        CANCELLED
    }
    
    enum ClearstreamEventType {
        SETTLEMENT_INITIATED,
        INSTRUCTION_SENT,
        SETTLEMENT_CONFIRMED,
        SETTLEMENT_COMPLETED,
        SETTLEMENT_FAILED,
        POSITION_UPDATED,
        CORPORATE_ACTION
    }
    
    // ========================================
    // Structs
    // ========================================
    
    struct ClearstreamSettlement {
        bytes32 settlementId;
        bytes32 tradeReference;
        address buyer;
        address seller;
        uint256 quantity;
        uint256 settlementAmount;
        ClearstreamSettlementStatus status;
        uint256 settlementDate;
        uint256 valueDate;
        bytes20 buyerAccount;
        bytes20 sellerAccount;
        string isin;
        bytes32 instructionReference;
    }
    
    struct ClearstreamInstruction {
        bytes32 instructionId;
        ClearstreamInstructionType instructionType;
        bytes32 settlementId;
        address participant;
        bytes20 participantAccount;
        uint256 quantity;
        uint256 amount;
        ClearstreamInstructionStatus status;
        uint256 instructionDate;
        uint256 valueDate;
        string isin;
        bytes32 tradeReference;
    }
    
    struct ClearstreamEvent {
        bytes32 eventId;
        ClearstreamEventType eventType;
        bytes32 settlementId;
        string eventDescription;
        uint256 eventTimestamp;
        address triggeredBy;
        bytes32 referenceId;
    }
    
    struct ClearstreamPosition {
        bytes20 participantAccount;
        string isin;
        uint256 position;
        uint256 availableBalance;
        uint256 blockedBalance;
        uint256 lastUpdate;
    }
    
    struct ClearstreamConfig {
        bytes20 defaultCsdAccount;
        uint256 settlementCycle;
        bool autoSettlementEnabled;
        uint256 minSettlementAmount;
        string marketIdentifier;
        bytes20 operatingCsd;
    }
    
    // ========================================
    // Events
    // ========================================
    
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
    
    // ========================================
    // Errors
    // ========================================
    
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
    
    // ========================================
    // Functions
    // ========================================
    
    function initiateSettlement(
        bytes32 tradeReference,
        address buyer,
        address seller,
        uint256 quantity,
        uint256 settlementAmount,
        uint256 valueDate
    ) external returns (bytes32 settlementId);
    
    function generateSettlementInstructions(bytes32 settlementId) external;
    
    function confirmSettlement(bytes32 settlementId, bytes32 instructionReference) external;
    
    function completeSettlement(bytes32 settlementId) external;
    
    function linkClearstreamAccount(address investor, bytes20 csdAccount) external;
    
    function getClearstreamPosition(bytes20 csdAccount) external view returns (ClearstreamPosition memory);
    
    function updateClearstreamConfig(ClearstreamConfig memory newConfig) external;
    
    function addISINToWhitelist(string memory isin) external;
}
