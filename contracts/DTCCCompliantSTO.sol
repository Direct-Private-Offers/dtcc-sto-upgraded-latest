// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC1820Implementer.sol";
import "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Import interfaces
import {ICLEARSTREAMIntegration} from "./interfaces/ICLEARSTREAMIntegration.sol";
import {IDTCCCompliantSTO} from "./interfaces/IDTCCCompliantSTO.sol";
import {ILEIRegistry} from "./interfaces/ILEIRegistry.sol";
import {IUPIProvider} from "./interfaces/IUPIProvider.sol";
import {ITradeRepository} from "./interfaces/ITradeRepository.sol";

import "./lib/ComplianceLib.sol";
import "./lib/CSADerivativesLib.sol";
import "./lib/ClearstreamLib.sol";
import "./lib/DateTimeLib.sol";

/**
 * @title DTCCCompliantSTO
 * @dev Clean implementation with no inheritance conflicts
 */
contract DTCCCompliantSTO is 
    AccessControl,
    Pausable,
    ReentrancyGuard,
    ERC1820Implementer,
    IDTCCCompliantSTO,
    ICLEARSTREAMIntegration
{
    using ComplianceLib for *;
    using CSADerivativesLib for *;
    using ClearstreamLib for *;
    using DateTimeLib for *;
    
    // Roles - DEFAULT_ADMIN_ROLE comes from AccessControl
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant QIB_VERIFIER = keccak256("QIB_VERIFIER");
    bytes32 public constant DERIVATIVES_REPORTER = keccak256("DERIVATIVES_REPORTER");
    bytes32 public constant CLEARSTREAM_OPERATOR = keccak256("CLEARSTREAM_OPERATOR");
    bytes32 public constant COMPLIANCE_REGISTRY = keccak256("COMPLIANCE_REGISTRY");
    
    // ========================================
    // ERC1400 Token Properties
    // ========================================
    string private _name;
    string private _symbol;
    uint256 private _granularity;
    uint256 private _totalSupply;
    uint8 private constant _decimals = 18;
    
    // ERC20 Compatible mappings
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // ERC1400 Partition mappings
    mapping(bytes32 => uint256) private _totalSupplyByPartition;
    mapping(address => mapping(bytes32 => uint256)) private _balanceOfByPartition;
    mapping(address => bytes32[]) private _partitionsOf;
    bytes32[] private _totalPartitions;
    bytes32[] private _defaultPartitions;
    
    // Document management
    struct Doc {
        string docURI;
        bytes32 docHash;
        uint256 timestamp;
    }
    mapping(bytes32 => Doc) private _documents;
    bytes32[] private _documentNames;
    
    // Operator management
    mapping(address => mapping(address => bool)) private _authorizedOperators;
    mapping(address => mapping(bytes32 => mapping(address => bool))) private _authorizedOperatorsByPartition;
    
    // Controller management
    address[] private _controllers;
    mapping(address => bool) private _isController;
    
    // KYC Registry
    struct KYCStatus {
        bool isApproved;
        uint64 expiry;
        uint256 lastUpdated;
    }
    mapping(address => KYCStatus) public kycRegistry;
    
    // Chainlink Price Feed
    AggregatorV3Interface internal priceFeed;
    
    // External registries
    ILEIRegistry public leiRegistry;
    IUPIProvider public upiProvider;
    ITradeRepository public tradeRepository;
    
    // Security Token State
    IDTCCCompliantSTO.OfferingType public currentOfferingType;
    uint256 public regCFMaxRaise = 5_000_000 * 10**18;
    uint256 public totalRaised;
    uint256 public nonAccreditedInvestorCount;
    
    // Mappings
    mapping(bytes32 => IDTCCCompliantSTO.Issuance) public issuances;
    mapping(address => IDTCCCompliantSTO.Investor) public investors;
    mapping(address => uint256) public transferLocks;
    
    // CSA Derivatives Storage
    mapping(bytes32 => IDTCCCompliantSTO.DerivativeData) public derivatives;
    mapping(bytes32 => CSACorrection[]) public derivativeCorrections;
    mapping(bytes32 => CSAErrorReport[]) public derivativeErrors;
    mapping(bytes32 => CSAPosition) public positions;
    mapping(bytes32 => IDTCCCompliantSTO.CollateralData) public tradeCollateral;
    mapping(bytes32 => CollateralUpdate[]) public collateralUpdates;
    
    // Clearstream PMI Integration
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamSettlement) public clearstreamSettlements;
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamInstruction[]) public settlementInstructions;
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamEvent[]) public settlementEvents;
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamPosition) public clearstreamPositions;
    mapping(address => bytes20) public participantAccounts;
    mapping(bytes32 => bool) public isinWhitelist;
    
    // Clearstream Configuration
    ICLEARSTREAMIntegration.ClearstreamConfig public clearstreamConfig;
    bytes12 public isinCode;
    
    // Constants
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600;
    
    // ERC1820 Interface constants
    string constant internal ERC1400_INTERFACE_NAME = "ERC1400Token";
    string constant internal ERC20_INTERFACE_NAME = "ERC20Token";
    IERC1820Registry private constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    
    // Local structures
    struct CSACorrection {
        bytes32 priorUti;
        IDTCCCompliantSTO.DerivativeData correctedData;
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
        IDTCCCompliantSTO.ValuationData valuation;
        uint256 lastUpdated;
    }
    
    struct CollateralUpdate {
        IDTCCCompliantSTO.CollateralData collateralData;
        uint256 updateTimestamp;
        address updatedBy;
    }
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TransferByPartition(bytes32 indexed fromPartition, address operator, address indexed from, address indexed to, uint256 value, bytes data, bytes operatorData);
    event ChangedPartition(bytes32 indexed fromPartition, bytes32 indexed toPartition, uint256 value);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
    event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
    event IssuedByPartition(bytes32 indexed partition, address indexed operator, address indexed to, uint256 value, bytes data, bytes operatorData);
    event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);
    event RedeemedByPartition(bytes32 indexed partition, address indexed operator, address indexed from, uint256 value, bytes operatorData);
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 documentHash);
    event DocumentRemoved(bytes32 indexed name, string uri, bytes32 documentHash);
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);
    
    // Modifiers
    modifier onlyController() {
        require(_isController[msg.sender] || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a controller");
        _;
    }
    
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
    
    modifier onlyValidDerivativeData(IDTCCCompliantSTO.DerivativeData calldata derivativeData) {
        if (derivativeData.uti == bytes32(0)) revert ICLEARSTREAMIntegration.InvalidUTI();
        
        if (!CSADerivativesLib.isValidCSADate(derivativeData.effectiveDate, block.timestamp)) 
            revert ICLEARSTREAMIntegration.InvalidDate();
        if (!CSADerivativesLib.isValidCSADate(derivativeData.expirationDate, block.timestamp)) 
            revert ICLEARSTREAMIntegration.InvalidDate();
        if (derivativeData.expirationDate < derivativeData.effectiveDate) 
            revert ICLEARSTREAMIntegration.InvalidDate();
        
        if (!CSADerivativesLib.isValidExecutionTimestamp(derivativeData.executionTimestamp, block.timestamp)) 
            revert ICLEARSTREAMIntegration.InvalidDate();
        
        if (!CSADerivativesLib.isValidCSANotionalAmount(derivativeData.notionalAmount)) 
            revert ICLEARSTREAMIntegration.InvalidNotionalAmount();
        if (!CSADerivativesLib.isValidCSACurrency(derivativeData.notionalCurrency)) 
            revert ICLEARSTREAMIntegration.InvalidCurrency();
        _;
    }
    
    /**
     * @dev Constructor
     */
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 tokenGranularity,
        address[] memory initialControllers,
        bytes32[] memory defaultPartitions,
        uint256 initialSupply,
        uint256 defaultLockup,
        IDTCCCompliantSTO.OfferingType offeringType,
        address leiRegistry_,
        address upiProvider_,
        address tradeRepository_,
        string memory isin,
        ICLEARSTREAMIntegration.ClearstreamConfig memory clearstreamConfig_,
        address priceFeed_
    ) {
        require(tokenGranularity >= 1, "Granularity must be >= 1");
        require(leiRegistry_ != address(0), "Invalid LEI registry");
        require(upiProvider_ != address(0), "Invalid UPI provider");
        require(tradeRepository_ != address(0), "Invalid trade repository");
        require(bytes(isin).length > 0, "Invalid ISIN");
        require(clearstreamConfig_.defaultCsdAccount != bytes20(0), "Invalid CSD account");
        require(priceFeed_ != address(0), "Invalid price feed");
        
        _name = tokenName;
        _symbol = tokenSymbol;
        _granularity = tokenGranularity;
        
        // Setup controllers
        for (uint i = 0; i < initialControllers.length; i++) {
            _isController[initialControllers[i]] = true;
            _controllers.push(initialControllers[i]);
            emit ControllerAdded(initialControllers[i]);
        }
        
        _defaultPartitions = defaultPartitions;
        
        // Mint initial supply
        _mint(msg.sender, initialSupply);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
        _grantRole(QIB_VERIFIER, msg.sender);
        _grantRole(DERIVATIVES_REPORTER, msg.sender);
        _grantRole(CLEARSTREAM_OPERATOR, msg.sender);
        _grantRole(COMPLIANCE_REGISTRY, msg.sender);
        
        // Set external registries
        leiRegistry = ILEIRegistry(leiRegistry_);
        upiProvider = IUPIProvider(upiProvider_);
        tradeRepository = ITradeRepository(tradeRepository_);
        
        // Set offering type
        currentOfferingType = offeringType;
        if (offeringType == ICSADerivatives.OfferingType.REG_CF) {
            regCFMaxRaise = 5_000_000 * 10**18;
        }
        
        // Clearstream Configuration
        clearstreamConfig = clearstreamConfig_;
        isinCode = ClearstreamLib.stringToBytes12(isin);
        isinWhitelist[keccak256(bytes(isin))] = true;
        
        // Chainlink Price Feed
        priceFeed = AggregatorV3Interface(priceFeed_);
        
        // Set default lockup
        transferLocks[msg.sender] = block.timestamp + defaultLockup;
        
        // Register in ERC1820 using the registry directly
        _ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            keccak256(abi.encodePacked(ERC1400_INTERFACE_NAME)),
            address(this)
        );
        _ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            keccak256(abi.encodePacked(ERC20_INTERFACE_NAME)),
            address(this)
        );
        
        emit ICLEARSTREAMIntegration.ClearstreamConfigured(clearstreamConfig_.defaultCsdAccount, isin, block.timestamp);
        emit ICSADerivatives.OfferingTypeSet(offeringType, block.timestamp);
    }
    
    // ========================================
    // ERC20 Required Functions
    // ========================================
    
    function name() public view returns (string memory) {
        return _name;
    }
    
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    function decimals() public pure returns (uint8) {
        return _decimals;
    }
    
    function granularity() public view returns (uint256) {
        return _granularity;
    }
    
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(msg.sender, msg.sender, to, amount, "");
        return true;
    }
    
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public whenNotPaused returns (bool) {
        require(spender != address(0), "Invalid spender");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public whenNotPaused returns (bool) {
        require(_isOperator(msg.sender, from) || amount <= _allowances[from][msg.sender], "Insufficient allowance");
        
        if (_allowances[from][msg.sender] >= amount) {
            _allowances[from][msg.sender] -= amount;
        } else {
            _allowances[from][msg.sender] = 0;
        }
        
        _transfer(msg.sender, from, to, amount, "");
        return true;
    }
    
    // ========================================
    // ERC1400 Document Management
    // ========================================
    
    function getDocument(bytes32 documentName) external view returns (string memory, bytes32, uint256) {
        require(bytes(_documents[documentName].docURI).length > 0, "Document does not exist");
        Doc memory doc = _documents[documentName];
        return (doc.docURI, doc.docHash, doc.timestamp);
    }
    
    function setDocument(bytes32 documentName, string calldata uri, bytes32 documentHash) external onlyController {
        _documents[documentName] = Doc({
            docURI: uri,
            docHash: documentHash,
            timestamp: block.timestamp
        });
        
        bool found = false;
        for (uint i = 0; i < _documentNames.length; i++) {
            if (_documentNames[i] == documentName) {
                found = true;
                break;
            }
        }
        if (!found) {
            _documentNames.push(documentName);
        }
        
        emit DocumentUpdated(documentName, uri, documentHash);
    }
    
    function removeDocument(bytes32 documentName) external onlyController {
        require(bytes(_documents[documentName].docURI).length > 0, "Document does not exist");
        delete _documents[documentName];
        
        for (uint i = 0; i < _documentNames.length; i++) {
            if (_documentNames[i] == documentName) {
                _documentNames[i] = _documentNames[_documentNames.length - 1];
                _documentNames.pop();
                break;
            }
        }
        
        emit DocumentRemoved(documentName, "", bytes32(0));
    }
    
    function getAllDocuments() external view returns (bytes32[] memory) {
        return _documentNames;
    }
    
    // ========================================
    // ERC1400 Partition Functions
    // ========================================
    
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256) {
        return _balanceOfByPartition[tokenHolder][partition];
    }
    
    function partitionsOf(address tokenHolder) external view returns (bytes32[] memory) {
        return _partitionsOf[tokenHolder];
    }
    
    function totalSupplyByPartition(bytes32 partition) external view returns (uint256) {
        return _totalSupplyByPartition[partition];
    }
    
    function totalPartitions() external view returns (bytes32[] memory) {
        return _totalPartitions;
    }
    
    function transferByPartition(
        bytes32 partition,
        address to,
        uint256 value,
        bytes calldata data
    ) external whenNotPaused returns (bytes32) {
        return _transferByPartition(partition, msg.sender, msg.sender, to, value, data, "");
    }
    
    function operatorTransferByPartition(
        bytes32 partition,
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata operatorData
    ) external whenNotPaused returns (bytes32) {
        require(_isOperatorForPartition(partition, msg.sender, from) || 
                value <= _allowances[from][msg.sender], "Not authorized");
        
        if (_allowances[from][msg.sender] >= value) {
            _allowances[from][msg.sender] -= value;
        } else {
            _allowances[from][msg.sender] = 0;
        }
        
        return _transferByPartition(partition, msg.sender, from, to, value, data, operatorData);
    }
    
    function getDefaultPartitions() public view returns (bytes32[] memory) {
        return _defaultPartitions;
    }
    
    function setDefaultPartitions(bytes32[] calldata partitions) external onlyController {
        _defaultPartitions = partitions;
    }
    
    // ========================================
    // Operator Management
    // ========================================
    
    function authorizeOperator(address operator) external {
        require(operator != msg.sender, "Cannot authorize self");
        _authorizedOperators[operator][msg.sender] = true;
        emit AuthorizedOperator(operator, msg.sender);
    }
    
    function revokeOperator(address operator) external {
        require(operator != msg.sender, "Cannot revoke self");
        _authorizedOperators[operator][msg.sender] = false;
        emit RevokedOperator(operator, msg.sender);
    }
    
    function authorizeOperatorByPartition(bytes32 partition, address operator) external {
        _authorizedOperatorsByPartition[msg.sender][partition][operator] = true;
        emit AuthorizedOperatorByPartition(partition, operator, msg.sender);
    }
    
    function revokeOperatorByPartition(bytes32 partition, address operator) external {
        _authorizedOperatorsByPartition[msg.sender][partition][operator] = false;
        emit RevokedOperatorByPartition(partition, operator, msg.sender);
    }
    
    function isOperator(address operator, address tokenHolder) public view returns (bool) {
        return _isOperator(operator, tokenHolder);
    }
    
    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool) {
        return _isOperatorForPartition(partition, operator, tokenHolder);
    }
    
    // ========================================
    // Controller Management
    // ========================================
    
    function controllers() external view returns (address[] memory) {
        return _controllers;
    }
    
    function isController(address account) external view returns (bool) {
        return _isController[account];
    }
    
    function addController(address controller) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_isController[controller], "Already a controller");
        _isController[controller] = true;
        _controllers.push(controller);
        emit ControllerAdded(controller);
    }
    
    function removeController(address controller) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isController[controller], "Not a controller");
        _isController[controller] = false;
        
        for (uint i = 0; i < _controllers.length; i++) {
            if (_controllers[i] == controller) {
                _controllers[i] = _controllers[_controllers.length - 1];
                _controllers.pop();
                break;
            }
        }
        
        emit ControllerRemoved(controller);
    }
    
    // ========================================
    // Token Issuance and Redemption
    // ========================================
    
    function issue(address tokenHolder, uint256 value, bytes calldata data) external onlyRole(ISSUER_ROLE) {
        require(_defaultPartitions.length > 0, "No default partitions");
        _issueByPartition(_defaultPartitions[0], msg.sender, tokenHolder, value, data);
    }
    
    function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) 
        external onlyRole(ISSUER_ROLE) {
        _issueByPartition(partition, msg.sender, tokenHolder, value, data);
    }
    
    function redeem(uint256 value, bytes calldata data) external {
        require(_defaultPartitions.length > 0, "No default partitions");
        _redeemByDefaultPartitions(msg.sender, msg.sender, value, data);
    }
    
    function redeemFrom(address from, uint256 value, bytes calldata data) external {
        require(_isOperator(msg.sender, from) || value <= _allowances[from][msg.sender], "Not authorized");
        
        if (_allowances[from][msg.sender] >= value) {
            _allowances[from][msg.sender] -= value;
        } else {
            _allowances[from][msg.sender] = 0;
        }
        
        _redeemByDefaultPartitions(msg.sender, from, value, data);
    }
    
    function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external {
        _redeemByPartition(partition, msg.sender, msg.sender, value, data, "");
    }
    
    // ========================================
    // KYC Registry Functions
    // ========================================
    
    function setKYC(address user, bool approved, uint64 expiry) external onlyRole(COMPLIANCE_REGISTRY) {
        require(user != address(0), "Invalid user");
        
        kycRegistry[user] = KYCStatus({
            isApproved: approved,
            expiry: expiry,
            lastUpdated: block.timestamp
        });
        
        investors[user].isVerified = approved;
        investors[user].verificationDate = block.timestamp;
        investors[user].lastKycRefresh = block.timestamp;
        
        emit ICSADerivatives.InvestorVerified(user, investors[user].isAccredited, block.timestamp);
    }
    
    function batchSetKYC(
        address[] calldata users,
        bool[] calldata approved,
        uint64[] calldata expiries
    ) external onlyRole(COMPLIANCE_REGISTRY) {
        require(users.length == approved.length && users.length == expiries.length, "Array length mismatch");
        require(users.length <= 100, "Batch size too large");
        
        for (uint i = 0; i < users.length; i++) {
            kycRegistry[users[i]] = KYCStatus({
                isApproved: approved[i],
                expiry: expiries[i],
                lastUpdated: block.timestamp
            });
            
            investors[users[i]].isVerified = approved[i];
            investors[users[i]].verificationDate = block.timestamp;
            investors[users[i]].lastKycRefresh = block.timestamp;
            
            emit ICSADerivatives.InvestorVerified(users[i], investors[users[i]].isAccredited, block.timestamp);
        }
    }
    
    function isKYCValid(address user) public view returns (bool) {
        KYCStatus memory status = kycRegistry[user];
        if (!status.isApproved) return false;
        if (status.expiry > 0 && block.timestamp > status.expiry) return false;
        return true;
    }
    
    // ========================================
    // Internal Derivative Reporting Function
    // ========================================
    
    function _reportDerivative(
        IDTCCCompliantSTO.DerivativeData calldata derivativeData,
        IDTCCCompliantSTO.CounterpartyData calldata counterparty1,
        IDTCCCompliantSTO.CounterpartyData calldata counterparty2,
        IDTCCCompliantSTO.CollateralData calldata collateralData,
        IDTCCCompliantSTO.ValuationData calldata valuationData
    ) internal returns (bytes32 uti) {
        _validateCounterparties(counterparty1, counterparty2);
        _validateCollateralAndValuation(collateralData, valuationData);
        
        uti = _getOrGenerateUTI(derivativeData);
        
        require(derivatives[uti].uti == bytes32(0), "Derivative already exists");
        
        _storeDerivativeData(uti, derivativeData, collateralData);
        _submitToTradeRepository(uti, derivativeData, counterparty1, counterparty2);
        
        emit ICSADerivatives.DerivativeReported(uti, msg.sender, block.timestamp, 
            ICSADerivatives.ActionType.NEWT, ICSADerivatives.EventType.TRAD);
        
        return uti;
    }
    
    function _validateCounterparties(
        IDTCCCompliantSTO.CounterpartyData calldata counterparty1,
        IDTCCCompliantSTO.CounterpartyData calldata counterparty2
    ) private pure {
        _validateCSACounterparty(counterparty1);
        _validateCSACounterparty(counterparty2);
    }
    
    function _validateCollateralAndValuation(
        IDTCCCompliantSTO.CollateralData calldata collateralData,
        IDTCCCompliantSTO.ValuationData calldata valuationData
    ) private pure {
        require(CSADerivativesLib.validateCollateralData(collateralData), "Invalid collateral");
        require(CSADerivativesLib.validateValuationData(valuationData), "Invalid valuation");
    }
    
    function _getOrGenerateUTI(IDTCCCompliantSTO.DerivativeData calldata derivativeData) private view returns (bytes32) {
        return derivativeData.uti == bytes32(0) ? _generateCSAUTI(derivativeData) : derivativeData.uti;
    }
    
    function _storeDerivativeData(
        bytes32 uti,
        IDTCCCompliantSTO.DerivativeData calldata derivativeData,
        IDTCCCompliantSTO.CollateralData calldata collateralData
    ) private {
        derivatives[uti] = derivativeData;
        tradeCollateral[uti] = collateralData;
    }
    
    function _submitToTradeRepository(
        bytes32 uti,
        IDTCCCompliantSTO.DerivativeData calldata derivativeData,
        IDTCCCompliantSTO.CounterpartyData calldata counterparty1,
        IDTCCCompliantSTO.CounterpartyData calldata counterparty2
    ) private {
        tradeRepository.submitTrade(
            uti,
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
    }
    
    // ========================================
    // IDTCCCompliantSTO Required Functions
    // ========================================
    
    function issueTokens(
        address investor,
        uint256 amount,
        string calldata ipfsCID,
        uint256 lockupPeriod,
        bytes20 csdAccount
    ) external override onlyIssuer whenNotPaused returns (bytes32 issuanceId) {
        require(investor != address(0), "Invalid investor");
        require(amount > 0, "Amount must be > 0");
        require(bytes(ipfsCID).length > 0, "Invalid IPFS CID");
        
        ComplianceLib.validateInvestorForOffering(
            investors,
            nonAccreditedInvestorCount,
            currentOfferingType,
            investor,
            amount
        );
        
        issuanceId = keccak256(abi.encodePacked(investor, block.timestamp, amount, ipfsCID));
        
        uint256 lockupEnd = lockupPeriod > 0 ? block.timestamp + lockupPeriod : 0;
        
        issuances[issuanceId] = ICSADerivatives.Issuance({
            investor: investor,
            amount: amount,
            ipfsCID: ipfsCID,
            timestamp: block.timestamp,
            lockupEnd: lockupEnd,
            verified: false,
            accredited: investors[investor].isAccredited
        });
        
        investors[investor].issuanceIds.push(issuanceId);
        investors[investor].totalInvested += amount;
        
        if (csdAccount != bytes20(0)) {
            participantAccounts[investor] = csdAccount;
            emit ICLEARSTREAMIntegration.ClearstreamAccountLinked(investor, csdAccount, block.timestamp);
        }
        
        if (lockupEnd > 0) {
            transferLocks[investor] = lockupEnd;
            emit ICSADerivatives.TransferLockUpdated(investor, lockupEnd);
        }
        
        require(_defaultPartitions.length > 0, "No default partitions");
        _issueByPartition(_defaultPartitions[0], msg.sender, investor, amount, bytes(ipfsCID));
        
        if (currentOfferingType == ICSADerivatives.OfferingType.REG_CF) {
            totalRaised += amount;
            emit ICSADerivatives.RegCFInvestment(investor, amount, totalRaised);
        }
        
        _updateClearstreamPosition(investor, int256(amount), true);
        
        emit ICLEARSTREAMIntegration.IssuanceRecorded(investor, amount, issuanceId, block.timestamp);
        
        if (isKYCValid(investor)) {
            _verifyIssuance(issuanceId, ipfsCID);
        }
        
        return issuanceId;
    }
    
    function verifyInvestor(
        address _investor,
        string calldata _kycProviderURL,
        bool _refreshIfVerified
    ) external override onlyCompliance returns (bytes32 requestId) {
        investors[_investor].isVerified = true;
        investors[_investor].isAccredited = true;
        investors[_investor].verificationDate = block.timestamp;
        investors[_investor].lastKycRefresh = block.timestamp;
        
        kycRegistry[_investor] = KYCStatus({
            isApproved: true,
            expiry: uint64(block.timestamp + 365 days),
            lastUpdated: block.timestamp
        });
        
        emit ICSADerivatives.InvestorVerified(_investor, true, block.timestamp);
        
        return keccak256(abi.encodePacked(_investor, block.timestamp));
    }
    
    function fulfillVerification(
        bytes32 _requestId,
        bool _isAccredited
    ) external override {
        // Placeholder for oracle callback
    }
    
    function setTransferLock(
        address investor,
        uint256 unlockTime
    ) external override onlyCompliance {
        transferLocks[investor] = unlockTime;
        emit ICSADerivatives.TransferLockUpdated(investor, unlockTime);
    }
    
    function forceTransfer(
        address from,
        address to,
        uint256 amount,
        string calldata reason
    ) external override onlyCompliance nonReentrant whenNotPaused {
        require(from != address(0), "Invalid from");
        require(to != address(0), "Invalid to");
        require(amount > 0, "Amount must be > 0");
        require(bytes(reason).length > 0, "Reason required");
        
        _transfer(msg.sender, from, to, amount, bytes(reason));
        
        emit ICSADerivatives.ComplianceOverride(msg.sender, from, reason);
    }
    
    function setOfferingType(IDTCCCompliantSTO.OfferingType offeringType) external override onlyCompliance {
        currentOfferingType = offeringType;
        emit ICSADerivatives.OfferingTypeSet(offeringType, block.timestamp);
    }
    
    function verifyQIB(address investor, bool isQIB_) external override onlyQIBVerifier {
        investors[investor].isQIB = isQIB_;
        emit ICSADerivatives.QIBVerified(investor, isQIB_, block.timestamp);
    }
    
    function isQIB(address investor) external view override returns (bool) {
        return investors[investor].isQIB;
    }
    
    // ========================================
    // ICSADerivatives Required Functions
    // ========================================
    
    function reportDerivative(
        IDTCCCompliantSTO.DerivativeData calldata derivativeData,
        IDTCCCompliantSTO.CounterpartyData calldata counterparty1,
        IDTCCCompliantSTO.CounterpartyData calldata counterparty2,
        IDTCCCompliantSTO.CollateralData calldata collateralData,
        IDTCCCompliantSTO.ValuationData calldata valuationData
    ) external override onlyDerivativesReporter whenNotPaused 
    onlyValidDerivativeData(derivativeData) 
    onlyValidLEI(counterparty1.lei) 
    onlyValidLEI(counterparty2.lei)
    returns (bytes32 uti) {
        return _reportDerivative(derivativeData, counterparty1, counterparty2, collateralData, valuationData);
    }
    
    function correctDerivative(
        bytes32 uti,
        bytes32 priorUti,
        IDTCCCompliantSTO.DerivativeData calldata correctedData
    ) external override onlyDerivativesReporter whenNotPaused {
        require(derivatives[uti].uti != bytes32(0), "Derivative not found");
        require(priorUti != bytes32(0), "Invalid prior UTI");
        require(CSADerivativesLib.isValidCSADate(correctedData.effectiveDate, block.timestamp), "Invalid effective date");
        require(CSADerivativesLib.isValidCSADate(correctedData.expirationDate, block.timestamp), "Invalid expiration date");
        
        derivativeCorrections[uti].push(CSACorrection({
            priorUti: priorUti,
            correctedData: correctedData,
            correctionTimestamp: block.timestamp,
            correctedBy: msg.sender
        }));
        
        derivatives[uti] = correctedData;
        
        tradeRepository.correctTrade(uti, priorUti);
        
        emit ICSADerivatives.DerivativeCorrected(uti, priorUti, msg.sender, block.timestamp);
    }
    
    function reportError(
        bytes32 uti,
        string calldata reason
    ) external override onlyDerivativesReporter whenNotPaused {
        require(derivatives[uti].uti != bytes32(0), "Derivative not found");
        require(bytes(reason).length > 0, "Reason required");
        
        derivativeErrors[uti].push(CSAErrorReport({
            reason: reason,
            reportTimestamp: block.timestamp,
            reportedBy: msg.sender
        }));
        
        tradeRepository.reportError(uti, reason);
        
        emit ICSADerivatives.ErrorReported(uti, msg.sender, block.timestamp, reason);
    }
    
    function reportPosition(
        bytes32 positionId,
        bytes32[] calldata underlyingUtis,
        IDTCCCompliantSTO.ValuationData calldata valuationData
    ) external override onlyDerivativesReporter whenNotPaused {
        require(positionId != bytes32(0), "Invalid position");
        require(underlyingUtis.length > 0, "No underlying UTIs");
        require(CSADerivativesLib.validateValuationData(valuationData), "Invalid valuation");
        
        uint256 maxUnderlying = underlyingUtis.length > 50 ? 50 : underlyingUtis.length;
        for (uint i = 0; i < maxUnderlying; i++) {
            require(derivatives[underlyingUtis[i]].uti != bytes32(0), "Invalid underlying derivative");
        }
        
        positions[positionId] = CSAPosition({
            positionId: positionId,
            underlyingUtis: underlyingUtis,
            valuation: valuationData,
            lastUpdated: block.timestamp
        });
        
        emit ICSADerivatives.PositionReported(positionId, msg.sender, block.timestamp, ICSADerivatives.ActionType.NEWT);
    }
    
    function batchReportDerivatives(
        IDTCCCompliantSTO.DerivativeData[] calldata derivativesData,
        IDTCCCompliantSTO.CounterpartyData[] calldata counterparties1,
        IDTCCCompliantSTO.CounterpartyData[] calldata counterparties2,
        IDTCCCompliantSTO.CollateralData[] calldata collateralData,
        IDTCCCompliantSTO.ValuationData[] calldata valuationData
    ) external override onlyDerivativesReporter whenNotPaused {
        require(derivativesData.length == counterparties1.length, "Array length mismatch");
        require(derivativesData.length == counterparties2.length, "Array length mismatch");
        require(derivativesData.length == collateralData.length, "Array length mismatch");
        require(derivativesData.length == valuationData.length, "Array length mismatch");
        require(derivativesData.length <= 20, "Batch too large");
        
        for (uint i = 0; i < derivativesData.length; i++) {
            _reportDerivative(
                derivativesData[i],
                counterparties1[i],
                counterparties2[i],
                collateralData[i],
                valuationData[i]
            );
        }
    }
    
    // ========================================
    // ICLEARSTREAMIntegration Required Functions
    // ========================================
    
    function initiateSettlement(
        bytes32 tradeReference,
        address buyer,
        address seller,
        uint256 quantity,
        uint256 settlementAmount,
        uint256 valueDate
    ) external override onlyClearstreamOperator whenNotPaused returns (bytes32 settlementId) {
        require(tradeReference != bytes32(0) && buyer != address(0) && seller != address(0) && 
                quantity > 0 && settlementAmount > 0 && valueDate > block.timestamp, "Invalid params");
        
        settlementId = keccak256(abi.encodePacked(tradeReference, buyer, seller, quantity, block.timestamp));
        
        bytes20 buyerAccount = participantAccounts[buyer];
        bytes20 sellerAccount = participantAccounts[seller];
        
        require(buyerAccount != bytes20(0) && sellerAccount != bytes20(0), "No Clearstream account");
        
        clearstreamSettlements[settlementId] = ICLEARSTREAMIntegration.ClearstreamSettlement(
            settlementId,
            tradeReference,
            buyer,
            seller,
            quantity,
            settlementAmount,
            ICLEARSTREAMIntegration.ClearstreamSettlementStatus.PENDING,
            block.timestamp,
            valueDate,
            buyerAccount,
            sellerAccount,
            ClearstreamLib.bytes12ToString(isinCode),
            bytes32(0)
        );
        
        emit ICLEARSTREAMIntegration.ClearstreamSettlementInitiated(
            settlementId, tradeReference, buyer, seller, quantity, block.timestamp
        );
        
        if (clearstreamConfig.autoSettlementEnabled) {
            _generateSettlementInstructions(settlementId);
        }
        
        return settlementId;
    }
    
    function generateSettlementInstructions(bytes32 settlementId) external override onlyClearstreamOperator whenNotPaused {
        _generateSettlementInstructions(settlementId);
    }
    
    function confirmSettlement(bytes32 settlementId, bytes32 instructionReference) 
        external override onlyClearstreamOperator whenNotPaused 
    {
        ICLEARSTREAMIntegration.ClearstreamSettlement storage s = clearstreamSettlements[settlementId];
        require(s.settlementId != bytes32(0) && s.status == ICLEARSTREAMIntegration.ClearstreamSettlementStatus.INSTRUCTED, "Invalid");
        
        s.status = ICLEARSTREAMIntegration.ClearstreamSettlementStatus.CONFIRMED;
        s.instructionReference = instructionReference;
        
        _updateClearstreamPosition(s.buyer, int256(s.quantity), true);
        _updateClearstreamPosition(s.seller, -int256(s.quantity), false);
        
        settlementEvents[settlementId].push(
            ICLEARSTREAMIntegration.ClearstreamEvent(
                keccak256(abi.encodePacked(settlementId, block.timestamp, "CONFIRMED")),
                ICLEARSTREAMIntegration.ClearstreamEventType.SETTLEMENT_CONFIRMED,
                settlementId,
                "Settlement confirmed",
                block.timestamp,
                msg.sender,
                instructionReference
            )
        );
        
        emit ICLEARSTREAMIntegration.ClearstreamSettlementConfirmed(settlementId, instructionReference, block.timestamp);
    }
    
    function completeSettlement(bytes32 settlementId) external override onlyClearstreamOperator whenNotPaused {
        ICLEARSTREAMIntegration.ClearstreamSettlement storage s = clearstreamSettlements[settlementId];
        require(s.settlementId != bytes32(0) && s.status == ICLEARSTREAMIntegration.ClearstreamSettlementStatus.CONFIRMED, "Invalid");
        
        s.status = ICLEARSTREAMIntegration.ClearstreamSettlementStatus.SETTLED;
        
        settlementEvents[settlementId].push(
            ICLEARSTREAMIntegration.ClearstreamEvent(
                keccak256(abi.encodePacked(settlementId, block.timestamp, "COMPLETED")),
                ICLEARSTREAMIntegration.ClearstreamEventType.SETTLEMENT_COMPLETED,
                settlementId,
                "Settlement completed",
                block.timestamp,
                msg.sender,
                s.instructionReference
            )
        );
        
        emit ICLEARSTREAMIntegration.ClearstreamSettlementCompleted(settlementId, block.timestamp);
    }
    
    function linkClearstreamAccount(address investor, bytes20 csdAccount) external override onlyClearstreamOperator {
        require(investor != address(0), "Invalid investor");
        require(csdAccount != bytes20(0), "Invalid CSD account");
        
        participantAccounts[investor] = csdAccount;
        
        bytes32 positionKey = keccak256(abi.encodePacked(csdAccount, isinCode));
        if (clearstreamPositions[positionKey].participantAccount == bytes20(0)) {
            clearstreamPositions[positionKey] = ICLEARSTREAMIntegration.ClearstreamPosition({
                participantAccount: csdAccount,
                isin: ClearstreamLib.bytes12ToString(isinCode),
                position: 0,
                availableBalance: 0,
                blockedBalance: 0,
                lastUpdate: block.timestamp
            });
        }
        
        emit ICLEARSTREAMIntegration.ClearstreamAccountLinked(investor, csdAccount, block.timestamp);
    }
    
    function getClearstreamPosition(bytes20 csdAccount) external view override returns (ICLEARSTREAMIntegration.ClearstreamPosition memory) {
        bytes32 positionKey = keccak256(abi.encodePacked(csdAccount, isinCode));
        return clearstreamPositions[positionKey];
    }
    
    function updateClearstreamConfig(ICLEARSTREAMIntegration.ClearstreamConfig memory newConfig) external override onlyClearstreamOperator {
        require(newConfig.defaultCsdAccount != bytes20(0), "Invalid CSD account");
        
        clearstreamConfig = newConfig;
        
        emit ICLEARSTREAMIntegration.ClearstreamConfigUpdated(newConfig.defaultCsdAccount, newConfig.settlementCycle, block.timestamp);
    }
    
    function addISINToWhitelist(string memory isin) external override onlyClearstreamOperator {
        require(bytes(isin).length > 0, "Invalid ISIN");
        isinWhitelist[keccak256(bytes(isin))] = true;
        emit ICLEARSTREAMIntegration.ISINWhitelisted(isin, block.timestamp);
    }
    
    // ========================================
    // Internal Functions
    // ========================================
    
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Cannot mint to zero address");
        require(amount % _granularity == 0, "Amount must be multiple of granularity");
        
        _totalSupply += amount;
        _balances[to] += amount;
        
        emit Transfer(address(0), to, amount);
    }
    
    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "Cannot burn from zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(amount % _granularity == 0, "Amount must be multiple of granularity");
        
        _balances[from] -= amount;
        _totalSupply -= amount;
        
        emit Transfer(from, address(0), amount);
    }
    
    function _transfer(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) internal {
        _validateTransferBasics(from, to, amount);
        
        if (from != address(0) && to != address(0)) {
            _validateKYCAccess(from, to);
            _validateOfferingRestrictions(to, amount);
        }
        
        _executeTransfer(operator, from, to, amount, data);
    }
    
    function _validateTransferBasics(address from, address to, uint256 amount) private view {
        require(from != address(0), "Cannot transfer from zero");
        require(to != address(0), "Cannot transfer to zero");
        require(_balances[from] >= amount, "Insufficient balance");
        require(amount % _granularity == 0, "Amount must be multiple of granularity");
    }
    
    function _validateKYCAccess(address from, address to) private view {
        require(isKYCValid(to), "Receiver not KYC approved");
        require(isKYCValid(from), "Sender not KYC approved");
        require(block.timestamp >= transferLocks[from], "Tokens locked");
    }
    
    function _validateOfferingRestrictions(address to, uint256 amount) private view {
        if (currentOfferingType == ICSADerivatives.OfferingType.REG_D_506C) {
            require(investors[to].isAccredited, "Receiver not accredited");
        }
        
        if (currentOfferingType == ICSADerivatives.OfferingType.REG_CF) {
            ComplianceLib.validateRegCFTransfer(investors, totalRaised, to, amount);
        }
        
        if (currentOfferingType == ICSADerivatives.OfferingType.RULE_144A) {
            require(investors[to].isQIB, "Receiver not QIB");
        }
    }
    
    function _executeTransfer(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) private {
        _balances[from] -= amount;
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
        
        _checkCSATransferCompliance(from, to, amount);
        _validateClearstreamTransfer(from, to, amount);
        _reportTradeToDTCC(from, to, amount);
    }
    
    function _transferByPartition(
        bytes32 fromPartition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal returns (bytes32) {
        require(_balanceOfByPartition[from][fromPartition] >= value, "Insufficient partition balance");
        
        bytes32 toPartition = fromPartition;
        
        _removeTokenFromPartition(from, fromPartition, value);
        _transfer(operator, from, to, value, data);
        _addTokenToPartition(to, toPartition, value);
        
        emit TransferByPartition(fromPartition, operator, from, to, value, data, operatorData);
        
        return toPartition;
    }
    
    function _issueByPartition(
        bytes32 partition,
        address operator,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        require(to != address(0), "Cannot issue to zero");
        require(value > 0, "Value must be > 0");
        
        _mint(to, value);
        _addTokenToPartition(to, partition, value);
        
        emit Issued(operator, to, value, data);
        emit IssuedByPartition(partition, operator, to, value, data, "");
    }
    
    function _redeemByPartition(
        bytes32 partition,
        address operator,
        address from,
        uint256 value,
        bytes memory data,
        bytes memory operatorData
    ) internal {
        require(_balanceOfByPartition[from][partition] >= value, "Insufficient partition balance");
        
        _removeTokenFromPartition(from, partition, value);
        _burn(from, value);
        
        emit Redeemed(operator, from, value, data);
        emit RedeemedByPartition(partition, operator, from, value, operatorData);
    }
    
    function _redeemByDefaultPartitions(
        address operator,
        address from,
        uint256 value,
        bytes memory data
    ) internal {
        require(_defaultPartitions.length > 0, "No default partitions");
        
        uint256 remainingValue = value;
        
        for (uint i = 0; i < _defaultPartitions.length && remainingValue > 0; i++) {
            uint256 partitionBalance = _balanceOfByPartition[from][_defaultPartitions[i]];
            if (partitionBalance > 0) {
                uint256 redeemAmount = partitionBalance < remainingValue ? partitionBalance : remainingValue;
                _redeemByPartition(_defaultPartitions[i], operator, from, redeemAmount, data, "");
                remainingValue -= redeemAmount;
            }
        }
        
        require(remainingValue == 0, "Insufficient balance across partitions");
    }
    
    function _addTokenToPartition(address to, bytes32 partition, uint256 value) internal {
        if (value == 0) return;
        
        if (_balanceOfByPartition[to][partition] == 0) {
            _partitionsOf[to].push(partition);
        }
        
        _balanceOfByPartition[to][partition] += value;
        
        if (_totalSupplyByPartition[partition] == 0) {
            _totalPartitions.push(partition);
        }
        
        _totalSupplyByPartition[partition] += value;
    }
    
    function _removeTokenFromPartition(address from, bytes32 partition, uint256 value) internal {
        require(_balanceOfByPartition[from][partition] >= value, "Insufficient balance");
        
        _balanceOfByPartition[from][partition] -= value;
        _totalSupplyByPartition[partition] -= value;
        
        if (_balanceOfByPartition[from][partition] == 0) {
            bytes32[] storage userPartitions = _partitionsOf[from];
            for (uint i = 0; i < userPartitions.length; i++) {
                if (userPartitions[i] == partition) {
                    userPartitions[i] = userPartitions[userPartitions.length - 1];
                    userPartitions.pop();
                    break;
                }
            }
        }
        
        if (_totalSupplyByPartition[partition] == 0) {
            for (uint i = 0; i < _totalPartitions.length; i++) {
                if (_totalPartitions[i] == partition) {
                    _totalPartitions[i] = _totalPartitions[_totalPartitions.length - 1];
                    _totalPartitions.pop();
                    break;
                }
            }
        }
    }
    
    function _isOperator(address operator, address tokenHolder) internal view returns (bool) {
        return operator == tokenHolder || 
               _authorizedOperators[operator][tokenHolder] || 
               _isController[operator];
    }
    
    function _isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) internal view returns (bool) {
        return _isOperator(operator, tokenHolder) || 
               _authorizedOperatorsByPartition[tokenHolder][partition][operator];
    }
    
    function _checkCSATransferCompliance(address from, address to, uint256 amount) internal {
        if (hasRole(DERIVATIVES_REPORTER, from) || hasRole(DERIVATIVES_REPORTER, to)) {
            require(isKYCValid(to) && isKYCValid(from), "Parties must be KYC approved");
            
            bytes20 fromLEI = _getLEIForAddress(from);
            bytes20 toLEI = _getLEIForAddress(to);
            
            emit ICSADerivatives.CSAComplianceCheck(from, fromLEI, true, block.timestamp);
            emit ICSADerivatives.CSAComplianceCheck(to, toLEI, true, block.timestamp);
        }
    }
    
    function _validateClearstreamTransfer(address from, address to, uint256 amount) internal {
        bytes20 fromAccount = participantAccounts[from];
        bytes20 toAccount = participantAccounts[to];
        
        if (fromAccount != bytes20(0) || toAccount != bytes20(0)) {
            require(fromAccount != bytes20(0) && toAccount != bytes20(0), "Both parties need CSD accounts");
            
            bytes32 fromKey = keccak256(abi.encodePacked(fromAccount, isinCode));
            bytes32 toKey = keccak256(abi.encodePacked(toAccount, isinCode));
            
            ICLEARSTREAMIntegration.ClearstreamPosition storage fromPos = clearstreamPositions[fromKey];
            ICLEARSTREAMIntegration.ClearstreamPosition storage toPos = clearstreamPositions[toKey];
            
            require(fromPos.availableBalance >= amount, "Insufficient CSD balance");
            
            fromPos.availableBalance -= amount;
            fromPos.blockedBalance += amount;
            toPos.blockedBalance += amount;
            
            emit ICLEARSTREAMIntegration.ClearstreamTransferValidated(
                keccak256(abi.encodePacked(from, to, amount, block.timestamp)),
                from,
                to,
                amount,
                block.timestamp
            );
        }
    }
    
  function _generateSettlementInstructions(bytes32 settlementId) internal {
    ICLEARSTREAMIntegration.ClearstreamSettlement storage s = clearstreamSettlements[settlementId];
    require(s.settlementId != bytes32(0), "Settlement not found");
    
    s.status = ICLEARSTREAMIntegration.ClearstreamSettlementStatus.INSTRUCTED;
    
    bytes32 deliveryId = keccak256(abi.encodePacked(settlementId, "DELIVERY"));
    bytes32 receiptId = keccak256(abi.encodePacked(settlementId, "RECEIPT"));
    
    // Push delivery instruction directly
    settlementInstructions[settlementId].push();
    ICLEARSTREAMIntegration.ClearstreamInstruction storage di = settlementInstructions[settlementId][settlementInstructions[settlementId].length - 1];
    di.instructionId = deliveryId;
    di.instructionType = ICLEARSTREAMIntegration.ClearstreamInstructionType.DELIVERY;
    di.settlementId = settlementId;
    di.participant = s.seller;
    di.participantAccount = s.sellerAccount;
    di.quantity = s.quantity;
    di.amount = s.settlementAmount;
    di.status = ICLEARSTREAMIntegration.ClearstreamInstructionStatus.SENT_TO_CSD;
    di.instructionDate = block.timestamp;
    di.valueDate = s.valueDate;
    di.isin = s.isin;
    di.tradeReference = s.tradeReference;
    
    // Push receipt instruction directly
    settlementInstructions[settlementId].push();
    ICLEARSTREAMIntegration.ClearstreamInstruction storage ri = settlementInstructions[settlementId][settlementInstructions[settlementId].length - 1];
    ri.instructionId = receiptId;
    ri.instructionType = ICLEARSTREAMIntegration.ClearstreamInstructionType.RECEIPT;
    ri.settlementId = settlementId;
    ri.participant = s.buyer;
    ri.participantAccount = s.buyerAccount;
    ri.quantity = s.quantity;
    ri.amount = s.settlementAmount;
    ri.status = ICLEARSTREAMIntegration.ClearstreamInstructionStatus.SENT_TO_CSD;
    ri.instructionDate = block.timestamp;
    ri.valueDate = s.valueDate;
    ri.isin = s.isin;
    ri.tradeReference = s.tradeReference;
    
    // Push event directly
    settlementEvents[settlementId].push();
    ICLEARSTREAMIntegration.ClearstreamEvent storage ev = settlementEvents[settlementId][settlementEvents[settlementId].length - 1];
    ev.eventId = keccak256(abi.encodePacked(settlementId, block.timestamp, "INSTRUCTED"));
    ev.eventType = ICLEARSTREAMIntegration.ClearstreamEventType.INSTRUCTION_SENT;
    ev.settlementId = settlementId;
    ev.eventDescription = "Instructions sent";
    ev.eventTimestamp = block.timestamp;
    ev.triggeredBy = msg.sender;
    ev.referenceId = deliveryId;
    
    emit ICLEARSTREAMIntegration.ClearstreamInstructionsGenerated(settlementId, deliveryId, receiptId, block.timestamp);
}
    
    function _updateClearstreamPosition(address participant, int256 delta, bool isAvailable) internal {
        bytes20 csdAccount = participantAccounts[participant];
        if (csdAccount == bytes20(0)) return;
        
        bytes32 key = keccak256(abi.encodePacked(csdAccount, isinCode));
        ICLEARSTREAMIntegration.ClearstreamPosition storage position = clearstreamPositions[key];
        
        if (position.participantAccount == bytes20(0)) {
            position.participantAccount = csdAccount;
            position.isin = ClearstreamLib.bytes12ToString(isinCode);
            position.position = 0;
            position.availableBalance = 0;
            position.blockedBalance = 0;
        }
        
        if (delta > 0) {
            if (isAvailable) position.availableBalance += uint256(delta);
            position.position += uint256(delta);
        } else if (delta < 0) {
            uint256 decrease = uint256(-delta);
            if (isAvailable) {
                require(position.availableBalance >= decrease, "Insufficient available");
                position.availableBalance -= decrease;
            }
            require(position.position >= decrease, "Insufficient position");
            position.position -= decrease;
        }
        
        position.lastUpdate = block.timestamp;
        
        emit ICLEARSTREAMIntegration.ClearstreamPositionUpdated(
            csdAccount, 
            position.isin, 
            position.position, 
            block.timestamp
        );
    }
    
    function _getLEIForAddress(address addr) internal view returns (bytes20) {
        return leiRegistry.getLEIForAddress(addr);
    }
    
    function _reportTradeToDTCC(address from, address to, uint256 amount) internal {
        (uint80 roundId, int256 price, , uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        
        _validatePriceData(price, updatedAt, roundId, answeredInRound);
        
        bytes32 dtccRef = keccak256(abi.encodePacked(from, to, amount, block.timestamp, roundId));
        
        _reportCSATradeData(from, to, amount, uint256(price));
        
        emit ICSADerivatives.TradeReported(from, to, amount, uint256(price), dtccRef, block.timestamp);
    }
    
    function _validatePriceData(int256 price, uint256 updatedAt, uint80 roundId, uint80 answeredInRound) private view {
        require(price > 0, "Invalid price");
        require(updatedAt > 0, "Price feed error");
        require(answeredInRound >= roundId, "Stale price");
        require(block.timestamp - updatedAt <= PRICE_STALENESS_THRESHOLD, "Stale price");
    }
    
    function _reportCSATradeData(address from, address to, uint256 amount, uint256 price) internal {
        bytes32 csaRef = keccak256(abi.encodePacked("CSA_TRADE", from, to, amount, price, block.timestamp));
        emit ICSADerivatives.CSATradeDataReported(csaRef, from, to, amount, block.timestamp);
    }
    
    function _verifyIssuance(bytes32 issuanceId, string memory ipfsCID) internal {
        issuances[issuanceId].verified = true;
        emit ICSADerivatives.DACVerified(issuanceId, ipfsCID, block.timestamp);
    }
    
    function _generateCSAUTI(IDTCCCompliantSTO.DerivativeData calldata data) internal view returns (bytes32) {
        return CSADerivativesLib.generateCSAUTI(data.upi, data.executionTimestamp, msg.sender, block.chainid);
    }
    
    function _validateCSACounterparty(IDTCCCompliantSTO.CounterpartyData calldata counterparty) internal pure {
        require(CSADerivativesLib.validateCSACounterparty(
            counterparty.lei, counterparty.walletAddress, counterparty.jurisdiction
        ), "Invalid counterparty");
    }
    
    // ========================================
    // View Functions
    // ========================================
    
    function getDerivativeCorrections(bytes32 uti) external view returns (CSACorrection[] memory) {
        return derivativeCorrections[uti];
    }
    
    function getDerivativeErrors(bytes32 uti) external view returns (CSAErrorReport[] memory) {
        return derivativeErrors[uti];
    }
    
    function getPosition(bytes32 positionId) external view returns (CSAPosition memory) {
        return positions[positionId];
    }
    
    function getCollateralHistory(bytes32 uti) external view returns (CollateralUpdate[] memory) {
        return collateralUpdates[uti];
    }
    
    function getInvestorIssuances(address investor) external view returns (bytes32[] memory) {
        return investors[investor].issuanceIds;
    }
    
    function getClearstreamSettlement(bytes32 settlementId) external view returns (ICLEARSTREAMIntegration.ClearstreamSettlement memory) {
        return clearstreamSettlements[settlementId];
    }
    
    function getSettlementInstructions(bytes32 settlementId) external view returns (ICLEARSTREAMIntegration.ClearstreamInstruction[] memory) {
        return settlementInstructions[settlementId];
    }
    
    function getSettlementEvents(bytes32 settlementId) external view returns (ICLEARSTREAMIntegration.ClearstreamEvent[] memory) {
        return settlementEvents[settlementId];
    }
    
    // ========================================
    // Admin Functions
    // ========================================
    
    function updatePriceFeed(address newPriceFeed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newPriceFeed != address(0), "Invalid address");
        priceFeed = AggregatorV3Interface(newPriceFeed);
    }
    
    function updateLEIRegistry(address newRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        leiRegistry = ILEIRegistry(newRegistry);
    }
    
    function updateUPIProvider(address newProvider) external onlyRole(DEFAULT_ADMIN_ROLE) {
        upiProvider = IUPIProvider(newProvider);
    }
    
    function updateTradeRepository(address newRepository) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tradeRepository = ITradeRepository(newRepository);
    }
    
    // ========================================
    // Helper Functions
    // ========================================
    
    function generateTestLEI() external view returns (bytes20) {
        return CSADerivativesLib.generateTestLEI(msg.sender, block.timestamp);
    }
    
    function generateTestUPI() external view returns (bytes12) {
        return CSADerivativesLib.generateTestUPI(block.timestamp);
    }
    
    function generateTestUTI() external view returns (bytes32) {
        return CSADerivativesLib.generateTestUTI(msg.sender, block.timestamp);
    }
    
    function getNAV() public view override returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= PRICE_STALENESS_THRESHOLD, "Stale price");
        
        if (_totalSupply == 0) return 0;
        return (_totalSupply * uint256(price)) / 10**priceFeed.decimals();
    }
}
