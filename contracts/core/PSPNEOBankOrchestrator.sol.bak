// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/IBillBittsPSP.sol";
import "./interfaces/IDTCCCompliantSTO.sol";
import "./interfaces/IBrokerDealer.sol";
import "./interfaces/IForexPSPIntegration.sol";
import "./interfaces/IMonitoringHub.sol";
import "./lib/PSPOrchestrationLib.sol";
import "./lib/AuditTrailLib.sol";

/**
 * @title PSPNEOBankOrchestrator
 * @dev Complete PSP orchestration as NEO Bank with BD integration and token issuance flows
 * @notice Orchestrates PSP flows, broker-dealer integration, token issuance, and comprehensive monitoring
 */
contract PSPNEOBankOrchestrator is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // Roles
    bytes32 public constant PSP_ORCHESTRATOR = keccak256("PSP_ORCHESTRATOR");
    bytes32 public constant BD_INTEGRATOR = keccak256("BD_INTEGRATOR");
    bytes32 public constant TOKEN_ISSUER = keccak256("TOKEN_ISSUER");
    bytes32 public constant MONITORING_OPERATOR = keccak256("MONITORING_OPERATOR");
    bytes32 public constant AUDIT_MANAGER = keccak256("AUDIT_MANAGER");
    
    // Core integrations
    IBillBittsPSP public billBittsPSP;
    IDTCCCompliantSTO public dtccSTO;
    IBrokerDealer public brokerDealer;
    IForexPSPIntegration public forexIntegration;
    IMonitoringHub public monitoringHub;
    
    // PSP NEO Bank State
    mapping(bytes32 => PSPFlow) public pspFlows;
    mapping(bytes32 => BDIntegration) public bdIntegrations;
    mapping(bytes32 => TokenIssuanceFlow) public tokenIssuances;
    mapping(bytes32 => CustomerAccount) public customerAccounts;
    mapping(address => bytes32[]) public customerFlows;
    
    // Configuration
    PSPNEOConfig public pspConfig;
    BDIntegrationConfig public bdConfig;
    TokenIssuanceConfig public tokenConfig;
    MonitoringConfig public monitoringConfig;
    
    // Audit & Monitoring
    mapping(bytes32 => AuditTrail) public auditTrails;
    mapping(bytes32 => MonitoringAlert[]) public monitoringAlerts;
    
    // Constants
    address public constant PSP_TREASURY = 0x...; // Bill Bitts PSP treasury
    uint256 public constant MAX_DAILY_FLOW = 1000000 * 10**18; // $1M daily limit
    
    // Structures
    struct PSPFlow {
        bytes32 flowId;
        PSPFlowType flowType;
        address customer;
        uint256 amount;
        string currency;
        PSPFlowStatus status;
        uint256 initiationTime;
        uint256 completionTime;
        bytes32 bdReference;
        bytes32 tokenReference;
        string flowDetails;
        AuditData auditData;
    }
    
    struct BDIntegration {
        bytes32 integrationId;
        address brokerDealer;
        address investor;
        uint256 investmentAmount;
        string investmentType;
        BDIntegrationStatus status;
        uint256 integrationTime;
        bytes32 pspFlowReference;
        bytes32 tokenIssuanceReference;
    }
    
    struct TokenIssuanceFlow {
        bytes32 issuanceId;
        address investor;
        uint256 tokenAmount;
        uint256 investmentAmount;
        string offeringType;
        TokenIssuanceStatus status;
        uint256 issuanceTime;
        bytes32 pspFlowReference;
        bytes32 bdReference;
        string complianceData;
    }
    
    struct CustomerAccount {
        bytes32 accountId;
        address customer;
        string accountType; // INDIVIDUAL, CORPORATE, INSTITUTIONAL
        uint256 totalDeposits;
        uint256 totalWithdrawals;
        uint256 accountBalance;
        string currency;
        uint256 accountOpened;
        bool kycVerified;
        bool amlCleared;
        string riskRating;
    }
    
    struct PSPNEOConfig {
        uint256 maxDailyFlowAmount;
        uint256 minTransactionAmount;
        uint256 maxTransactionAmount;
        uint256 pspFeePercentage;
        address pspTreasuryWallet;
        bool autoSettlementEnabled;
        uint256 settlementDelay;
    }
    
    struct BDIntegrationConfig {
        address[] approvedBrokerDealers;
        uint256 bdCommissionPercentage;
        uint256 minInvestmentAmount;
        uint256 maxInvestmentAmount;
        bool autoTokenIssuanceEnabled;
    }
    
    struct TokenIssuanceConfig {
        uint256 minTokenAllocation;
        uint256 maxTokenAllocation;
        string[] supportedOfferingTypes;
        bool autoComplianceCheck;
        uint256 issuanceDelay;
    }
    
    struct MonitoringConfig {
        uint256 alertThresholdAmount;
        uint256 suspiciousPatternCount;
        bool realTimeMonitoringEnabled;
        address monitoringService;
        uint256 auditRetentionPeriod;
    }
    
    struct AuditData {
        bytes32 auditId;
        address performedBy;
        uint256 auditTimestamp;
        string auditAction;
        bytes32 previousState;
        bytes32 newState;
        string auditNotes;
    }
    
    struct MonitoringAlert {
        bytes32 alertId;
        MonitoringAlertType alertType;
        address subject;
        uint256 amount;
        string alertDescription;
        uint256 alertTimestamp;
        MonitoringAlertStatus status;
        string resolutionNotes;
    }
    
    // Enums
    enum PSPFlowType {
        DEPOSIT,
        WITHDRAWAL,
        TRANSFER,
        FOREX_CONVERSION,
        TOKEN_PURCHASE,
        DIVIDEND_DISTRIBUTION,
        INTEREST_PAYMENT
    }
    
    enum PSPFlowStatus {
        INITIATED,
        VALIDATED,
        PROCESSING,
        COMPLETED,
        FAILED,
        SUSPENDED,
        AUDIT_REQUIRED
    }
    
    enum BDIntegrationStatus {
        PENDING_APPROVAL,
        APPROVED,
        FUNDS_RECEIVED,
        TOKENS_ISSUED,
        COMPLETED,
        REJECTED
    }
    
    enum TokenIssuanceStatus {
        PENDING_FUNDS,
        COMPLIANCE_CHECK,
        TOKENS_MINTED,
        DISTRIBUTED,
        FAILED
    }
    
    enum MonitoringAlertType {
        LARGE_TRANSACTION,
        SUSPICIOUS_PATTERN,
        COMPLIANCE_VIOLATION,
        SYSTEM_ANOMALY,
        FRAUD_DETECTED
    }
    
    enum MonitoringAlertStatus {
        OPEN,
        INVESTIGATING,
        RESOLVED,
        FALSE_POSITIVE,
        ESCALATED
    }
    
    // Events
    event PSPFlowInitiated(
        bytes32 indexed flowId,
        PSPFlowType flowType,
        address customer,
        uint256 amount,
        string currency,
        uint256 timestamp
    );
    
    event PSPFlowCompleted(
        bytes32 indexed flowId,
        PSPFlowStatus status,
        uint256 completionTime,
        bytes32 bdReference,
        bytes32 tokenReference
    );
    
    event BDIntegrationInitiated(
        bytes32 indexed integrationId,
        address brokerDealer,
        address investor,
        uint256 investmentAmount,
        string investmentType,
        uint256 timestamp
    );
    
    event TokenIssuanceExecuted(
        bytes32 indexed issuanceId,
        address investor,
        uint256 tokenAmount,
        uint256 investmentAmount,
        string offeringType,
        uint256 issuanceTime
    );
    
    event CustomerAccountCreated(
        bytes32 indexed accountId,
        address customer,
        string accountType,
        uint256 initialDeposit,
        string currency,
        uint256 timestamp
    );
    
    event MonitoringAlertGenerated(
        bytes32 indexed alertId,
        MonitoringAlertType alertType,
        address subject,
        uint256 amount,
        string description,
        uint256 timestamp
    );
    
    event AuditTrailRecorded(
        bytes32 indexed auditId,
        bytes32 flowId,
        address auditor,
        string action,
        string notes,
        uint256 timestamp
    );
    
    event PSPOrchestrationCompleted(
        bytes32 flowId,
        bytes32 bdIntegrationId,
        bytes32 tokenIssuanceId,
        address customer,
        uint256 totalAmount,
        uint256 completionTime
    );
    
    // Modifiers
    modifier onlyPSPOrchestrator() {
        require(hasRole(PSP_ORCHESTRATOR, msg.sender), "Caller is not PSP orchestrator");
        _;
    }
    
    modifier onlyBDIntegrator() {
        require(hasRole(BD_INTEGRATOR, msg.sender), "Caller is not BD integrator");
        _;
    }
    
    modifier onlyTokenIssuer() {
        require(hasRole(TOKEN_ISSUER, msg.sender), "Caller is not token issuer");
        _;
    }
    
    modifier onlyMonitoringOperator() {
        require(hasRole(MONITORING_OPERATOR, msg.sender), "Caller is not monitoring operator");
        _;
    }
    
    modifier onlyAuditManager() {
        require(hasRole(AUDIT_MANAGER, msg.sender), "Caller is not audit manager");
        _;
    }
    
    modifier validCustomer(address _customer) {
        require(customerAccounts[_getAccountId(_customer)].accountId != bytes32(0), "Customer account not found");
        _;
    }
    
    /**
     * @dev Constructor for PSP NEO Bank Orchestrator
     */
    constructor(
        address _billBittsPSP,
        address _dtccSTO,
        address _brokerDealer,
        address _forexIntegration,
        address _monitoringHub,
        PSPNEOConfig memory _pspConfig,
        BDIntegrationConfig memory _bdConfig,
        TokenIssuanceConfig memory _tokenConfig,
        MonitoringConfig memory _monitoringConfig
    ) {
        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PSP_ORCHESTRATOR, msg.sender);
        _setupRole(BD_INTEGRATOR, msg.sender);
        _setupRole(TOKEN_ISSUER, msg.sender);
        _setupRole(MONITORING_OPERATOR, msg.sender);
        _setupRole(AUDIT_MANAGER, msg.sender);
        
        // Set core integrations
        billBittsPSP = IBillBittsPSP(_billBittsPSP);
        dtccSTO = IDTCCCompliantSTO(_dtccSTO);
        brokerDealer = IBrokerDealer(_brokerDealer);
        forexIntegration = IForexPSPIntegration(_forexIntegration);
        monitoringHub = IMonitoringHub(_monitoringHub);
        
        // Set configurations
        pspConfig = _pspConfig;
        bdConfig = _bdConfig;
        tokenConfig = _tokenConfig;
        monitoringConfig = _monitoringConfig;
    }
    
    // ========================================
    // PSP Flow Orchestration
    // ========================================
    
    /**
     * @dev Initiate comprehensive PSP flow
     * @param _flowType Type of PSP flow
     * @param _customer Customer address
     * @param _amount Flow amount
     * @param _currency Currency
     * @param _flowDetails Additional flow details
     */
    function initiatePSPFlow(
        PSPFlowType _flowType,
        address _customer,
        uint256 _amount,
        string memory _currency,
        string memory _flowDetails
    ) external onlyPSPOrchestrator nonReentrant whenNotPaused returns (bytes32 flowId) {
        require(_amount >= pspConfig.minTransactionAmount, "Amount below minimum");
        require(_amount <= pspConfig.maxTransactionAmount, "Amount above maximum");
        
        // Validate daily limits
        require(_checkDailyLimits(_customer, _amount), "Daily limit exceeded");
        
        flowId = keccak256(abi.encodePacked(_flowType, _customer, _amount, block.timestamp));
        
        PSPFlow memory newFlow = PSPFlow({
            flowId: flowId,
            flowType: _flowType,
            customer: _customer,
            amount: _amount,
            currency: _currency,
            status: PSPFlowStatus.INITIATED,
            initiationTime: block.timestamp,
            completionTime: 0,
            bdReference: bytes32(0),
            tokenReference: bytes32(0),
            flowDetails: _flowDetails,
            auditData: AuditData({
                auditId: bytes32(0),
                performedBy: address(0),
                auditTimestamp: 0,
                auditAction: "",
                previousState: bytes32(0),
                newState: bytes32(0),
                auditNotes: ""
            })
        });
        
        pspFlows[flowId] = newFlow;
        customerFlows[_customer].push(flowId);
        
        // Initial monitoring check
        _performInitialMonitoring(_customer, _amount, _flowType);
        
        emit PSPFlowInitiated(
            flowId,
            _flowType,
            _customer,
            _amount,
            _currency,
            block.timestamp
        );
        
        return flowId;
    }
    
    /**
     * @dev Execute complete PSP flow with BD and token integration
     * @param _flowId PSP flow ID
     */
    function executePSPFlow(
        bytes32 _flowId
    ) external onlyPSPOrchestrator nonReentrant whenNotPaused {
        PSPFlow storage flow = pspFlows[_flowId];
        require(flow.flowId != bytes32(0), "Flow not found");
        require(flow.status == PSPFlowStatus.INITIATED, "Flow already processed");
        
        // Validate flow
        bool validationPassed = _validatePSPFlow(flow);
        require(validationPassed, "Flow validation failed");
        
        flow.status = PSPFlowStatus.VALIDATED;
        
        // Execute based on flow type
        if (flow.flowType == PSPFlowType.TOKEN_PURCHASE) {
            _orchestrateTokenPurchaseFlow(flow);
        } else if (flow.flowType == PSPFlowType.DEPOSIT) {
            _orchestrateDepositFlow(flow);
        } else if (flow.flowType == PSPFlowType.FOREX_CONVERSION) {
            _orchestrateForexFlow(flow);
        }
        
        // Record audit trail
        _recordAuditTrail(_flowId, "PSP_FLOW_EXECUTED", "PSP flow execution completed");
    }
    
    /**
     * @dev Orchestrate token purchase flow with BD integration
     * @param _flow PSP flow
     */
    function _orchestrateTokenPurchaseFlow(PSPFlow storage _flow) internal {
        // Step 1: Initiate BD integration
        bytes32 bdIntegrationId = _initiateBDIntegration(
            _flow.customer,
            _flow.amount,
            _flow.currency
        );
        
        _flow.bdReference = bdIntegrationId;
        _flow.status = PSPFlowStatus.PROCESSING;
        
        // Step 2: Process through Bill Bitts PSP
        bool pspSuccess = billBittsPSP.processSettlement(
            _flow.customer,
            pspConfig.pspTreasuryWallet,
            _flow.amount,
            _flow.currency
        );
        
        require(pspSuccess, "PSP settlement failed");
        
        // Step 3: Execute token issuance
        bytes32 tokenIssuanceId = _executeTokenIssuance(
            _flow.customer,
            _flow.amount,
            "REG_D_506C" // Example offering type
        );
        
        _flow.tokenReference = tokenIssuanceId;
        _flow.status = PSPFlowStatus.COMPLETED;
        _flow.completionTime = block.timestamp;
        
        emit PSPOrchestrationCompleted(
            _flow.flowId,
            bdIntegrationId,
            tokenIssuanceId,
            _flow.customer,
            _flow.amount,
            block.timestamp
        );
    }
    
    // ========================================
    // Broker-Dealer Integration
    // ========================================
    
    /**
     * @dev Initiate broker-dealer integration
     * @param _investor Investor address
     * @param _investmentAmount Investment amount
     * @param _currency Currency
     */
    function _initiateBDIntegration(
        address _investor,
        uint256 _investmentAmount,
        string memory _currency
    ) internal returns (bytes32 integrationId) {
        integrationId = keccak256(abi.encodePacked(_investor, _investmentAmount, block.timestamp));
        
        BDIntegration memory newIntegration = BDIntegration({
            integrationId: integrationId,
            brokerDealer: address(brokerDealer),
            investor: _investor,
            investmentAmount: _investmentAmount,
            investmentType: "SECURITY_TOKEN",
            status: BDIntegrationStatus.PENDING_APPROVAL,
            integrationTime: block.timestamp,
            pspFlowReference: bytes32(0),
            tokenIssuanceReference: bytes32(0)
        });
        
        bdIntegrations[integrationId] = newIntegration;
        
        // Submit to broker dealer
        bool bdSubmitted = brokerDealer.submitInvestment(
            _investor,
            _investmentAmount,
            _currency,
            "DPO_TOKEN_OFFERING"
        );
        
        require(bdSubmitted, "BD submission failed");
        
        newIntegration.status = BDIntegrationStatus.APPROVED;
        
        emit BDIntegrationInitiated(
            integrationId,
            address(brokerDealer),
            _investor,
            _investmentAmount,
            "SECURITY_TOKEN",
            block.timestamp
        );
        
        return integrationId;
    }
    
    /**
     * @dev Complete BD integration and release funds
     * @param _integrationId BD integration ID
     */
    function completeBDIntegration(
        bytes32 _integrationId
    ) external onlyBDIntegrator nonReentrant {
        BDIntegration storage integration = bdIntegrations[_integrationId];
        require(integration.integrationId != bytes32(0), "Integration not found");
        require(integration.status == BDIntegrationStatus.APPROVED, "Integration not approved");
        
        // Verify funds received
        bool fundsReceived = brokerDealer.verifyFundsReceipt(
            integration.investor,
            integration.investmentAmount
        );
        
        require(fundsReceived, "Funds not received");
        
        integration.status = BDIntegrationStatus.FUNDS_RECEIVED;
        
        // If auto-token issuance enabled, proceed
        if (bdConfig.autoTokenIssuanceEnabled) {
            _triggerTokenIssuance(_integrationId);
        }
    }
    
    // ========================================
    // Token Issuance Flows
    // ========================================
    
    /**
     * @dev Execute token issuance flow
     * @param _investor Investor address
     * @param _investmentAmount Investment amount
     * @param _offeringType Type of securities offering
     */
    function _executeTokenIssuance(
        address _investor,
        uint256 _investmentAmount,
        string memory _offeringType
    ) internal returns (bytes32 issuanceId) {
        issuanceId = keccak256(abi.encodePacked(_investor, _investmentAmount, block.timestamp));
        
        // Calculate token allocation
        uint256 tokenAmount = _calculateTokenAllocation(_investmentAmount, _offeringType);
        
        TokenIssuanceFlow memory newIssuance = TokenIssuanceFlow({
            issuanceId: issuanceId,
            investor: _investor,
            tokenAmount: tokenAmount,
            investmentAmount: _investmentAmount,
            offeringType: _offeringType,
            status: TokenIssuanceStatus.PENDING_FUNDS,
            issuanceTime: block.timestamp,
            pspFlowReference: bytes32(0),
            bdReference: bytes32(0),
            complianceData: ""
        });
        
        tokenIssuances[issuanceId] = newIssuance;
        
        // Perform compliance check
        if (tokenConfig.autoComplianceCheck) {
            bool compliancePassed = _performComplianceCheck(_investor, _investmentAmount, _offeringType);
            require(compliancePassed, "Compliance check failed");
            
            newIssuance.status = TokenIssuanceStatus.COMPLIANCE_CHECK;
            newIssuance.complianceData = "AUTO_APPROVED";
        }
        
        // Issue tokens via DTCC STO contract
        bytes32 tokenIssuanceId = dtccSTO.issueTokens(
            _investor,
            tokenAmount,
            "IPFS_CID_PLACEHOLDER", // IPFS CID for offering documents
            0, // No lockup period
            bytes20(0) // No Clearstream account
        );
        
        newIssuance.status = TokenIssuanceStatus.TOKENS_MINTED;
        
        emit TokenIssuanceExecuted(
            issuanceId,
            _investor,
            tokenAmount,
            _investmentAmount,
            _offeringType,
            block.timestamp
        );
        
        return issuanceId;
    }
    
    /**
     * @dev Trigger token issuance from BD integration
     * @param _bdIntegrationId BD integration ID
     */
    function _triggerTokenIssuance(bytes32 _bdIntegrationId) internal {
        BDIntegration storage integration = bdIntegrations[_bdIntegrationId];
        
        bytes32 tokenIssuanceId = _executeTokenIssuance(
            integration.investor,
            integration.investmentAmount,
            integration.investmentType
        );
        
        integration.tokenIssuanceReference = tokenIssuanceId;
        integration.status = BDIntegrationStatus.TOKENS_ISSUED;
        
        // Complete the integration
        integration.status = BDIntegrationStatus.COMPLETED;
    }
    
    // ========================================
    // Customer Account Management
    // ========================================
    
    /**
     * @dev Create NEO bank customer account
     * @param _customer Customer address
     * @param _accountType Type of account
     * @param _initialDeposit Initial deposit amount
     * @param _currency Account currency
     */
    function createCustomerAccount(
        address _customer,
        string memory _accountType,
        uint256 _initialDeposit,
        string memory _currency
    ) external onlyPSPOrchestrator returns (bytes32 accountId) {
        accountId = _getAccountId(_customer);
        
        require(customerAccounts[accountId].accountId == bytes32(0), "Account already exists");
        
        CustomerAccount memory newAccount = CustomerAccount({
            accountId: accountId,
            customer: _customer,
            accountType: _accountType,
            totalDeposits: _initialDeposit,
            totalWithdrawals: 0,
            accountBalance: _initialDeposit,
            currency: _currency,
            accountOpened: block.timestamp,
            kycVerified: true, // Assuming KYC done beforehand
            amlCleared: true,  // Assuming AML cleared
            riskRating: "MEDIUM"
        });
        
        customerAccounts[accountId] = newAccount;
        
        emit CustomerAccountCreated(
            accountId,
            _customer,
            _accountType,
            _initialDeposit,
            _currency,
            block.timestamp
        );
        
        return accountId;
    }
    
    /**
     * @dev Update customer account balance
     * @param _customer Customer address
     * @param _amount Amount to update
     * @param _isDeposit Whether it's a deposit (true) or withdrawal (false)
     */
    function updateAccountBalance(
        address _customer,
        uint256 _amount,
        bool _isDeposit
    ) external onlyPSPOrchestrator validCustomer(_customer) {
        bytes32 accountId = _getAccountId(_customer);
        CustomerAccount storage account = customerAccounts[accountId];
        
        if (_isDeposit) {
            account.totalDeposits += _amount;
            account.accountBalance += _amount;
        } else {
            require(account.accountBalance >= _amount, "Insufficient balance");
            account.totalWithdrawals += _amount;
            account.accountBalance -= _amount;
        }
    }
    
    // ========================================
    // Monitoring & Audit Hooks
    // ========================================
    
    /**
     * @dev Perform initial monitoring check
     * @param _customer Customer address
     * @param _amount Transaction amount
     * @param _flowType Flow type
     */
    function _performInitialMonitoring(
        address _customer,
        uint256 _amount,
        PSPFlowType _flowType
    ) internal {
        // Check for large transactions
        if (_amount >= monitoringConfig.alertThresholdAmount) {
            _generateMonitoringAlert(
                _customer,
                _amount,
                MonitoringAlertType.LARGE_TRANSACTION,
                "Large transaction detected"
            );
        }
        
        // Check for suspicious patterns
        if (_detectSuspiciousPattern(_customer, _amount, _flowType)) {
            _generateMonitoringAlert(
                _customer,
                _amount,
                MonitoringAlertType.SUSPICIOUS_PATTERN,
                "Suspicious transaction pattern detected"
            );
        }
        
        // Real-time monitoring if enabled
        if (monitoringConfig.realTimeMonitoringEnabled) {
            monitoringHub.logTransaction(
                _customer,
                _amount,
                uint256(_flowType),
                block.timestamp
            );
        }
    }
    
    /**
     * @dev Generate monitoring alert
     * @param _subject Alert subject
     * @param _amount Alert amount
     * @param _alertType Type of alert
     * @param _description Alert description
     */
    function _generateMonitoringAlert(
        address _subject,
        uint256 _amount,
        MonitoringAlertType _alertType,
        string memory _description
    ) internal {
        bytes32 alertId = keccak256(abi.encodePacked(_subject, _amount, block.timestamp));
        
        MonitoringAlert memory newAlert = MonitoringAlert({
            alertId: alertId,
            alertType: _alertType,
            subject: _subject,
            amount: _amount,
            alertDescription: _description,
            alertTimestamp: block.timestamp,
            status: MonitoringAlertStatus.OPEN,
            resolutionNotes: ""
        });
        
        monitoringAlerts[alertId].push(newAlert);
        
        emit MonitoringAlertGenerated(
            alertId,
            _alertType,
            _subject,
            _amount,
            _description,
            block.timestamp
        );
    }
    
    /**
     * @dev Record audit trail
     * @param _flowId Flow ID
     * @param _action Audit action
     * @param _notes Audit notes
     */
    function _recordAuditTrail(
        bytes32 _flowId,
        string memory _action,
        string memory _notes
    ) internal {
        bytes32 auditId = keccak256(abi.encodePacked(_flowId, _action, block.timestamp));
        
        AuditData memory auditData = AuditData({
            auditId: auditId,
            performedBy: msg.sender,
            auditTimestamp: block.timestamp,
            auditAction: _action,
            previousState: bytes32(0), // Would track state changes
            newState: bytes32(0),
            auditNotes: _notes
        });
        
        auditTrails[auditId] = auditData;
        
        // Update flow with audit data
        if (pspFlows[_flowId].flowId != bytes32(0)) {
            pspFlows[_flowId].auditData = auditData;
        }
        
        emit AuditTrailRecorded(
            auditId,
            _flowId,
            msg.sender,
            _action,
            _notes,
            block.timestamp
        );
    }
    
    // ========================================
    // Internal Helper Functions
    // ========================================
    
    function _getAccountId(address _customer) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("ACCOUNT", _customer));
    }
    
    function _validatePSPFlow(PSPFlow memory _flow) internal view returns (bool) {
        // Check customer account exists
        if (customerAccounts[_getAccountId(_flow.customer)].accountId == bytes32(0)) {
            return false;
        }
        
        // Check daily limits
        if (!_checkDailyLimits(_flow.customer, _flow.amount)) {
            return false;
        }
        
        // Additional validation logic based on flow type
        return PSPOrchestrationLib.validateFlow(_flow.flowType, _flow.amount, _flow.currency);
    }
    
    function _checkDailyLimits(address _customer, uint256 _amount) internal view returns (bool) {
        // Calculate today's total flows for customer
        uint256 dailyTotal = 0;
        bytes32[] memory customerFlowIds = customerFlows[_customer];
        
        for (uint i = 0; i < customerFlowIds.length; i++) {
            PSPFlow memory flow = pspFlows[customerFlowIds[i]];
            if (flow.initiationTime >= block.timestamp - 1 days) {
                dailyTotal += flow.amount;
            }
        }
        
        return (dailyTotal + _amount) <= pspConfig.maxDailyFlowAmount;
    }
    
    function _calculateTokenAllocation(
        uint256 _investmentAmount,
        string memory _offeringType
    ) internal view returns (uint256) {
        // Simplified calculation - in production, use proper token economics
        if (keccak256(abi.encodePacked(_offeringType)) == keccak256(abi.encodePacked("REG_D_506C"))) {
            return (_investmentAmount * 1e18) / (40 * 10**18); // $40 per token
        }
        return (_investmentAmount * 1e18) / (50 * 10**18); // Default $50 per token
    }
    
    function _performComplianceCheck(
        address _investor,
        uint256 _amount,
        string memory _offeringType
    ) internal view returns (bool) {
        // Integration with existing compliance system
        return dtccSTO.investors(_investor).isVerified;
    }
    
    function _detectSuspiciousPattern(
        address _customer,
        uint256 _amount,
        PSPFlowType _flowType
    ) internal view returns (bool) {
        // Basic pattern detection - in production, use ML models
        bytes32[] memory customerFlowIds = customerFlows[_customer];
        uint256 recentFlows = 0;
        
        for (uint i = 0; i < customerFlowIds.length; i++) {
            PSPFlow memory flow = pspFlows[customerFlowIds[i]];
            if (flow.initiationTime >= block.timestamp - 1 hours) {
                recentFlows++;
            }
        }
        
        return recentFlows >= monitoringConfig.suspiciousPatternCount;
    }
    
    function _orchestrateDepositFlow(PSPFlow storage _flow) internal {
        // Implement deposit flow orchestration
        _flow.status = PSPFlowStatus.COMPLETED;
        _flow.completionTime = block.timestamp;
    }
    
    function _orchestrateForexFlow(PSPFlow storage _flow) internal {
        // Implement Forex flow orchestration
        _flow.status = PSPFlowStatus.COMPLETED;
        _flow.completionTime = block.timestamp;
    }
    
    // ========================================
    // View & Utility Functions
    // ========================================
    
    function getPSPFlow(bytes32 _flowId) external view returns (PSPFlow memory) {
        return pspFlows[_flowId];
    }
    
    function getCustomerFlows(address _customer) external view returns (bytes32[] memory) {
        return customerFlows[_customer];
    }
    
    function getCustomerAccount(address _customer) external view returns (CustomerAccount memory) {
        return customerAccounts[_getAccountId(_customer)];
    }
    
    function getMonitoringAlerts(bytes32 _alertId) external view returns (MonitoringAlert[] memory) {
        return monitoringAlerts[_alertId];
    }
    
    // ========================================
    // Administration & Configuration
    // ========================================
    
    function updatePSPConfig(PSPNEOConfig memory _newConfig) external onlyPSPOrchestrator {
        pspConfig = _newConfig;
    }
    
    function updateBDConfig(BDIntegrationConfig memory _newConfig) external onlyBDIntegrator {
        bdConfig = _newConfig;
    }
    
    function updateTokenConfig(TokenIssuanceConfig memory _newConfig) external onlyTokenIssuer {
        tokenConfig = _newConfig;
    }
    
    function updateMonitoringConfig(MonitoringConfig memory _newConfig) external onlyMonitoringOperator {
        monitoringConfig = _newConfig;
    }
    
    function pauseOrchestration() external onlyPSPOrchestrator {
        _pause();
    }
    
    function unpauseOrchestration() external onlyPSPOrchestrator {
        _unpause();
    }
    
    function emergencyHaltFlow(bytes32 _flowId) external onlyPSPOrchestrator {
        PSPFlow storage flow = pspFlows[_flowId];
        require(flow.flowId != bytes32(0), "Flow not found");
        flow.status = PSPFlowStatus.SUSPENDED;
        
        _generateMonitoringAlert(
            flow.customer,
            flow.amount,
            MonitoringAlertType.SYSTEM_ANOMALY,
            "Flow emergency halted"
        );
    }
}