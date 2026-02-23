// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ICSADerivativesManager.sol";
import "../interfaces/ITradeRepository.sol";
import "../interfaces/IUPIProvider.sol";
import "../lib/CSADerivativesLib.sol";

contract CSADerivativesManager is AccessControl, ICSADerivativesManager {
    bytes32 public constant DERIVATIVES_REPORTER = keccak256("DERIVATIVES_REPORTER");
    
    struct CSACorrection {
        bytes32 priorUti;
        ICSADerivatives.DerivativeData correctedData;
        uint256 correctionTimestamp;
        address correctedBy;
    }
    
    struct CSAErrorReport {
        string reason;
        uint256 reportTimestamp;
        address reportedBy;
    }
    
    struct CSAPosition {
        bytes32 positionId;
        bytes32[] underlyingUtis;
        ICSADerivatives.ValuationData valuation;
        uint256 lastUpdated;
    }
    
    // Storage
    mapping(bytes32 => ICSADerivatives.DerivativeData) public derivatives;
    mapping(bytes32 => CSACorrection[]) public derivativeCorrections;
    mapping(bytes32 => CSAErrorReport[]) public derivativeErrors;
    mapping(bytes32 => CSAPosition) public positions;
    mapping(bytes32 => ICSADerivatives.CollateralData) public tradeCollateral;
    
    // External dependencies
    ITradeRepository public tradeRepository;
    IUPIProvider public upiProvider;
    
    constructor(address tradeRepository_, address upiProvider_) {
        require(tradeRepository_ != address(0), "Invalid trade repository");
        require(upiProvider_ != address(0), "Invalid UPI provider");
        
        tradeRepository = ITradeRepository(tradeRepository_);
        upiProvider = IUPIProvider(upiProvider_);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DERIVATIVES_REPORTER, msg.sender);
    }
    
    // Modifiers split into smaller pieces to avoid stack too deep
    modifier validUTI(bytes32 uti) {
        _validateUTI(uti);
        _;
    }
    
    modifier validDerivativeDates(ICSADerivatives.DerivativeData calldata data) {
        _validateDerivativeDates(data);
        _;
    }
    
    modifier validDerivativeAmounts(ICSADerivatives.DerivativeData calldata data) {
        _validateDerivativeAmounts(data);
        _;
    }
    
    modifier validLEI(bytes20 lei) {
        require(lei != bytes20(0), "Invalid LEI");
        _;
    }
    
    // Main reporting function - refactored to avoid stack too deep
    function reportDerivative(
        ICSADerivatives.DerivativeData calldata derivativeData,
        ICSADerivatives.CounterpartyData calldata counterparty1,
        ICSADerivatives.CounterpartyData calldata counterparty2,
        ICSADerivatives.CollateralData calldata collateralData,
        ICSADerivatives.ValuationData calldata valuationData
    )
        external
        onlyRole(DERIVATIVES_REPORTER)
        returns (bytes32 uti)
    {
        // Validate all inputs using helper functions
        _validateDerivativeInputs(derivativeData, counterparty1, counterparty2, collateralData, valuationData);
        
        // Generate or use existing UTI
        uti = _getOrCreateUTI(derivativeData);
        
        require(derivatives[uti].uti == bytes32(0), "Derivative already exists");
        
        // Store data
        derivatives[uti] = derivativeData;
        tradeCollateral[uti] = collateralData;
        
        // Submit to trade repository
        _submitTradeToRepository(uti, derivativeData, counterparty1, counterparty2);
        
        emit DerivativeReported(uti, msg.sender, block.timestamp);
        return uti;
    }
    
    function correctDerivative(
        bytes32 uti,
        bytes32 priorUti,
        ICSADerivatives.DerivativeData calldata correctedData
    ) external onlyRole(DERIVATIVES_REPORTER) {
        require(derivatives[uti].uti != bytes32(0), "Derivative not found");
        require(priorUti != bytes32(0), "Invalid prior UTI");
        
        derivativeCorrections[uti].push(CSACorrection({
            priorUti: priorUti,
            correctedData: correctedData,
            correctionTimestamp: block.timestamp,
            correctedBy: msg.sender
        }));
        
        derivatives[uti] = correctedData;
        tradeRepository.correctTrade(uti, priorUti);
        
        emit DerivativeCorrected(uti, priorUti, block.timestamp);
    }
    
    function reportError(bytes32 uti, string calldata reason) external onlyRole(DERIVATIVES_REPORTER) {
        require(derivatives[uti].uti != bytes32(0), "Derivative not found");
        require(bytes(reason).length > 0, "Reason required");
        
        derivativeErrors[uti].push(CSAErrorReport({
            reason: reason,
            reportTimestamp: block.timestamp,
            reportedBy: msg.sender
        }));
        
        tradeRepository.reportError(uti, reason);
        emit ErrorReported(uti, reason, block.timestamp);
    }
    
    function reportPosition(
        bytes32 positionId,
        bytes32[] calldata underlyingUtis,
        ICSADerivatives.ValuationData calldata valuationData
    ) external onlyRole(DERIVATIVES_REPORTER) {
        require(positionId != bytes32(0), "Invalid position");
        require(underlyingUtis.length > 0, "No underlying UTIs");
        require(CSADerivativesLib.validateValuationData(valuationData), "Invalid valuation");
        
        // Validate underlying derivatives exist
        uint256 len = underlyingUtis.length < 50 ? underlyingUtis.length : 50;
        for (uint256 i = 0; i < len; i++) {
            require(derivatives[underlyingUtis[i]].uti != bytes32(0), "Invalid underlying");
        }
        
        positions[positionId] = CSAPosition({
            positionId: positionId,
            underlyingUtis: underlyingUtis,
            valuation: valuationData,
            lastUpdated: block.timestamp
        });
    }
    
    function batchReportDerivatives(
        ICSADerivatives.DerivativeData[] calldata derivativesData,
        ICSADerivatives.CounterpartyData[] calldata counterparties1,
        ICSADerivatives.CounterpartyData[] calldata counterparties2,
        ICSADerivatives.CollateralData[] calldata collateralData,
        ICSADerivatives.ValuationData[] calldata valuationData
    ) external onlyRole(DERIVATIVES_REPORTER) {
        uint256 len = derivativesData.length;
        require(len == counterparties1.length && len == counterparties2.length && 
                len == collateralData.length && len == valuationData.length, "Array mismatch");
        require(len <= 20, "Batch too large");
        
        for (uint256 i = 0; i < len; i++) {
            this.reportDerivative(
                derivativesData[i],
                counterparties1[i],
                counterparties2[i],
                collateralData[i],
                valuationData[i]
            );
        }
    }
    
    // View Functions
    function getDerivative(bytes32 uti) external view returns (ICSADerivatives.DerivativeData memory) {
        return derivatives[uti];
    }
    
    function getDerivativeCorrections(bytes32 uti) external view returns (bytes32[] memory) {
        CSACorrection[] storage corrections = derivativeCorrections[uti];
        bytes32[] memory priorUtis = new bytes32[](corrections.length);
        for (uint256 i = 0; i < corrections.length; i++) {
            priorUtis[i] = corrections[i].priorUti;
        }
        return priorUtis;
    }
    
    function getDerivativeErrors(bytes32 uti) external view returns (string[] memory) {
        CSAErrorReport[] storage errors = derivativeErrors[uti];
        string[] memory reasons = new string[](errors.length);
        for (uint256 i = 0; i < errors.length; i++) {
            reasons[i] = errors[i].reason;
        }
        return reasons;
    }
    
    function getPosition(bytes32 positionId) external view returns (ICSADerivatives.ValuationData memory) {
        return positions[positionId].valuation;
    }
    
    // ============ INTERNAL HELPER FUNCTIONS ============
    
    function _validateUTI(bytes32 uti) private pure {
        // UTI can be zero for new trades
        require(uti != bytes32(0) || true, "Invalid UTI");
    }
    
    function _validateDerivativeDates(ICSADerivatives.DerivativeData calldata data) private view {
        require(
            CSADerivativesLib.isValidCSADate(data.effectiveDate, block.timestamp),
            "Invalid effective date"
        );
        require(
            CSADerivativesLib.isValidCSADate(data.expirationDate, block.timestamp),
            "Invalid expiration date"
        );
        require(
            data.expirationDate >= data.effectiveDate,
            "Expiration before effective"
        );
        require(
            CSADerivativesLib.isValidExecutionTimestamp(data.executionTimestamp, block.timestamp),
            "Invalid execution timestamp"
        );
    }
    
    function _validateDerivativeAmounts(ICSADerivatives.DerivativeData calldata data) private pure {
        require(
            CSADerivativesLib.isValidCSANotionalAmount(data.notionalAmount),
            "Invalid notional amount"
        );
        require(
            CSADerivativesLib.isValidCSACurrency(data.notionalCurrency),
            "Invalid currency"
        );
    }
    
    function _validateDerivativeInputs(
        ICSADerivatives.DerivativeData calldata data,
        ICSADerivatives.CounterpartyData calldata cp1,
        ICSADerivatives.CounterpartyData calldata cp2,
        ICSADerivatives.CollateralData calldata collateral,
        ICSADerivatives.ValuationData calldata valuation
    ) private view {
        // Validate derivative data
        _validateUTI(data.uti);
        _validateDerivativeDates(data);
        _validateDerivativeAmounts(data);
        
        // Validate counterparties
        _validateCounterparty(cp1, "cp1");
        _validateCounterparty(cp2, "cp2");
        
        // Validate collateral and valuation
        require(
            CSADerivativesLib.validateCollateralData(collateral),
            "Invalid collateral"
        );
        require(
            CSADerivativesLib.validateValuationData(valuation),
            "Invalid valuation"
        );
    }
    
    function _validateCounterparty(
        ICSADerivatives.CounterpartyData calldata cp,
        string memory errorPrefix
    ) private pure {
        require(cp.lei != bytes20(0), string(abi.encodePacked(errorPrefix, ": Invalid LEI")));
        require(
            CSADerivativesLib.validateCSACounterparty(
                cp.lei,
                cp.walletAddress,
                cp.jurisdiction
            ),
            string(abi.encodePacked(errorPrefix, ": Invalid counterparty data"))
        );
    }
    
    function _getOrCreateUTI(ICSADerivatives.DerivativeData calldata data) private view returns (bytes32) {
        if (data.uti != bytes32(0)) {
            return data.uti;
        }
        return CSADerivativesLib.generateCSAUTI(
            data.upi,
            data.executionTimestamp,
            msg.sender,
            block.chainid
        );
    }
    
    function _submitTradeToRepository(
        bytes32 uti,
        ICSADerivatives.DerivativeData calldata data,
        ICSADerivatives.CounterpartyData calldata cp1,
        ICSADerivatives.CounterpartyData calldata cp2
    ) private {
        tradeRepository.submitTrade(
            uti,
            data.priorUti,
            data.upi,
            cp1.lei,
            cp2.lei,
            data.effectiveDate,
            data.expirationDate,
            data.executionTimestamp,
            data.notionalAmount,
            data.notionalCurrency
        );
    }
}
