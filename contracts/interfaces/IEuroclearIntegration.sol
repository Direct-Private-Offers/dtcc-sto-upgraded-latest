// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1400/ERC1400.sol";
import "./IDTCCCompliantSTO.sol";
import "./ICSADerivatives.sol";

interface IEuroclearIntegration {
    // Events
    event SecurityTokenized(
        bytes32 indexed isin,
        address indexed tokenAddress,
        address indexed investor,
        uint256 amount,
        bytes32 euroclearRef,
        bytes32 issuanceId
    );
    
    event CorporateActionProcessed(
        bytes32 indexed isin,
        string actionType,
        uint256 effectiveDate,
        bytes32 euroclearRef
    );
    
    event SettlementCompleted(
        bytes32 indexed tradeRef,
        bytes32 indexed isin,
        address from,
        address to,
        uint256 amount,
        bytes32 euroclearRef
    );

    event EuroclearDerivativeReported(
        bytes32 indexed uti,
        bytes32 indexed isin,
        address reporter,
        uint256 timestamp
    );

    // Data Structures
    struct SecurityDetails {
        bytes32 isin;
        string description;
        string currency;
        uint256 issueDate;
        uint256 maturityDate;
        uint256 totalSupply;
        string issuerName;
        bytes12 upi; // Universal Product Identifier
        bytes20 issuerLEI; // Legal Entity Identifier
    }

    struct CorporateAction {
        bytes32 isin;
        string actionType; // DIVIDEND, SPLIT, MERGER, etc.
        uint256 effectiveDate;
        uint256 recordDate;
        bytes32 reference;
        bytes data; // Action-specific data
    }

    struct EuroclearDerivativeData {
        bytes32 isin;
        ICSADerivatives.DerivativeData derivativeData;
        ICSADerivatives.CounterpartyData counterparty1;
        ICSADerivatives.CounterpartyData counterparty2;
        ICSADerivatives.CollateralData collateralData;
        ICSADerivatives.ValuationData valuationData;
    }

    // Functions
    function tokenizeSecurity(
        bytes32 isin,
        address investor,
        uint256 amount,
        bytes32 euroclearRef,
        string calldata ipfsCID
    ) external returns (bytes32 issuanceId);

    function processCorporateAction(
        CorporateAction calldata action
    ) external;

    function syncSettlement(
        bytes32 tradeRef,
        bytes32 isin,
        address from,
        address to,
        uint256 amount,
        bytes32 euroclearRef
    ) external;

    function reportEuroclearDerivative(
        EuroclearDerivativeData calldata euroclearDerivative
    ) external returns (bytes32 uti);

    function getSecurityDetails(bytes32 isin) external view returns (SecurityDetails memory);

    function validateInvestor(
        bytes32 isin,
        address investor
    ) external view returns (bool isValid, string memory reason);

    function getEuroclearNAV(bytes32 isin) external view returns (uint256 nav);
}