// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "./modules/interfaces/ITokenCore.sol";
import "./modules/interfaces/IComplianceManager.sol";
import "./modules/interfaces/ICSADerivativesManager.sol";
import "./modules/interfaces/IClearstreamManager.sol";
import "./interfaces/IDTCCCompliantSTO.sol";
import "./interfaces/ICLEARSTREAMIntegration.sol";

/**
 * @title DTCCCompliantSTO
 * @dev Main orchestrator contract that delegates to specialized modules
 */
contract DTCCCompliantSTO is AccessControl, Pausable, ReentrancyGuard, IDTCCCompliantSTO {
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Module addresses
    ITokenCore public tokenCore;
    IComplianceManager public complianceManager;
    ICSADerivativesManager public derivativesManager;
    IClearstreamManager public clearstreamManager;
    
    // External dependencies
    AggregatorV3Interface public priceFeed;
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600;
    
    // Issuance tracking
    mapping(bytes32 => ICSADerivatives.Issuance) public issuances;
    mapping(address => bytes32[]) public investorIssuances;
    
    event ModulesUpdated(address tokenCore, address compliance, address derivatives, address clearstream);
    
    constructor(
        address tokenCore_,
        address complianceManager_,
        address derivativesManager_,
        address clearstreamManager_,
        address priceFeed_
    ) {
        require(tokenCore_ != address(0), "Invalid TokenCore");
        require(complianceManager_ != address(0), "Invalid ComplianceManager");
        require(derivativesManager_ != address(0), "Invalid DerivativesManager");
        require(clearstreamManager_ != address(0), "Invalid ClearstreamManager");
        require(priceFeed_ != address(0), "Invalid price feed");
        
        tokenCore = ITokenCore(tokenCore_);
        complianceManager = IComplianceManager(complianceManager_);
        derivativesManager = ICSADerivativesManager(derivativesManager_);
        clearstreamManager = IClearstreamManager(clearstreamManager_);
        priceFeed = AggregatorV3Interface(priceFeed_);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    // ========================================
    // ERC20/ERC1400 Functions (Delegated)
    // ========================================
    
    function name() external view returns (string memory) {
        return tokenCore.name();
    }
    
    function symbol() external view returns (string memory) {
        return tokenCore.symbol();
    }
    
    function decimals() external pure returns (uint8) {
        return 18;
    }
    
    function totalSupply() external view returns (uint256) {
        return tokenCore.totalSupply();
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return tokenCore.balanceOf(account);
    }
    
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        complianceManager.validateTransfer(msg.sender, to, amount);
        return tokenCore.transfer(msg.sender, to, amount);
    }
    
    function allowance(address owner, address spender) external view returns (uint256) {
        return tokenCore.allowance(owner, spender);
    }
    
    function approve(address spender, uint256 amount) external whenNotPaused returns (bool) {
        return tokenCore.approve(msg.sender, spender, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        complianceManager.validateTransfer(from, to, amount);
        return tokenCore.transferFrom(msg.sender, from, to, amount);
    }
    
    // ERC1400 Partition Functions
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256) {
        return tokenCore.balanceOfByPartition(partition, tokenHolder);
    }
    
    function partitionsOf(address tokenHolder) external view returns (bytes32[] memory) {
        return tokenCore.partitionsOf(tokenHolder);
    }
    
    function transferByPartition(
        bytes32 partition,
        address to,
        uint256 value,
        bytes calldata data
    ) external whenNotPaused returns (bytes32) {
        complianceManager.validateTransfer(msg.sender, to, value);
        return tokenCore.transferByPartition(partition, msg.sender, msg.sender, to, value, data, "");
    }
    
    // ========================================
    // Issuance Functions
    // ========================================
    
    function issueTokens(
        address investor,
        uint256 amount,
        string calldata ipfsCID,
        uint256 lockupPeriod,
        bytes20 csdAccount
    ) external override onlyRole(ISSUER_ROLE) whenNotPaused returns (bytes32 issuanceId) {
        require(investor != address(0), "Invalid investor");
        require(amount > 0, "Amount must be > 0");
        
        // Create issuance record
        issuanceId = keccak256(abi.encodePacked(investor, block.timestamp, amount, ipfsCID));
        
        issuances[issuanceId] = ICSADerivatives.Issuance({
            investor: investor,
            amount: amount,
            ipfsCID: ipfsCID,
            timestamp: block.timestamp,
            lockupEnd: lockupPeriod > 0 ? block.timestamp + lockupPeriod : 0,
            verified: false,
            accredited: complianceManager.isAccredited(investor)
        });
        
        investorIssuances[investor].push(issuanceId);
        
        // Mint tokens (using default partition)
        bytes32[] memory defaultPartitions = tokenCore.getDefaultPartitions();
        require(defaultPartitions.length > 0, "No default partitions");
        tokenCore.mint(investor, amount, defaultPartitions[0]);
        
        // Set transfer lock if applicable
        if (lockupPeriod > 0) {
            complianceManager.setTransferLock(investor, block.timestamp + lockupPeriod);
        }
        
        // Link Clearstream account if provided
        if (csdAccount != bytes20(0)) {
            clearstreamManager.linkClearstreamAccount(investor, csdAccount);
        }
        
        // Record investment for compliance
        complianceManager.recordInvestment(investor, amount);
        
        return issuanceId;
    }
    
    // ========================================
    // Compliance Functions (Delegated)
    // ========================================
    
    function verifyInvestor(
        address investor,
        string calldata kycProviderURL,
        bool /* refreshIfVerified */
    ) external override onlyRole(COMPLIANCE_OFFICER) returns (bytes32) {
        return complianceManager.verifyInvestor(investor, kycProviderURL);
    }
    
    function setTransferLock(address investor, uint256 unlockTime) external override onlyRole(COMPLIANCE_OFFICER) {
        complianceManager.setTransferLock(investor, unlockTime);
    }
    
    function forceTransfer(
        address from,
        address to,
        uint256 amount,
        string calldata reason
    ) external override onlyRole(COMPLIANCE_OFFICER) nonReentrant whenNotPaused {
        require(bytes(reason).length > 0, "Reason required");
        tokenCore.transferFrom(msg.sender, from, to, amount);
        emit ICSADerivatives.ComplianceOverride(msg.sender, from, reason);
    }
    
    function setOfferingType(ICSADerivatives.OfferingType offeringType) external override onlyRole(COMPLIANCE_OFFICER) {
        complianceManager.setOfferingType(offeringType);
    }
    
    function verifyQIB(address investor, bool isQIB_) external override onlyRole(COMPLIANCE_OFFICER) {
        complianceManager.setQIBStatus(investor, isQIB_);
    }
    
    function isQIB(address investor) external view override returns (bool) {
        return complianceManager.isQIB(investor);
    }
    
    // ========================================
    // KYC Management
    // ========================================
    
    function setKYC(address user, bool approved, uint64 expiry) external onlyRole(COMPLIANCE_OFFICER) {
        complianceManager.setKYC(user, approved, expiry);
    }
    
    function isKYCValid(address user) public view returns (bool) {
        return complianceManager.isKYCValid(user);
    }
    
    // ========================================
    // Derivative Functions (Delegated) - REMOVED override keyword
    // ========================================
    
    function reportDerivative(
        ICSADerivatives.DerivativeData calldata derivativeData,
        ICSADerivatives.CounterpartyData calldata counterparty1,
        ICSADerivatives.CounterpartyData calldata counterparty2,
        ICSADerivatives.CollateralData calldata collateralData,
        ICSADerivatives.ValuationData calldata valuationData
    ) external onlyRole(ISSUER_ROLE) whenNotPaused returns (bytes32) {
        return derivativesManager.reportDerivative(
            derivativeData,
            counterparty1,
            counterparty2,
            collateralData,
            valuationData
        );
    }
    
    function correctDerivative(
        bytes32 uti,
        bytes32 priorUti,
        ICSADerivatives.DerivativeData calldata correctedData
    ) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.correctDerivative(uti, priorUti, correctedData);
    }
    
    function reportError(
        bytes32 uti,
        string calldata reason
    ) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.reportError(uti, reason);
    }
    
    // ADD MISSING FUNCTIONS from ICSADerivatives
    function reportPosition(
        bytes32 positionId,
        bytes32[] calldata underlyingUtis,
        ICSADerivatives.ValuationData calldata valuationData
    ) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.reportPosition(positionId, underlyingUtis, valuationData);
    }
    
    function batchReportDerivatives(
        ICSADerivatives.DerivativeData[] calldata derivativesData,
        ICSADerivatives.CounterpartyData[] calldata counterparties1,
        ICSADerivatives.CounterpartyData[] calldata counterparties2,
        ICSADerivatives.CollateralData[] calldata collateralData,
        ICSADerivatives.ValuationData[] calldata valuationData
    ) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.batchReportDerivatives(
            derivativesData,
            counterparties1,
            counterparties2,
            collateralData,
            valuationData
        );
    }
    
    // ========================================
    // Clearstream Functions (Delegated) - REMOVED override keyword
    // ========================================
    
    function initiateSettlement(
        bytes32 tradeReference,
        address buyer,
        address seller,
        uint256 quantity,
        uint256 settlementAmount,
        uint256 valueDate
    ) external onlyRole(ISSUER_ROLE) whenNotPaused returns (bytes32) {
        return clearstreamManager.initiateSettlement(
            tradeReference,
            buyer,
            seller,
            quantity,
            settlementAmount,
            valueDate
        );
    }
    
    function generateSettlementInstructions(bytes32 settlementId) external onlyRole(ISSUER_ROLE) whenNotPaused {
        clearstreamManager.generateSettlementInstructions(settlementId);
    }
    
    function confirmSettlement(bytes32 settlementId, bytes32 instructionReference) external onlyRole(ISSUER_ROLE) whenNotPaused {
        clearstreamManager.confirmSettlement(settlementId, instructionReference);
    }
    
    function completeSettlement(bytes32 settlementId) external onlyRole(ISSUER_ROLE) whenNotPaused {
        clearstreamManager.completeSettlement(settlementId);
    }
    
    function linkClearstreamAccount(address investor, bytes20 csdAccount) external onlyRole(COMPLIANCE_OFFICER) {
        clearstreamManager.linkClearstreamAccount(investor, csdAccount);
    }
    
    // ========================================
    // View Functions
    // ========================================
    
    function getNAV() public view override returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= PRICE_STALENESS_THRESHOLD, "Stale price");
        
        uint256 totalSupply_ = tokenCore.totalSupply();
        if (totalSupply_ == 0) return 0;
        
        return (totalSupply_ * uint256(price)) / 10 ** priceFeed.decimals();
    }
    
    function getInvestorIssuances(address investor) external view returns (bytes32[] memory) {
        return investorIssuances[investor];
    }
    
    // ========================================
    // Admin Functions
    // ========================================
    
    function updateModules(
        address tokenCore_,
        address complianceManager_,
        address derivativesManager_,
        address clearstreamManager_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenCore_ != address(0)) tokenCore = ITokenCore(tokenCore_);
        if (complianceManager_ != address(0)) complianceManager = IComplianceManager(complianceManager_);
        if (derivativesManager_ != address(0)) derivativesManager = ICSADerivativesManager(derivativesManager_);
        if (clearstreamManager_ != address(0)) clearstreamManager = IClearstreamManager(clearstreamManager_);
        
        emit ModulesUpdated(tokenCore_, complianceManager_, derivativesManager_, clearstreamManager_);
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    // Required overrides from IDTCCCompliantSTO
    function fulfillVerification(bytes32, bool) external pure override {
        revert("Not implemented");
    }
}
