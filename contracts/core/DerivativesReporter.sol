// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/ICSADerivatives.sol";
import "../interfaces/ILEIRegistry.sol";
import "../interfaces/IUPIProvider.sol";
import "../interfaces/ITradeRepository.sol";
import "../lib/CSADerivativesLib.sol";
import "../utils/Errors.sol";

/**
 * @title DerivativesReporter
 * @dev Standalone contract for CSA derivatives reporting with DTCC compliance
 * @notice This contract handles derivative reporting, validation, and error tracking
 */
contract DerivativesReporter is AccessControl, Pausable, ReentrancyGuard, ICSADerivatives {
    using CSADerivativesLib for *;
    
    // Roles
    bytes32 public constant DERIVATIVES_REPORTER = keccak256("DERIVATIVES_REPORTER");
    
    // External registries
    ILEIRegistry public leiRegistry;
    IUPIProvider public upiProvider;
    ITradeRepository public tradeRepository;
    
    // Storage
    mapping(bytes32 => DerivativeData) public derivatives;
    mapping(bytes32 => CSAErrorReport[]) public derivativeErrors;
    mapping(bytes32 => bool) private reportedUtis;
    
    // Structures
    struct CSAErrorReport {
        bytes32 uti;
        string reason;
        uint256 timestamp;
        address reportedBy;
    }
    
    // Events (inherited from ICSADerivatives)
    
    /**
     * @dev Constructor
     * @param _leiRegistry Address of LEI registry
     * @param _upiProvider Address of UPI provider
     * @param _tradeRepository Address of trade repository
     */
    constructor(
        address _leiRegistry,
        address _upiProvider,
        address _tradeRepository
    ) {
        if (_leiRegistry == address(0)) revert Errors.ZeroAddress();
        if (_upiProvider == address(0)) revert Errors.ZeroAddress();
        if (_tradeRepository == address(0)) revert Errors.ZeroAddress();
        
        leiRegistry = ILEIRegistry(_leiRegistry);
        upiProvider = IUPIProvider(_upiProvider);
        tradeRepository = ITradeRepository(_tradeRepository);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Report a new derivative
     * @param derivativeData Derivative data structure
     * @param counterparty1 First counterparty data
     * @param counterparty2 Second counterparty data
     * @param collateralData Collateral data
     * @param valuationData Valuation data
     * @return uti Unique Trade Identifier
     */
    function reportDerivative(
        DerivativeData calldata derivativeData,
        CounterpartyData calldata counterparty1,
        CounterpartyData calldata counterparty2,
        CollateralData calldata collateralData,
        ValuationData calldata valuationData
    ) external override onlyRole(DERIVATIVES_REPORTER) whenNotPaused nonReentrant returns (bytes32) {
        // Validate UTI
        if (derivativeData.uti == bytes32(0)) revert Errors.InvalidUTI();
        if (reportedUtis[derivativeData.uti]) revert Errors.DerivativeAlreadyReported();
        
        // Validate LEIs
        if (!leiRegistry.isValidLEI(counterparty1.lei)) revert Errors.InvalidLEI();
        if (!leiRegistry.isValidLEI(counterparty2.lei)) revert Errors.InvalidLEI();
        
        // Validate UPI
        if (!upiProvider.isValidUPI(derivativeData.upi)) revert Errors.InvalidUPI();
        
        // Validate derivative data
        if (!CSADerivativesLib.isValidCSADate(derivativeData.effectiveDate)) revert Errors.InvalidDate();
        if (!CSADerivativesLib.isValidCSADate(derivativeData.expirationDate)) revert Errors.InvalidDate();
        if (!CSADerivativesLib.isValidExecutionTimestamp(derivativeData.executionTimestamp)) revert Errors.InvalidDate();
        if (!CSADerivativesLib.isValidCSANotionalAmount(derivativeData.notionalAmount)) revert Errors.InvalidNotionalAmount();
        if (!CSADerivativesLib.isValidCSACurrency(derivativeData.notionalCurrency)) revert Errors.InvalidCurrency();
        
        // Validate counterparties
        if (!CSADerivativesLib.validateCSACounterparty(
            counterparty1.lei,
            counterparty1.walletAddress,
            counterparty1.jurisdiction
        )) revert Errors.InvalidCounterparty();
        
        if (!CSADerivativesLib.validateCSACounterparty(
            counterparty2.lei,
            counterparty2.walletAddress,
            counterparty2.jurisdiction
        )) revert Errors.InvalidCounterparty();
        
        // Validate collateral
        if (!CSADerivativesLib.validateCollateralData(collateralData)) revert Errors.InvalidCollateral();
        
        // Validate valuation
        if (!CSADerivativesLib.validateValuationData(valuationData)) revert Errors.InvalidValuation();
        
        // Store derivative
        derivatives[derivativeData.uti] = derivativeData;
        reportedUtis[derivativeData.uti] = true;
        
        // Submit to trade repository
        tradeRepository.submitTrade(
            derivativeData.uti,
            derivativeData.priorUti,
            derivativeData.upi,
            counterparty1.lei,
            counterparty2.lei,
            derivativeData.effectiveDate,
            derivativeData.expirationDate,
            derivativeData.executionTimestamp,
            derivativeData.notionalAmount,
            derivativeData.notionalCurrency
        );
        
        // Emit event
        emit DerivativeReported(
            derivativeData.uti,
            msg.sender,
            block.timestamp,
            ActionType.NEWT,
            EventType.TRAD
        );
        
        return derivativeData.uti;
    }
    
    /**
     * @dev Correct a previously reported derivative
     * @param uti Unique Trade Identifier
     * @param priorUti Prior UTI reference
     * @param correctedData Corrected derivative data
     */
    function correctDerivative(
        bytes32 uti,
        bytes32 priorUti,
        DerivativeData calldata correctedData
    ) external override onlyRole(DERIVATIVES_REPORTER) whenNotPaused nonReentrant {
        if (!reportedUtis[uti]) revert Errors.DerivativeNotFound();
        
        derivatives[uti] = correctedData;
        
        tradeRepository.correctTrade(uti, priorUti);
        
        emit DerivativeCorrected(
            uti,
            priorUti,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @dev Report an error for an existing derivative
     * @param uti Unique Trade Identifier
     * @param reason Error reason
     */
    function reportError(
        bytes32 uti,
        string calldata reason
    ) external override onlyRole(DERIVATIVES_REPORTER) whenNotPaused nonReentrant {
        if (!reportedUtis[uti]) revert Errors.DerivativeNotFound();
        
        derivativeErrors[uti].push(CSAErrorReport({
            uti: uti,
            reason: reason,
            timestamp: block.timestamp,
            reportedBy: msg.sender
        }));
        
        tradeRepository.reportError(uti, reason);
        
        emit ErrorReported(
            uti,
            msg.sender,
            block.timestamp,
            reason
        );
    }
    
    /**
     * @dev Report a position
     * @param positionId Position identifier
     * @param underlyingUtis Array of underlying UTIs
     * @param valuationData Valuation data
     */
    function reportPosition(
        bytes32 positionId,
        bytes32[] calldata underlyingUtis,
        ValuationData calldata valuationData
    ) external override onlyRole(DERIVATIVES_REPORTER) whenNotPaused nonReentrant {
        if (underlyingUtis.length == 0) revert Errors.InvalidInput();
        if (!CSADerivativesLib.validateValuationData(valuationData)) revert Errors.InvalidValuation();
        
        // Validate all underlying derivatives exist
        for (uint256 i = 0; i < underlyingUtis.length; i++) {
            if (!reportedUtis[underlyingUtis[i]]) revert Errors.InvalidUnderlyingDerivative();
        }
        
        emit PositionReported(
            positionId,
            msg.sender,
            block.timestamp,
            ActionType.POSC
        );
    }
    
    /**
     * @dev Batch report multiple derivatives
     * @param derivativesData Array of derivative data
     * @param counterparties1 Array of first counterparty data
     * @param counterparties2 Array of second counterparty data
     * @param collateralData Array of collateral data
     * @param valuationData Array of valuation data
     */
    function batchReportDerivatives(
        DerivativeData[] calldata derivativesData,
        CounterpartyData[] calldata counterparties1,
        CounterpartyData[] calldata counterparties2,
        CollateralData[] calldata collateralData,
        ValuationData[] calldata valuationData
    ) external override onlyRole(DERIVATIVES_REPORTER) whenNotPaused nonReentrant {
        uint256 length = derivativesData.length;
        if (length == 0) revert Errors.InvalidInput();
        if (length != counterparties1.length || 
            length != counterparties2.length || 
            length != collateralData.length || 
            length != valuationData.length) {
            revert Errors.InvalidInput();
        }
        
        for (uint256 i = 0; i < length; i++) {
            this.reportDerivative(
                derivativesData[i],
                counterparties1[i],
                counterparties2[i],
                collateralData[i],
                valuationData[i]
            );
        }
    }
    
    /**
     * @dev Get derivative data
     * @param uti Unique Trade Identifier
     * @return Derivative data structure
     */
    function getDerivative(bytes32 uti) external view returns (DerivativeData memory) {
        if (!reportedUtis[uti]) revert Errors.DerivativeNotFound();
        return derivatives[uti];
    }
    
    /**
     * @dev Get error reports for a derivative
     * @param uti Unique Trade Identifier
     * @return Array of error reports
     */
    function getErrorReports(bytes32 uti) external view returns (CSAErrorReport[] memory) {
        return derivativeErrors[uti];
    }
    
    /**
     * @dev Check if a derivative has been reported
     * @param uti Unique Trade Identifier
     * @return true if reported
     */
    function isDerivativeReported(bytes32 uti) external view returns (bool) {
        return reportedUtis[uti];
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}

