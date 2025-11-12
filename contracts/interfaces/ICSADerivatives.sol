// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICSADerivatives {
    // Enums
    enum ActionType { NEWT, CANC, CORR, VALU, POSC, COLL, OTHR }
    enum EventType { TRAD, VALU, COLL, OTHR }
    enum OfferingType { REG_D_506B, REG_D_506C, REG_CF, RULE_144A, REG_A, REG_S }

    // Core Data Structures
    struct DerivativeData {
        bytes32 uti;
        bytes32 priorUti;
        bytes12 upi;
        uint256 effectiveDate;
        uint256 expirationDate;
        uint256 executionTimestamp;
        uint256 notionalAmount;
        string notionalCurrency;
        string productType;
        string underlyingAsset;
    }

    struct CounterpartyData {
        bytes20 lei;
        address walletAddress;
        string jurisdiction;
        bool isReportable;
    }

    struct CollateralData {
        uint256 collateralAmount;
        string collateralCurrency;
        string collateralType;
        uint256 valuationTimestamp;
    }

    struct ValuationData {
        uint256 marketValue;
        string valuationCurrency;
        uint256 valuationTimestamp;
        string valuationModel;
    }

    struct Investor {
        bool isVerified;
        bool isAccredited;
        bool isQIB;
        uint256 verificationDate;
        uint256 lastKycRefresh;
        uint256 totalInvested;
        bytes32[] issuanceIds;
    }

    struct Issuance {
        address investor;
        uint256 amount;
        string ipfsCID;
        uint256 timestamp;
        uint256 lockupEnd;
        bool verified;
        bool accredited;
    }

    // Events
    event DerivativeReported(
        bytes32 indexed uti,
        address indexed reporter,
        uint256 timestamp,
        ActionType action,
        EventType eventType
    );

    event DerivativeCorrected(
        bytes32 indexed uti,
        bytes32 indexed priorUti,
        address correctedBy,
        uint256 timestamp
    );

    event ErrorReported(
        bytes32 indexed uti,
        address indexed reporter,
        uint256 timestamp,
        string reason
    );

    event PositionReported(
        bytes32 indexed positionId,
        address indexed reporter,
        uint256 timestamp,
        ActionType action
    );

    event InvestorVerified(
        address indexed investor,
        bool accredited,
        uint256 timestamp
    );

    event DACVerified(
        bytes32 indexed issuanceId,
        string ipfsCID,
        uint256 timestamp
    );

    event ComplianceOverride(
        address indexed complianceOfficer,
        address indexed investor,
        string reason
    );

    event TransferLockUpdated(
        address indexed investor,
        uint256 unlockTime
    );

    event OfferingTypeSet(
        OfferingType offeringType,
        uint256 timestamp
    );

    event QIBVerified(
        address indexed investor,
        bool isQIB,
        uint256 timestamp
    );

    event RegCFInvestment(
        address indexed investor,
        uint256 amount,
        uint256 totalRaised
    );

    event CSAComplianceCheck(
        address indexed participant,
        bytes20 lei,
        bool compliant,
        uint256 timestamp
    );

    event TradeReported(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 price,
        bytes32 dtccRef,
        uint256 timestamp
    );

    event CSATradeDataReported(
        bytes32 indexed csaRef,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );

    // Functions
    function reportDerivative(
        DerivativeData calldata derivativeData,
        CounterpartyData calldata counterparty1,
        CounterpartyData calldata counterparty2,
        CollateralData calldata collateralData,
        ValuationData calldata valuationData
    ) external returns (bytes32 uti);

    function correctDerivative(
        bytes32 uti,
        bytes32 priorUti,
        DerivativeData calldata correctedData
    ) external;

    function reportError(
        bytes32 uti,
        string calldata reason
    ) external;

    function reportPosition(
        bytes32 positionId,
        bytes32[] calldata underlyingUtis,
        ValuationData calldata valuationData
    ) external;

    function batchReportDerivatives(
        DerivativeData[] calldata derivativesData,
        CounterpartyData[] calldata counterparties1,
        CounterpartyData[] calldata counterparties2,
        CollateralData[] calldata collateralData,
        ValuationData[] calldata valuationData
    ) external;
}