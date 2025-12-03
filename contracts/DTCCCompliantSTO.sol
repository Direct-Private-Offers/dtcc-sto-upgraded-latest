// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./interfaces/IDTCCCompliantSTO.sol";
import "./interfaces/ICSADerivatives.sol";
import "./interfaces/ICLEARSTREAMIntegration.sol";
import "./interfaces/IFineractIntegration.sol";
import "./interfaces/IDPOGLOBALIntegration.sol";
import "./interfaces/ILEIRegistry.sol";
import "./interfaces/IUPIProvider.sol";
import "./interfaces/ITradeRepository.sol";
import "./interfaces/ISanctionsScreening.sol";
import "./interfaces/IStateChannels.sol";

import "./lib/ComplianceLib.sol";
import "./lib/CSADerivativesLib.sol";
import "./lib/ClearstreamLib.sol";
import "./lib/FineractLib.sol";
import "./lib/DateTimeLib.sol";
import "./lib/DividendLib.sol";
import "./utils/Errors.sol";

/**
 * @title DTCCCompliantSTO with Apache Fineract Integration
 * @dev Comprehensive security token with CSA derivatives compliance, Clearstream PMI, and Fineract integration
 * Combines ERC1400 security token features with global regulatory compliance
 * @notice This contract handles security token issuance, compliance verification,
 *         CSA derivatives reporting, Clearstream PMI integration, and Fineract banking system sync
 */
contract DTCCCompliantSTO is 
    IERC20,
    IERC20Metadata,
    ChainlinkClient, 
    Ownable,
    AccessControl, 
    Pausable,
    ReentrancyGuard,
    IDTCCCompliantSTO,
    ICSADerivatives,
    ICLEARSTREAMIntegration,
    IFineractIntegration,
    IDPOGLOBALIntegration
{
    using ComplianceLib for *;
    using CSADerivativesLib for *;
    using ClearstreamLib for *;
    using FineractLib for *;
    using DateTimeLib for *;
    using DividendLib for *;
    
    // Roles
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant QIB_VERIFIER = keccak256("QIB_VERIFIER");
    bytes32 public constant DERIVATIVES_REPORTER = keccak256("DERIVATIVES_REPORTER");
    bytes32 public constant CLEARSTREAM_OPERATOR = keccak256("CLEARSTREAM_OPERATOR");
    bytes32 public constant FINERACT_OPERATOR = keccak256("FINERACT_OPERATOR");
    bytes32 public constant DIVIDEND_MANAGER = keccak256("DIVIDEND_MANAGER");
    
    // Chainlink Configuration
    AggregatorV3Interface internal priceFeed;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    // External registries for compliance
    ILEIRegistry public leiRegistry;
    IUPIProvider public upiProvider;
    ITradeRepository public tradeRepository;
    ISanctionsScreening public sanctionsScreening;
    IStateChannels public stateChannels;
    
    // Security Token State
    OfferingType public currentOfferingType;
    uint256 public regCFMaxRaise = 5_000_000 * 10**18;
    uint256 public totalRaised;
    uint256 public nonAccreditedInvestorCount;
    
    // ERC20 State Variables
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Mappings
    mapping(bytes32 => Issuance) public issuances;
    mapping(address => Investor) public investors;
    mapping(bytes32 => address) private pendingVerifications;
    mapping(address => uint256) public transferLocks;
    
    // CSA Derivatives Storage
    mapping(bytes32 => DerivativeData) public derivatives;
    mapping(bytes32 => CSACorrection[]) public derivativeCorrections;
    mapping(bytes32 => CSAErrorReport[]) public derivativeErrors;
    mapping(bytes32 => CSAPosition) public positions;
    mapping(bytes32 => CollateralData) public tradeCollateral;
    mapping(bytes32 => CollateralUpdate[]) public collateralUpdates;
    
    // Clearstream PMI Integration Storage
    mapping(bytes32 => ClearstreamSettlement) public clearstreamSettlements;
    mapping(bytes32 => ClearstreamInstruction[]) public settlementInstructions;
    mapping(bytes32 => ClearstreamEvent[]) public settlementEvents;
    mapping(bytes32 => ClearstreamPosition) public clearstreamPositions;
    mapping(address => bytes20) public participantAccounts;
    mapping(bytes32 => bool) public isinWhitelist;
    
    // Fineract Integration Storage
    mapping(bytes32 => FineractTransaction) public fineractTransactions;
    mapping(address => FineractClientInfo) public fineractClientInfo;
    mapping(bytes32 => FineractLoan[]) public fineractLoans;
    mapping(bytes32 => FineractSavings[]) public fineractSavingsAccounts;
    mapping(address => bool) public syncedWithFineract;
    uint256 public ledgerSyncThreshold = 10000 * 10**18;
    
    // Dividend Distribution Storage
    mapping(uint256 => DividendCycle) public dividendCycles;
    mapping(address => mapping(uint256 => bool)) public dividendClaims;
    mapping(address => uint256) public lastDividendClaim;
    uint256 public currentDividendCycle;
    uint256 public totalDividendsDistributed;
    
    // Multi-signature Security
    mapping(bytes32 => MultiSigApproval) public multiSigApprovals;
    mapping(address => bool) public multiSigSigners;
    uint256 public largeTransferThreshold = 100000 * 10**18;
    uint256 public multiSigRequired = 2;
    
    // DPO Global LLC Integration
    mapping(bytes32 => CrossChainSwap) public crossChainSwaps;
    mapping(string => address) public interlistedExchanges;
    mapping(address => bool) public dpoGlobalWhitelist;
    
    // Corporate Actions
    mapping(bytes32 => CorporateAction) public corporateActions;
    mapping(bytes32 => mapping(address => bool)) public corporateActionParticipants;
    
    // Clearstream Configuration
    ClearstreamConfig public clearstreamConfig;
    bytes12 public isinCode;
    
    // Fineract Configuration
    FineractConfig public fineractConfig;
    
    // Constants (Arbitrum Mainnet)
    address public constant ARB_LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant ARB_ORACLE = 0x2362A262148518Ce69600Cc5a6032aC8391233f5;
    bytes32 public constant COMPLIANCE_JOB = "53f9755920cd451a8fe46f5087468395";
    bytes32 public constant LEDGER_SYNC_JOB = "f1e5d5e5d5e5d5e5d5e5d5e5d5e5d5e5";
    
    // Price feed staleness threshold (1 hour)
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600;
    
    // Add missing storage variables
    mapping(address => bool) public sanctionedAddresses;
    
    // Structures
    struct Issuance {
        bytes32 issuanceId;
        address issuer;
        uint256 amount;
        uint256 timestamp;
        bool completed;
        string isin;
        bytes20 lei;
    }
    
    struct Investor {
        address investor;
        InvestorType investorType;
        uint256 accreditedSince;
        uint256 investmentLimit;
        bool verified;
        bytes20 lei;
        bytes12 upi;
    }
    
    struct ClearstreamSettlement {
        bytes32 settlementId;
        string isin;
        uint256 quantity;
        uint256 amount;
        address buyer;
        address seller;
        ClearstreamSettlementStatus status;
        uint256 settlementDate;
        uint256 valueDate;
        string transactionReference;
    }
    
    struct ClearstreamInstruction {
        bytes32 instructionId;
        ClearstreamInstructionType instructionType;
        string isin;
        uint256 quantity;
        uint256 amount;
        address participant;
        ClearstreamInstructionStatus status;
        uint256 instructionDate;
        uint256 settlementDate;
        string instructionReference; // Changed from 'reference'
    }
    
    struct ClearstreamEvent {
        bytes32 eventId;
        ClearstreamEventType eventType;
        string isin;
        uint256 timestamp;
        string description;
        bytes32 relatedTransaction;
    }
    
    struct ClearstreamPosition {
        bytes32 positionId;
        string isin;
        address participant;
        uint256 quantity;
        uint256 availableQuantity;
        uint256 lockedQuantity;
        uint256 lastUpdate;
    }
    
    struct ClearstreamConfig {
        string apiBaseUrl;
        string csdIdentifier;
        string participantId;
        bytes32 apiKeyHash;
        uint256 settlementCycle;
        bool autoSettlementEnabled;
        string defaultCurrency;
    }
    
    struct DerivativeData {
        bytes32 uti;
        string productType;
        uint256 effectiveDate;
        uint256 expirationDate;
        uint256 executionTimestamp;
        uint256 notionalAmount;
        string notionalCurrency;
        address counterpartyA;
        address counterpartyB;
        string assetClass;
        string underlyingAsset;
        uint256 underlyingQuantity;
        string underlyingCurrency;
    }
    
    struct CSACorrection {
        bytes32 priorUti;
        DerivativeData correctedData;
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
        ValuationData valuation;
        uint256 lastUpdated;
        uint256 collateralValue;
        uint256 exposure;
    }
    
    struct CollateralData {
        bytes32 collateralId;
        string collateralType;
        uint256 amount;
        string currency;
        address provider;
        uint256 valuationDate;
        uint256 haircutPercentage;
    }
    
    struct CollateralUpdate {
        CollateralData collateralData;
        uint256 updateTimestamp;
        address updatedBy;
    }
    
    struct ValuationData {
        uint256 value;
        string valuationMethod;
        uint256 valuationDate;
        string currency;
        uint256 confidenceInterval;
    }
    
    // Enums
    enum InvestorType {
        RETAIL,
        ACCREDITED,
        QIB,
        INSTITUTIONAL,
        INSIDER
    }
    
    enum OfferingType {
        REG_CF,
        REG_A_PLUS,
        REG_D_506C,
        QIB_ONLY
    }
    
    // Fineract Structures
    struct FineractTransaction {
        bytes32 transactionId;
        FineractTransactionType transactionType;
        address client;
        uint256 amount;
        string currencyCode;
        string description;
        uint256 transactionDate;
        bytes32 referenceNumber;
        bool synced;
        bytes32 fineractReference;
        string officeId;
        string paymentTypeId;
    }
    
    struct FineractClientInfo {
        string clientId;
        string accountNo;
        string officeId;
        string staffId;
        string savingsProductId;
        string loanProductId;
        uint256 activationDate;
        bool active;
        string externalId;
        string mobileNo;
        string emailAddress;
    }
    
    struct FineractLoan {
        bytes32 loanId;
        string loanAccountNo;
        uint256 principalAmount;
        uint256 interestRate;
        uint256 termFrequency;
        string termPeriodFrequencyType;
        uint256 numberOfRepayments;
        uint256 repaymentEvery;
        string repaymentFrequencyType;
        string amortizationType;
        string interestType;
        string interestCalculationPeriodType;
        uint256 loanStartDate;
        uint256 loanEndDate;
        bool disbursed;
        bool closed;
    }
    
    struct FineractSavings {
        bytes32 savingsId;
        string savingsAccountNo;
        uint256 accountBalance;
        uint256 availableBalance;
        uint256 nominalAnnualInterestRate;
        string depositType;
        uint256 depositStartDate;
        uint256 depositEndDate;
        bool locked;
    }
    
    struct FineractConfig {
        string apiBaseUrl;
        string tenantIdentifier;
        string username;
        bytes32 apiKeyHash;
        uint256 syncInterval;
        bool autoSyncEnabled;
        string defaultOfficeId;
        string defaultCurrencyCode;
    }
    
    // Dividend Structures
    struct DividendCycle {
        uint256 cycleId;
        uint256 totalAmount;
        uint256 recordDate;
        uint256 paymentDate;
        uint256 perShareAmount;
        bool distributed;
        bytes32 ipfsCID;
    }
    
    // Multi-signature Structures
    struct MultiSigApproval {
        bytes32 approvalId;
        address[] signers;
        uint256 requiredSignatures;
        uint256 currentSignatures;
        bool executed;
        bytes32 transactionHash;
        uint256 expiration;
    }
    
    // DPO Global LLC Structures
    struct CrossChainSwap {
        bytes32 swapId;
        address user;
        address sourceToken;
        address targetToken;
        uint256 sourceAmount;
        uint256 targetAmount;
        uint256 sourceChain;
        uint256 targetChain;
        CrossChainSwapStatus status;
        uint256 initiationTime;
        uint256 completionTime;
    }
    
    struct CorporateAction {
        bytes32 actionId;
        CorporateActionType actionType;
        string isin;
        uint256 recordDate;
        uint256 executionDate;
        string details;
        uint256 entitlementRatio;
        bool executed;
    }
    
    // Enums
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
    
    enum FineractTransactionType {
        DEPOSIT,
        WITHDRAWAL,
        LOAN_DISBURSEMENT,
        LOAN_REPAYMENT,
        DIVIDEND_PAYMENT,
        INTEREST_PAYMENT,
        FEE_COLLECTION,
        TRANSFER
    }
    
    enum CrossChainSwapStatus {
        PENDING,
        EXECUTING,
        COMPLETED,
        FAILED,
        REFUNDED
    }
    
    enum CorporateActionType {
        DIVIDEND,
        STOCK_SPLIT,
        MERGER,
        ACQUISITION,
        RIGHTS_OFFERING,
        SPIN_OFF
    }
    
    // Modifiers
    modifier onlyIssuer() {
        require(hasRole(ISSUER_ROLE, msg.sender), "Caller is not an issuer");
        _;
    }
    
    modifier onlyCompliance() {
        require(hasRole(COMPLIANCE_OFFICER, msg.sender), "Caller is not compliance");
        _;
    }
    
    modifier onlyQIBVerifier() {
        require(hasRole(QIB_VERIFIER, msg.sender), "Caller is not QIB verifier");
        _;
    }
    
    modifier onlyDerivativesReporter() {
        require(hasRole(DERIVATIVES_REPORTER, msg.sender), "Caller is not derivatives reporter");
        _;
    }
    
    modifier onlyClearstreamOperator() {
        require(hasRole(CLEARSTREAM_OPERATOR, msg.sender), "Caller is not Clearstream operator");
        _;
    }
    
    modifier onlyFineractOperator() {
        require(hasRole(FINERACT_OPERATOR, msg.sender), "Caller is not Fineract operator");
        _;
    }
    
    modifier onlyDividendManager() {
        require(hasRole(DIVIDEND_MANAGER, msg.sender), "Caller is not dividend manager");
        _;
    }
    
    modifier requiresMultiSig(uint256 _amount, bytes32 _txHash) {
        if (_amount >= largeTransferThreshold) {
            require(multiSigApprovals[_txHash].executed, "Multi-signature approval required");
        }
        _;
    }
    
    modifier onlyValidLEI(bytes20 lei) {
        require(leiRegistry.isValidLEI(lei), "Invalid LEI");
        _;
    }
    
    modifier onlyValidUPI(bytes12 upi) {
        require(upiProvider.isValidUPI(upi), "Invalid UPI");
        _;
    }
    
    modifier onlyValidISIN(string memory isin) {
        require(isinWhitelist[keccak256(bytes(isin))], "Invalid ISIN");
        _;
    }
    
    modifier onlyValidDerivativeData(DerivativeData calldata derivativeData) {
        if (derivativeData.uti == bytes32(0)) revert Errors.InvalidUTI();
        if (!CSADerivativesLib.isValidCSADate(derivativeData.effectiveDate)) revert Errors.InvalidDate();
        if (!CSADerivativesLib.isValidCSADate(derivativeData.expirationDate)) revert Errors.InvalidDate();
        if (derivativeData.expirationDate < derivativeData.effectiveDate) revert Errors.InvalidDate();
        if (!CSADerivativesLib.isValidExecutionTimestamp(derivativeData.executionTimestamp)) revert Errors.InvalidDate();
        if (!CSADerivativesLib.isValidCSANotionalAmount(derivativeData.notionalAmount)) revert Errors.InvalidNotionalAmount();
        if (!CSADerivativesLib.isValidCSACurrency(derivativeData.notionalCurrency)) revert Errors.InvalidCurrency();
        _;
    }
    
    modifier notSanctioned(address _addr) {
        require(!sanctionedAddresses[_addr], "Address is sanctioned");
        _;
    }
    
    modifier onlySyncedWithFineract(address _addr) {
        require(syncedWithFineract[_addr], "Address not synced with Fineract");
        _;
    }
    
    /**
     * @dev Constructor with comprehensive compliance integration
     */
    constructor(
        string memory _name_,
        string memory _symbol_,
        uint256 _initialSupply,
        uint256 _defaultLockup,
        OfferingType _offeringType,
        address _leiRegistry,
        address _upiProvider,
        address _tradeRepository,
        address _sanctionsScreening,
        address _stateChannels,
        string memory _isin,
        ClearstreamConfig memory _clearstreamConfig,
        FineractConfig memory _fineractConfig
    ) 
        Ownable(msg.sender)
    {
        // Initialize ERC20 variables
        _name = _name_;
        _symbol = _symbol_;
        
        // Initialize roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ISSUER_ROLE, msg.sender);
        _setupRole(COMPLIANCE_OFFICER, msg.sender);
        _setupRole(QIB_VERIFIER, msg.sender);
        _setupRole(DERIVATIVES_REPORTER, msg.sender);
        _setupRole(CLEARSTREAM_OPERATOR, msg.sender);
        _setupRole(FINERACT_OPERATOR, msg.sender);
        _setupRole(DIVIDEND_MANAGER, msg.sender);
        
        // Set Chainlink parameters for Arbitrum
        setChainlinkToken(ARB_LINK);
        setChainlinkOracle(ARB_ORACLE);
        jobId = COMPLIANCE_JOB;
        fee = 0.1 * 10**18; // 0.1 LINK
        
        // Initialize external services
        leiRegistry = ILEIRegistry(_leiRegistry);
        upiProvider = IUPIProvider(_upiProvider);
        tradeRepository = ITradeRepository(_tradeRepository);
        sanctionsScreening = ISanctionsScreening(_sanctionsScreening);
        stateChannels = IStateChannels(_stateChannels);
        
        // Initialize security token parameters
        currentOfferingType = _offeringType;
        isinCode = keccak256(bytes(_isin));
        isinWhitelist[isinCode] = true;
        clearstreamConfig = _clearstreamConfig;
        
        // Initialize Fineract configuration
        fineractConfig = _fineractConfig;
        
        // Initialize dividend cycle
        currentDividendCycle = 1;
        
        // Initialize multi-signature signers
        multiSigSigners[msg.sender] = true;
        
        // Mint initial supply to deployer
        _mint(msg.sender, _initialSupply);
    }
    
    // ========================================
    // ERC20 Implementation Functions
    // ========================================
    
    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    
    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    
    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Returns the total supply of the token.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @dev Returns the balance of the specified account.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Returns the amount of tokens that spender is allowed to spend on behalf of owner.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev Approves the spender to spend the specified amount of tokens.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev Transfers tokens from sender to recipient with compliance checks.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _beforeTokenTransfer(msg.sender, to, amount);
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev Transfers tokens from one account to another with compliance checks.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _beforeTokenTransfer(from, to, amount);
        
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert Errors.InsufficientAllowance();
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev Increases the allowance granted to spender.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    
    /**
     * @dev Decreases the allowance granted to spender.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert Errors.InsufficientAllowance();
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
    
    /**
     * @dev Internal transfer function.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert Errors.ZeroAddress();
        if (to == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();
        
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert Errors.InsufficientBalance();
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev Internal mint function.
     */
    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();
        
        _totalSupply += amount;
        _balances[account] += amount;
        
        emit Transfer(address(0), account, amount);
    }
    
    /**
     * @dev Internal burn function.
     */
    function _burn(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();
        
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert Errors.InsufficientBalance();
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        
        emit Transfer(account, address(0), amount);
    }
    
    /**
     * @dev Internal approve function.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        if (owner == address(0)) revert Errors.ZeroAddress();
        if (spender == address(0)) revert Errors.ZeroAddress();
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // ========================================
    // Fineract Integration Functions
    // ========================================
    
    /**
     * @dev Sync client with Fineract banking system
     * @param _client Client address
     * @param _clientId Fineract client ID
     * @param _officeId Fineract office ID
     * @param _externalId External identifier
     */
    function syncClientWithFineract(
        address _client,
        string calldata _clientId,
        string calldata _officeId,
        string calldata _externalId,
        string calldata _mobileNo,
        string calldata _emailAddress
    ) external override onlyFineractOperator returns (bool) {
        if (_client == address(0)) revert Errors.ZeroAddress();
        
        fineractClientInfo[_client] = FineractClientInfo({
            clientId: _clientId,
            accountNo: "",  // Will be set when account is created
            officeId: _officeId,
            staffId: "",
            savingsProductId: "",
            loanProductId: "",
            activationDate: block.timestamp,
            active: true,
            externalId: _externalId,
            mobileNo: _mobileNo,
            emailAddress: _emailAddress
        });
        
        syncedWithFineract[_client] = true;
        
        emit ClientSyncedWithFineract(
            _client,
            _clientId,
            _officeId,
            block.timestamp
        );
        
        return true;
    }
    
    /**
     * @dev Create savings account in Fineract for client
     * @param _client Client address
     * @param _savingsProductId Fineract savings product ID
     * @param _nominalAnnualInterestRate Annual interest rate
     */
    function createFineractSavingsAccount(
        address _client,
        string calldata _savingsProductId,
        uint256 _nominalAnnualInterestRate,
        string calldata _depositType
    ) external override onlyFineractOperator onlySyncedWithFineract(_client) returns (bytes32 savingsId) {
        savingsId = keccak256(abi.encodePacked(
            _client,
            _savingsProductId,
            block.timestamp
        ));
        
        FineractSavings memory savings = FineractSavings({
            savingsId: savingsId,
            savingsAccountNo: string(abi.encodePacked("SAV", block.timestamp)),
            accountBalance: 0,
            availableBalance: 0,
            nominalAnnualInterestRate: _nominalAnnualInterestRate,
            depositType: _depositType,
            depositStartDate: block.timestamp,
            depositEndDate: 0,
            locked: false
        });
        
        fineractSavingsAccounts[savingsId].push(savings);
        
        // Update client info with savings product
        FineractClientInfo storage clientInfo = fineractClientInfo[_client];
        clientInfo.savingsProductId = _savingsProductId;
        
        emit FineractSavingsAccountCreated(
            savingsId,
            _client,
            _savingsProductId,
            _nominalAnnualInterestRate,
            block.timestamp
        );
        
        return savingsId;
    }
    
    /**
     * @dev Create loan account in Fineract
     * @param _client Client address
     * @param _loanProductId Fineract loan product ID
     * @param _principalAmount Loan principal
     * @param _interestRate Annual interest rate
     * @param _termFrequency Loan term
     */
    function createFineractLoan(
        address _client,
        string calldata _loanProductId,
        uint256 _principalAmount,
        uint256 _interestRate,
        uint256 _termFrequency,
        string calldata _termPeriodFrequencyType,
        uint256 _numberOfRepayments
    ) external override onlyFineractOperator onlySyncedWithFineract(_client) returns (bytes32 loanId) {
        loanId = keccak256(abi.encodePacked(
            _client,
            _loanProductId,
            block.timestamp
        ));
        
        FineractLoan memory loan = FineractLoan({
            loanId: loanId,
            loanAccountNo: string(abi.encodePacked("LOAN", block.timestamp)),
            principalAmount: _principalAmount,
            interestRate: _interestRate,
            termFrequency: _termFrequency,
            termPeriodFrequencyType: _termPeriodFrequencyType,
            numberOfRepayments: _numberOfRepayments,
            repaymentEvery: 1, // Monthly by default
            repaymentFrequencyType: "MONTHS",
            amortizationType: "EQUAL_PRINCIPAL",
            interestType: "DECLINING_BALANCE",
            interestCalculationPeriodType: "SAME_AS_REPAYMENT_PERIOD",
            loanStartDate: block.timestamp,
            loanEndDate: block.timestamp + (_termFrequency * 30 days), // Approximate
            disbursed: false,
            closed: false
        });
        
        fineractLoans[loanId].push(loan);
        
        // Update client info with loan product
        FineractClientInfo storage clientInfo = fineractClientInfo[_client];
        clientInfo.loanProductId = _loanProductId;
        
        emit FineractLoanCreated(
            loanId,
            _client,
            _loanProductId,
            _principalAmount,
            _interestRate,
            block.timestamp
        );
        
        return loanId;
    }
    
    /**
     * @dev Record transaction in Fineract ledger
     * @param _client Client address
     * @param _amount Transaction amount
     * @param _transactionType Type of transaction
     * @param _description Transaction description
     */
    function recordFineractTransaction(
        address _client,
        uint256 _amount,
        FineractTransactionType _transactionType,
        string calldata _description,
        string calldata _paymentTypeId
    ) external override onlyFineractOperator returns (bytes32 transactionId) {
        if (_client == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();
        
        transactionId = keccak256(abi.encodePacked(
            _client,
            _amount,
            block.timestamp,
            uint256(_transactionType)
        ));
        
        FineractClientInfo storage clientInfo = fineractClientInfo[_client];
        
        FineractTransaction memory transaction = FineractTransaction({
            transactionId: transactionId,
            transactionType: _transactionType,
            client: _client,
            amount: _amount,
            currencyCode: fineractConfig.defaultCurrencyCode,
            description: _description,
            transactionDate: block.timestamp,
            referenceNumber: transactionId,
            synced: false,
            fineractReference: bytes32(0),
            officeId: clientInfo.officeId,
            paymentTypeId: _paymentTypeId
        });
        
        fineractTransactions[transactionId] = transaction;
        
        emit FineractTransactionRecorded(
            transactionId,
            _client,
            _amount,
            _transactionType,
            _description,
            block.timestamp
        );
        
        // Auto-sync if amount is above threshold
        if (_amount >= ledgerSyncThreshold && fineractConfig.autoSyncEnabled) {
            _syncTransactionWithFineract(transactionId);
        }
        
        return transactionId;
    }
    
    /**
     * @dev Sync transaction with Fineract API
     * @param _transactionId Transaction ID to sync
     */
    function syncWithFineract(
        bytes32 _transactionId
    ) external override onlyFineractOperator {
        _syncTransactionWithFineract(_transactionId);
    }
    
    function _syncTransactionWithFineract(bytes32 _transactionId) internal {
        FineractTransaction storage transaction = fineractTransactions[_transactionId];
        require(!transaction.synced, "Transaction already synced");
        
        // In production, this would make an API call to Fineract
        // For now, we simulate the sync
        transaction.synced = true;
        transaction.fineractReference = keccak256(abi.encodePacked(
            "FINERACT",
            block.timestamp,
            _transactionId
        ));
        
        emit FineractTransactionSynced(
            _transactionId,
            transaction.fineractReference,
            block.timestamp
        );
    }
    
    /**
     * @dev Batch sync multiple transactions with Fineract
     * @param _transactionIds Array of transaction IDs to sync
     */
    function batchSyncWithFineract(
        bytes32[] calldata _transactionIds
    ) external override onlyFineractOperator {
        for (uint256 i = 0; i < _transactionIds.length; i++) {
            if (!fineractTransactions[_transactionIds[i]].synced) {
                _syncTransactionWithFineract(_transactionIds[i]);
            }
        }
    }
    
    // ========================================
    // Dividend Distribution Functions
    // ========================================
    
    /**
     * @dev Declare dividend distribution
     */
    function declareDividend(
        uint256 _totalAmount,
        uint256 _recordDate,
        uint256 _paymentDate,
        string calldata _ipfsCID
    ) external override onlyDividendManager returns (uint256 cycleId) {
        if (_totalAmount == 0) revert Errors.ZeroAmount();
        if (_recordDate >= _paymentDate) revert Errors.InvalidDate();
        if (bytes(_ipfsCID).length == 0) revert Errors.InvalidIPFSCID();
        
        cycleId = currentDividendCycle;
        uint256 perShareAmount = _totalAmount / totalSupply();
        
        dividendCycles[cycleId] = DividendCycle({
            cycleId: cycleId,
            totalAmount: _totalAmount,
            recordDate: _recordDate,
            paymentDate: _paymentDate,
            perShareAmount: perShareAmount,
            distributed: false,
            ipfsCID: _ipfsCID
        });
        
        currentDividendCycle++;
        
        emit DividendDeclared(
            cycleId,
            _totalAmount,
            perShareAmount,
            _recordDate,
            _paymentDate,
            _ipfsCID,
            block.timestamp
        );
        
        return cycleId;
    }
    
    /**
     * @dev Claim dividends for a specific cycle
     */
    function claimDividend(uint256 _cycleId) external override nonReentrant {
        if (_cycleId >= currentDividendCycle) revert Errors.InvalidInput();
        if (dividendClaims[msg.sender][_cycleId]) revert Errors.AlreadyVerified();
        
        DividendCycle storage cycle = dividendCycles[_cycleId];
        if (block.timestamp < cycle.paymentDate) revert Errors.InvalidDate();
        if (cycle.distributed) revert Errors.InvalidInput();
        
        uint256 holderBalance = balanceOf(msg.sender);
        if (holderBalance == 0) revert Errors.ZeroAmount();
        
        uint256 dividendAmount = holderBalance * cycle.perShareAmount;
        
        // Mark as claimed
        dividendClaims[msg.sender][_cycleId] = true;
        lastDividendClaim[msg.sender] = block.timestamp;
        
        // Record dividend payment in Fineract
        if (syncedWithFineract[msg.sender]) {
            bytes32 transactionId = recordFineractTransaction(
                msg.sender,
                dividendAmount,
                FineractTransactionType.DIVIDEND_PAYMENT,
                string(abi.encodePacked("Dividend payment for cycle ", _cycleId)),
                "11" // Default payment type for dividends
            );
            
            emit DividendClaimed(
                msg.sender,
                _cycleId,
                dividendAmount,
                transactionId,
                block.timestamp
            );
        } else {
            emit DividendClaimed(
                msg.sender,
                _cycleId,
                dividendAmount,
                bytes32(0),
                block.timestamp
            );
        }
    }
    
    /**
     * @dev Distribute dividends for a cycle
     */
    function distributeDividends(uint256 _cycleId) external override onlyDividendManager {
        if (_cycleId >= currentDividendCycle) revert Errors.InvalidInput();
        
        DividendCycle storage cycle = dividendCycles[_cycleId];
        if (cycle.distributed) revert Errors.InvalidInput();
        if (block.timestamp < cycle.paymentDate) revert Errors.InvalidDate();
        
        cycle.distributed = true;
        totalDividendsDistributed += cycle.totalAmount;
        
        emit DividendsDistributed(
            _cycleId,
            cycle.totalAmount,
            block.timestamp
        );
    }
    
    // ========================================
    // Enhanced Transfer with Fineract Integration
    // ========================================
    
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual notSanctioned(_from) notSanctioned(_to) {
        // Check if contract is paused
        require(!paused(), "Token transfer while paused");
        
        // Sanctions screening
        require(!sanctionedAddresses[_from], "Originator is sanctioned");
        require(!sanctionedAddresses[_to], "Beneficiary is sanctioned");
        
        // Compliance checks
        if (!_checkCompliance(_from, _to, _amount)) {
            revert Errors.TransferNotCompliant();
        }
        
        // Fineract ledger sync for large transactions
        if (_amount >= ledgerSyncThreshold) {
            _syncTransferWithFineract(_from, _to, _amount);
        }
    }
    
    function _checkCompliance(address _from, address _to, uint256 _amount) internal returns (bool) {
        // Check if addresses are sanctioned
        bool fromSanctioned = sanctionsScreening.screenAddress(_from);
        bool toSanctioned = sanctionsScreening.screenAddress(_to);
        
        if (fromSanctioned || toSanctioned) {
            if (fromSanctioned) sanctionedAddresses[_from] = true;
            if (toSanctioned) sanctionedAddresses[_to] = true;
            return false;
        }
        
        // Check transfer locks
        if (_from != address(0) && transferLocks[_from] > block.timestamp) {
            revert Errors.TransferLocked();
        }
        
        // Additional compliance checks can be added here
        return true;
    }
    
    function _syncTransferWithFineract(address _from, address _to, uint256 _amount) internal {
        // Record withdrawal for sender
        if (syncedWithFineract[_from]) {
            recordFineractTransaction(
                _from,
                _amount,
                FineractTransactionType.WITHDRAWAL,
                string(abi.encodePacked("Token transfer to ", _to)),
                "1" // Default payment type for withdrawals
            );
        }
        
        // Record deposit for receiver
        if (syncedWithFineract[_to]) {
            recordFineractTransaction(
                _to,
                _amount,
                FineractTransactionType.DEPOSIT,
                string(abi.encodePacked("Token transfer from ", _from)),
                "1" // Default payment type for deposits
            );
        }
        
        emit FineractLedgerSync(
            _from,
            _to,
            _amount,
            block.timestamp
        );
    }
    
    // ========================================
    // Multi-signature Security Functions
    // ========================================
    
    /**
     * @dev Initiate multi-signature approval
     */
    function initiateMultiSigApproval(
        bytes32 _transactionHash,
        address[] calldata _signers,
        uint256 _expiration
    ) external override onlyCompliance {
        require(_signers.length >= multiSigRequired, "Insufficient signers");
        
        multiSigApprovals[_transactionHash] = MultiSigApproval({
            approvalId: _transactionHash,
            signers: _signers,
            requiredSignatures: multiSigRequired,
            currentSignatures: 0,
            executed: false,
            transactionHash: _transactionHash,
            expiration: _expiration
        });
        
        emit MultiSigInitiated(_transactionHash, _signers, _expiration, block.timestamp);
    }
    
    /**
     * @dev Sign multi-signature transaction
     */
    function signMultiSig(bytes32 _transactionHash) external override {
        MultiSigApproval storage approval = multiSigApprovals[_transactionHash];
        require(approval.approvalId != bytes32(0), "Approval not found");
        require(block.timestamp < approval.expiration, "Approval expired");
        
        bool isSigner = false;
        for (uint i = 0; i < approval.signers.length; i++) {
            if (approval.signers[i] == msg.sender) {
                isSigner = true;
                break;
            }
        }
        require(isSigner, "Not an approved signer");
        
        approval.currentSignatures++;
        
        if (approval.currentSignatures >= approval.requiredSignatures) {
            approval.executed = true;
            emit MultiSigExecuted(_transactionHash, block.timestamp);
        } else {
            emit MultiSigSigned(_transactionHash, msg.sender, block.timestamp);
        }
    }
    
    // ========================================
    // Issuance Functions
    // ========================================
    
    /**
     * @dev Issue new tokens to an investor
     */
    function issueTokens(
        address _to,
        uint256 _amount,
        string calldata _isin,
        bytes20 _lei
    ) external override onlyIssuer onlyValidLEI(_lei) onlyValidISIN(_isin) returns (bytes32 issuanceId) {
        if (_to == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();
        
        issuanceId = keccak256(abi.encodePacked(
            _to,
            _amount,
            block.timestamp,
            _isin
        ));
        
        issuances[issuanceId] = Issuance({
            issuanceId: issuanceId,
            issuer: msg.sender,
            amount: _amount,
            timestamp: block.timestamp,
            completed: false,
            isin: _isin,
            lei: _lei
        });
        
        // Mint tokens
        _mint(_to, _amount);
        
        // Update issuance status
        issuances[issuanceId].completed = true;
        
        // Update investor record
        if (investors[_to].investor == address(0)) {
            investors[_to] = Investor({
                investor: _to,
                investorType: InvestorType.RETAIL,
                accreditedSince: 0,
                investmentLimit: 0,
                verified: false,
                lei: _lei,
                upi: bytes12(0)
            });
        }
        
        emit TokensIssued(issuanceId, _to, _amount, _isin, _lei, block.timestamp);
        
        return issuanceId;
    }
    
    // ========================================
    // Compliance Functions
    // ========================================
    
    /**
     * @dev Verify investor accreditation
     */
    function verifyAccreditation(
        address _investor,
        bool _accredited,
        bytes12 _upi
    ) external override onlyQIBVerifier onlyValidUPI(_upi) returns (bool) {
        if (_investor == address(0)) revert Errors.ZeroAddress();
        
        Investor storage investor = investors[_investor];
        investor.verified = true;
        investor.investorType = _accredited ? InvestorType.ACCREDITED : InvestorType.RETAIL;
        investor.accreditedSince = _accredited ? block.timestamp : 0;
        investor.upi = _upi;
        
        emit AccreditationVerified(_investor, _accredited, _upi, block.timestamp);
        
        return true;
    }
    
    // ========================================
    // CSA Derivatives Functions
    // ========================================
    
    /**
     * @dev Report derivative trade
     */
    function reportDerivativeTrade(
        DerivativeData calldata _derivativeData
    ) external override onlyDerivativesReporter onlyValidDerivativeData(_derivativeData) returns (bytes32 derivativeId) {
        derivativeId = _derivativeData.uti;
        
        derivatives[derivativeId] = _derivativeData;
        
        emit DerivativeReported(
            derivativeId,
            _derivativeData.productType,
            _derivativeData.notionalAmount,
            _derivativeData.notionalCurrency,
            _derivativeData.effectiveDate,
            _derivativeData.expirationDate,
            block.timestamp
        );
        
        return derivativeId;
    }
    
    // ========================================
    // Clearstream Integration Functions
    // ========================================
    
    /**
     * @dev Initiate settlement through Clearstream
     */
    function initiateClearstreamSettlement(
        string calldata _isin,
        uint256 _quantity,
        uint256 _amount,
        address _buyer,
        address _seller
    ) external override onlyClearstreamOperator onlyValidISIN(_isin) returns (bytes32 settlementId) {
        if (_buyer == address(0) || _seller == address(0)) revert Errors.ZeroAddress();
        if (_quantity == 0 || _amount == 0) revert Errors.ZeroAmount();
        
        settlementId = keccak256(abi.encodePacked(
            _isin,
            _quantity,
            _amount,
            _buyer,
            _seller,
            block.timestamp
        ));
        
        clearstreamSettlements[settlementId] = ClearstreamSettlement({
            settlementId: settlementId,
            isin: _isin,
            quantity: _quantity,
            amount: _amount,
            buyer: _buyer,
            seller: _seller,
            status: ClearstreamSettlementStatus.PENDING,
            settlementDate: block.timestamp,
            valueDate: block.timestamp + 2 days, // T+2 settlement
            transactionReference: string(abi.encodePacked("CS_", settlementId))
        });
        
        emit ClearstreamSettlementInitiated(
            settlementId,
            _isin,
            _quantity,
            _amount,
            _buyer,
            _seller,
            block.timestamp
        );
        
        return settlementId;
    }
    
    /**
     * @dev Create settlement instruction
     */
    function createSettlementInstruction(
        ClearstreamInstructionType _instructionType,
        string calldata _isin,
        uint256 _quantity,
        uint256 _amount,
        address _participant
    ) external override onlyClearstreamOperator onlyValidISIN(_isin) returns (bytes32 instructionId) {
        instructionId = keccak256(abi.encodePacked(
            _instructionType,
            _isin,
            _quantity,
            _amount,
            _participant,
            block.timestamp
        ));
        
        ClearstreamInstruction memory instruction = ClearstreamInstruction({
            instructionId: instructionId,
            instructionType: _instructionType,
            isin: _isin,
            quantity: _quantity,
            amount: _amount,
            participant: _participant,
            status: ClearstreamInstructionStatus.PENDING,
            instructionDate: block.timestamp,
            settlementDate: block.timestamp + 2 days,
            instructionReference: string(abi.encodePacked("INST_", instructionId))
        });
        
        settlementInstructions[instructionId].push(instruction);
        
        emit SettlementInstructionCreated(
            instructionId,
            _instructionType,
            _isin,
            _quantity,
            _amount,
            _participant,
            block.timestamp
        );
        
        return instructionId;
    }
    
    // ========================================
    // View Functions
    // ========================================
    
    function getFineractClientInfo(address _client) external view returns (FineractClientInfo memory) {
        return fineractClientInfo[_client];
    }
    
    function getFineractTransaction(bytes32 _transactionId) external view returns (FineractTransaction memory) {
        return fineractTransactions[_transactionId];
    }
    
    function getDividendCycle(uint256 _cycleId) external view returns (DividendCycle memory) {
        return dividendCycles[_cycleId];
    }
    
    function getMultiSigApproval(bytes32 _transactionHash) external view returns (MultiSigApproval memory) {
        return multiSigApprovals[_transactionHash];
    }
    
    function getCrossChainSwap(bytes32 _swapId) external view returns (CrossChainSwap memory) {
        return crossChainSwaps[_swapId];
    }
    
    function getCorporateAction(bytes32 _actionId) external view returns (CorporateAction memory) {
        return corporateActions[_actionId];
    }
    
    function getInvestor(address _investor) external view returns (Investor memory) {
        return investors[_investor];
    }
    
    function getIssuance(bytes32 _issuanceId) external view returns (Issuance memory) {
        return issuances[_issuanceId];
    }
    
    function getDerivative(bytes32 _uti) external view returns (DerivativeData memory) {
        return derivatives[_uti];
    }
    
    function getClearstreamSettlement(bytes32 _settlementId) external view returns (ClearstreamSettlement memory) {
        return clearstreamSettlements[_settlementId];
    }
    
    function getSettlementInstruction(bytes32 _instructionId) external view returns (ClearstreamInstruction[] memory) {
        return settlementInstructions[_instructionId];
    }
    
    // ========================================
    // Admin Functions
    // ========================================
    
    function updateFineractConfig(FineractConfig memory _newConfig) external onlyCompliance {
        fineractConfig = _newConfig;
        emit FineractConfigUpdated(block.timestamp);
    }
    
    function updateLedgerSyncThreshold(uint256 _newThreshold) external onlyCompliance {
        ledgerSyncThreshold = _newThreshold;
    }
    
    function updateLargeTransferThreshold(uint256 _newThreshold) external onlyCompliance {
        largeTransferThreshold = _newThreshold;
    }
    
    function addMultiSigSigner(address _signer) external onlyCompliance {
        multiSigSigners[_signer] = true;
    }
    
    function addDPOGlobalWhitelist(address _address) external onlyCompliance {
        dpoGlobalWhitelist[_address] = true;
    }
    
    function addISINToWhitelist(string calldata _isin) external onlyCompliance {
        isinWhitelist[keccak256(bytes(_isin))] = true;
        emit ISINWhitelisted(_isin, block.timestamp);
    }
    
    function setTransferLock(address _account, uint256 _lockDuration) external onlyCompliance {
        transferLocks[_account] = block.timestamp + _lockDuration;
        emit TransferLockSet(_account, _lockDuration, block.timestamp);
    }
    
    // Emergency functions
    function emergencyHalt(string memory _reason) external onlyCompliance {
        _pause();
        emit EmergencyHalt(_reason, block.timestamp);
    }
    
    function emergencyRemoveSanction(address _addr) external onlyCompliance {
        sanctionedAddresses[_addr] = false;
        emit SanctionRemoved(_addr, block.timestamp);
    }
    
    // ========================================
    // Pausable Functions
    // ========================================
    
    function pause() external onlyCompliance {
        _pause();
    }
    
    function unpause() external onlyCompliance {
        _unpause();
    }
    
    // Events
    event ClientSyncedWithFineract(address indexed client, string clientId, string officeId, uint256 timestamp);
    event FineractSavingsAccountCreated(bytes32 indexed savingsId, address indexed client, string savingsProductId, uint256 interestRate, uint256 timestamp);
    event FineractLoanCreated(bytes32 indexed loanId, address indexed client, string loanProductId, uint256 principalAmount, uint256 interestRate, uint256 timestamp);
    event FineractTransactionRecorded(bytes32 indexed transactionId, address indexed client, uint256 amount, FineractTransactionType transactionType, string description, uint256 timestamp);
    event FineractTransactionSynced(bytes32 indexed transactionId, bytes32 fineractReference, uint256 timestamp);
    event FineractLedgerSync(address indexed from, address indexed to, uint256 amount, uint256 timestamp);
    event FineractConfigUpdated(uint256 timestamp);
    event DividendDeclared(uint256 indexed cycleId, uint256 totalAmount, uint256 perShareAmount, uint256 recordDate, uint256 paymentDate, string ipfsCID, uint256 timestamp);
    event DividendClaimed(address indexed claimant, uint256 indexed cycleId, uint256 amount, bytes32 transactionId, uint256 timestamp);
    event DividendsDistributed(uint256 indexed cycleId, uint256 totalAmount, uint256 timestamp);
    event MultiSigInitiated(bytes32 indexed transactionHash, address[] signers, uint256 expiration, uint256 timestamp);
    event MultiSigSigned(bytes32 indexed transactionHash, address signer, uint256 timestamp);
    event MultiSigExecuted(bytes32 indexed transactionHash, uint256 timestamp);
    event EmergencyHalt(string reason, uint256 timestamp);
    event SanctionRemoved(address indexed addr, uint256 timestamp);
    event TokensIssued(bytes32 indexed issuanceId, address indexed to, uint256 amount, string isin, bytes20 lei, uint256 timestamp);
    event AccreditationVerified(address indexed investor, bool accredited, bytes12 upi, uint256 timestamp);
    event DerivativeReported(bytes32 indexed derivativeId, string productType, uint256 notionalAmount, string currency, uint256 effectiveDate, uint256 expirationDate, uint256 timestamp);
    event ClearstreamSettlementInitiated(bytes32 indexed settlementId, string isin, uint256 quantity, uint256 amount, address buyer, address seller, uint256 timestamp);
    event SettlementInstructionCreated(bytes32 indexed instructionId, ClearstreamInstructionType instructionType, string isin, uint256 quantity, uint256 amount, address participant, uint256 timestamp);
    event ISINWhitelisted(string isin, uint256 timestamp);
    event TransferLockSet(address indexed account, uint256 lockDuration, uint256 timestamp);
    
    // ERC20 Events (inherited from IERC20 and IERC20Metadata)
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}