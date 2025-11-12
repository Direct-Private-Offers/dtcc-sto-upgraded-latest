// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1400/ERC1400.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./interfaces/IDTCCCompliantSTO.sol";
import "./interfaces/ICSADerivatives.sol";
import "./interfaces/ICLEARSTREAMIntegration.sol";
import "./interfaces/ILEIRegistry.sol";
import "./interfaces/IUPIProvider.sol";
import "./interfaces/ITradeRepository.sol";

import "./lib/ComplianceLib.sol";
import "./lib/CSADerivativesLib.sol";
import "./lib/ClearstreamLib.sol";
import "./lib/DateTimeLib.sol";
import "./utils/Errors.sol";

/**
 * @title DTCCCompliantSTO
 * @dev Comprehensive security token with CSA derivatives compliance and Clearstream PMI integration
 * Combines ERC1400 security token features with CSA derivatives reporting and Clearstream settlement
 * @notice This contract handles security token issuance, compliance verification,
 *         CSA derivatives reporting, and Clearstream PMI integration
 */
contract DTCCCompliantSTO is 
    ERC1400, 
    ChainlinkClient, 
    ConfirmedOwner, 
    AccessControl, 
    Pausable,
    ReentrancyGuard,
    IDTCCCompliantSTO,
    ICSADerivatives,
    ICLEARSTREAMIntegration
{
    using ComplianceLib for *;
    using CSADerivativesLib for *;
    using ClearstreamLib for *;
    using DateTimeLib for *;
    
    // Roles
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant QIB_VERIFIER = keccak256("QIB_VERIFIER");
    bytes32 public constant DERIVATIVES_REPORTER = keccak256("DERIVATIVES_REPORTER");
    bytes32 public constant CLEARSTREAM_OPERATOR = keccak256("CLEARSTREAM_OPERATOR");
    
    // Chainlink Configuration
    AggregatorV3Interface internal priceFeed;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    // External registries for CSA compliance
    ILEIRegistry public leiRegistry;
    IUPIProvider public upiProvider;
    ITradeRepository public tradeRepository;
    
    // Security Token State
    OfferingType public currentOfferingType;
    uint256 public regCFMaxRaise = 5_000_000 * 10**18;
    uint256 public totalRaised;
    uint256 public nonAccreditedInvestorCount;
    
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
    mapping(address => bytes20) public participantAccounts; // CSD participant accounts
    mapping(bytes32 => bool) public isinWhitelist; // ISIN validation
    
    // Clearstream Configuration
    ClearstreamConfig public clearstreamConfig;
    bytes12 public isinCode; // International Securities Identification Number
    
    // Constants (Arbitrum Mainnet)
    address public constant ARB_LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant ARB_ORACLE = 0x2362A262148518Ce69600Cc5a6032aC8391233f5;
    bytes32 public constant COMPLIANCE_JOB = "53f9755920cd451a8fe46f5087468395";
    bytes32 public constant DAC_VERIFICATION_JOB = "a79995d8583345d5b0a3cdcce84b7da5";
    bytes32 public constant CLEARSTREAM_JOB = "c8b5e5d5e5d5e5d5e5d5e5d5e5d5e5d5"; // Clearstream integration job
    
    // Price feed staleness threshold (1 hour)
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600;
    
    // Structures
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
    }
    
    struct CollateralUpdate {
        CollateralData collateralData;
        uint256 updateTimestamp;
        address updatedBy;
    }
    
    // Clearstream Structures
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
        uint256 settlementCycle; // T+1, T+2, etc.
        bool autoSettlementEnabled;
        uint256 minSettlementAmount;
        string marketIdentifier;
        bytes20 operatingCsd;
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
    
    /**
     * @dev Constructor for DTCCCompliantSTO with Clearstream integration
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _initialSupply Initial token supply
     * @param _defaultLockup Default lockup period in seconds
     * @param _offeringType Type of securities offering (Reg D, Reg CF, etc.)
     * @param _leiRegistry Address of LEI registry contract
     * @param _upiProvider Address of UPI provider contract
     * @param _tradeRepository Address of trade repository contract
     * @param _isin ISIN code for Clearstream identification
     * @param _clearstreamConfig Clearstream configuration
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _defaultLockup,
        OfferingType _offeringType,
        address _leiRegistry,
        address _upiProvider,
        address _tradeRepository,
        string memory _isin,
        ClearstreamConfig memory _clearstreamConfig
    ) 
        ERC1400(_name, _symbol)
        ConfirmedOwner(msg.sender)
    {
        if (_leiRegistry == address(0)) revert Errors.ZeroAddress();
        if (_upiProvider == address(0)) revert Errors.ZeroAddress();
        if (_tradeRepository == address(0)) revert Errors.ZeroAddress();
        if (bytes(_isin).length == 0) revert Errors.InvalidInput();
        if (_clearstreamConfig.defaultCsdAccount == bytes20(0)) revert Errors.InvalidInput();
        
        _mint(msg.sender, _initialSupply);
        
        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(COMPLIANCE_OFFICER, msg.sender);
        _setupRole(ISSUER_ROLE, msg.sender);
        _setupRole(QIB_VERIFIER, msg.sender);
        _setupRole(DERIVATIVES_REPORTER, msg.sender);
        _setupRole(CLEARSTREAM_OPERATOR, msg.sender);
        
        // Set external registries
        leiRegistry = ILEIRegistry(_leiRegistry);
        upiProvider = IUPIProvider(_upiProvider);
        tradeRepository = ITradeRepository(_tradeRepository);
        
        // Set offering type
        currentOfferingType = _offeringType;
        if (_offeringType == OfferingType.REG_CF) {
            regCFMaxRaise = 5_000_000 * 10**18;
        }
        
        // Clearstream Configuration
        clearstreamConfig = _clearstreamConfig;
        isinCode = ClearstreamLib.stringToBytes12(_isin);
        isinWhitelist[keccak256(bytes(_isin))] = true;
        
        // Chainlink Setup
        setChainlinkToken(ARB_LINK);
        setChainlinkOracle(ARB_ORACLE);
        priceFeed = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612); // ETH/USD
        fee = 0.1 * 10**18; // 0.1 LINK
        jobId = COMPLIANCE_JOB;
        
        // Set default lockup
        transferLocks[msg.sender] = block.timestamp + _defaultLockup;
        
        emit OfferingTypeSet(_offeringType, block.timestamp);
        emit ClearstreamConfigured(_clearstreamConfig.defaultCsdAccount, _isin, block.timestamp);
    }
    
    // ========================================
    // Security Token Functions (IDTCCCompliantSTO)
    // ========================================
    
    /**
     * @dev Issue security tokens to an investor with Clearstream integration
     * @param _investor Address of the investor receiving tokens
     * @param _amount Amount of tokens to issue
     * @param _ipfsCID IPFS CID of the issuance document
     * @param _lockupPeriod Lockup period in seconds (0 for no lockup)
     * @param _csdAccount Clearstream CSD account for the investor
     * @return issuanceId Unique identifier for this issuance
     */
    function issueTokens(
        address _investor,
        uint256 _amount,
        string calldata _ipfsCID,
        uint256 _lockupPeriod,
        bytes20 _csdAccount
    ) external override onlyIssuer returns (bytes32 issuanceId) {
        if (_investor == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();
        if (bytes(_ipfsCID).length == 0) revert Errors.InvalidIPFSCID();
        
        // Regulatory compliance checks
        ComplianceLib.validateInvestorForOffering(
            investors,
            nonAccreditedInvestorCount,
            currentOfferingType,
            _investor,
            _amount
        );
        
        issuanceId = keccak256(abi.encodePacked(
            _investor,
            block.timestamp,
            _amount,
            _ipfsCID
        ));
        
        uint256 lockupEnd = _lockupPeriod > 0 ? block.timestamp + _lockupPeriod : 0;
        
        issuances[issuanceId] = Issuance({
            investor: _investor,
            amount: _amount,
            ipfsCID: _ipfsCID,
            timestamp: block.timestamp,
            lockupEnd: lockupEnd,
            verified: false,
            accredited: investors[_investor].isAccredited
        });
        
        // Update investor record
        investors[_investor].issuanceIds.push(issuanceId);
        investors[_investor].totalInvested += _amount;
        
        // Set Clearstream account for investor
        if (_csdAccount != bytes20(0)) {
            participantAccounts[_investor] = _csdAccount;
            emit ClearstreamAccountLinked(_investor, _csdAccount, block.timestamp);
        }
        
        if (lockupEnd > 0) {
            transferLocks[_investor] = lockupEnd;
            emit TransferLockUpdated(_investor, lockupEnd);
        }
        
        _mint(_investor, _amount);
        
        // Update raise tracking for Reg CF
        if (currentOfferingType == OfferingType.REG_CF) {
            totalRaised += _amount;
            emit RegCFInvestment(_investor, _amount, totalRaised);
        }
        
        // Report to Clearstream for position update
        _updateClearstreamPosition(_investor, int256(_amount), true);
        
        emit IssuanceRecorded(
            issuanceId,
            _investor,
            _amount,
            _ipfsCID,
            block.timestamp,
            _lockupPeriod
        );
        
        // Auto-verify if investor is pre-approved
        if (investors[_investor].isVerified) {
            _verifyIssuance(issuanceId, _ipfsCID);
        }
        
        return issuanceId;
    }
    
    /**
     * @dev Verify an investor through Chainlink KYC provider
     * @param _investor Address of investor to verify
     * @param _kycProviderURL URL of the KYC provider endpoint
     * @param _refreshIfVerified If true, refresh verification even if already verified
     * @return requestId Chainlink request ID for this verification
     */
    function verifyInvestor(
        address _investor,
        string calldata _kycProviderURL,
        bool _refreshIfVerified
    ) external override onlyCompliance returns (bytes32 requestId) {
        if (_investor == address(0)) revert Errors.ZeroAddress();
        if (bytes(_kycProviderURL).length == 0) revert Errors.InvalidInput();
        
        if (!_refreshIfVerified) {
            if (investors[_investor].isVerified) revert Errors.AlreadyVerified();
        }
        
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillVerification.selector
        );
        
        req.add("method", "POST");
        req.add("url", _kycProviderURL);
        req.add("body", string(abi.encodePacked(
            '{"address":"',
            ComplianceLib.toHexString(_investor),
            '","tokenContract":"',
            ComplianceLib.toHexString(address(this)),
            '"}'
        )));
        req.add("path", "accredited");
        
        requestId = sendChainlinkRequest(req, fee);
        pendingVerifications[requestId] = _investor;
        
        return requestId;
    }
    
    /**
     * @dev Callback function for Chainlink oracle to fulfill KYC verification
     * @param _requestId Chainlink request ID
     * @param _isAccredited Whether the investor is accredited
     */
    function fulfillVerification(
        bytes32 _requestId,
        bool _isAccredited
    ) public recordChainlinkFulfillment(_requestId) {
        address investor = pendingVerifications[_requestId];
        if (investor == address(0)) revert Errors.InvalidRequestId();
        
        investors[investor].isVerified = true;
        investors[investor].isAccredited = _isAccredited;
        investors[investor].verificationDate = block.timestamp;
        investors[investor].lastKycRefresh = block.timestamp;
        
        emit InvestorVerified(investor, _isAccredited, block.timestamp);
        
        // Auto-verify all pending issuances (with gas limit protection)
        bytes32[] memory issuanceIds = investors[investor].issuanceIds;
        uint256 maxIterations = issuanceIds.length > 100 ? 100 : issuanceIds.length; // Limit to prevent gas issues
        for (uint i = 0; i < maxIterations; i++) {
            if (!issuances[issuanceIds[i]].verified) {
                issuances[issuanceIds[i]].accredited = _isAccredited;
                _verifyIssuance(issuanceIds[i], issuances[issuanceIds[i]].ipfsCID);
            }
        }
    }
    
    function setTransferLock(
        address _investor,
        uint256 _unlockTime
    ) external override onlyCompliance {
        transferLocks[_investor] = _unlockTime;
        emit TransferLockUpdated(_investor, _unlockTime);
    }
    
    /**
     * @dev Force transfer tokens (compliance override)
     * @param _from Address to transfer from
     * @param _to Address to transfer to
     * @param _amount Amount to transfer
     * @param _reason Reason for compliance override
     */
    function forceTransfer(
        address _from,
        address _to,
        uint256 _amount,
        string calldata _reason
    ) external override onlyCompliance nonReentrant {
        if (_from == address(0)) revert Errors.ZeroAddress();
        if (_to == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();
        if (bytes(_reason).length == 0) revert Errors.InvalidInput();
        
        _transfer(_from, _to, _amount);
        emit ComplianceOverride(msg.sender, _from, _reason);
    }
    
    function setOfferingType(OfferingType _offeringType) external override onlyCompliance {
        currentOfferingType = _offeringType;
        emit OfferingTypeSet(_offeringType, block.timestamp);
    }
    
    function verifyQIB(address _investor, bool _isQIB) external override onlyQIBVerifier {
        investors[_investor].isQIB = _isQIB;
        emit QIBVerified(_investor, _isQIB, block.timestamp);
    }
    
    function isQIB(address _investor) external view override returns (bool) {
        return investors[_investor].isQIB;
    }
    
    // ========================================
    // CSA Derivatives Functions (ICSADerivatives)
    // ========================================
    
    function reportDerivative(
        DerivativeData calldata derivativeData,
        CounterpartyData calldata counterparty1,
        CounterpartyData calldata counterparty2,
        CollateralData calldata collateralData,
        ValuationData calldata valuationData
    ) external override onlyDerivativesReporter whenNotPaused 
    onlyValidDerivativeData(derivativeData) 
    onlyValidLEI(counterparty1.lei) 
    onlyValidLEI(counterparty2.lei)
    returns (bytes32 uti) {
        
        _validateCSACounterparty(counterparty1);
        _validateCSACounterparty(counterparty2);
        if (!CSADerivativesLib.validateCollateralData(collateralData)) revert Errors.InvalidCollateral();
        if (!CSADerivativesLib.validateValuationData(valuationData)) revert Errors.InvalidValuation();
        
        // Generate UTI if not provided
        uti = derivativeData.uti == bytes32(0) ? _generateCSAUTI(derivativeData) : derivativeData.uti;
        
        if (derivatives[uti].uti != bytes32(0)) revert Errors.DerivativeAlreadyReported();
        
        // Store derivative data
        derivatives[uti] = derivativeData;
        tradeCollateral[uti] = collateralData;
        
        // Report to trade repository
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
        
        emit DerivativeReported(
            uti,
            msg.sender,
            block.timestamp,
            ActionType.NEWT,
            EventType.TRAD
        );
        
        return uti;
    }
    
    function correctDerivative(
        bytes32 uti,
        bytes32 priorUti,
        DerivativeData calldata correctedData
    ) external override onlyDerivativesReporter whenNotPaused {
        if (derivatives[uti].uti == bytes32(0)) revert Errors.DerivativeNotFound();
        if (priorUti == bytes32(0)) revert Errors.InvalidUTI();
        if (!CSADerivativesLib.validateCSADate(correctedData.effectiveDate)) revert Errors.InvalidDate();
        if (!CSADerivativesLib.validateCSADate(correctedData.expirationDate)) revert Errors.InvalidDate();
        
        // Store correction
        derivativeCorrections[uti].push(CSACorrection({
            priorUti: priorUti,
            correctedData: correctedData,
            correctionTimestamp: block.timestamp,
            correctedBy: msg.sender
        }));
        
        // Update derivative data
        derivatives[uti] = correctedData;
        
        // Report correction to repository
        tradeRepository.correctTrade(uti, priorUti);
        
        emit DerivativeCorrected(uti, priorUti, msg.sender, block.timestamp);
    }
    
    function reportError(
        bytes32 uti,
        string calldata reason
    ) external override onlyDerivativesReporter whenNotPaused {
        if (derivatives[uti].uti == bytes32(0)) revert Errors.DerivativeNotFound();
        if (bytes(reason).length == 0) revert Errors.InvalidInput();
        
        derivativeErrors[uti].push(CSAErrorReport({
            reason: reason,
            reportTimestamp: block.timestamp,
            reportedBy: msg.sender
        }));
        
        tradeRepository.reportError(uti, reason);
        
        emit ErrorReported(uti, msg.sender, block.timestamp, reason);
    }
    
    function reportPosition(
        bytes32 positionId,
        bytes32[] calldata underlyingUtis,
        ValuationData calldata valuationData
    ) external override onlyDerivativesReporter whenNotPaused {
        if (positionId == bytes32(0)) revert Errors.InvalidPosition();
        if (underlyingUtis.length == 0) revert Errors.InvalidInput();
        if (!CSADerivativesLib.validateValuationData(valuationData)) revert Errors.InvalidValuation();
        
        // Validate all underlying derivatives exist (with gas limit protection)
        uint256 maxUnderlying = underlyingUtis.length > 50 ? 50 : underlyingUtis.length;
        for (uint i = 0; i < maxUnderlying; i++) {
            if (derivatives[underlyingUtis[i]].uti == bytes32(0)) revert Errors.InvalidUnderlyingDerivative();
        }
        
        positions[positionId] = CSAPosition({
            positionId: positionId,
            underlyingUtis: underlyingUtis,
            valuation: valuationData,
            lastUpdated: block.timestamp
        });
        
        emit PositionReported(
            positionId,
            msg.sender,
            block.timestamp,
            ActionType.NEWT
        );
    }
    
    function batchReportDerivatives(
        DerivativeData[] calldata derivativesData,
        CounterpartyData[] calldata counterparties1,
        CounterpartyData[] calldata counterparties2,
        CollateralData[] calldata collateralData,
        ValuationData[] calldata valuationData
    ) external override onlyDerivativesReporter whenNotPaused {
        if (derivativesData.length != counterparties1.length) revert Errors.InvalidInput();
        if (derivativesData.length != counterparties2.length) revert Errors.InvalidInput();
        if (derivativesData.length != collateralData.length) revert Errors.InvalidInput();
        if (derivativesData.length != valuationData.length) revert Errors.InvalidInput();
        
        // Limit batch size to prevent gas issues
        if (derivativesData.length > 20) revert Errors.InvalidInput();
        
        for (uint i = 0; i < derivativesData.length; i++) {
            reportDerivative(
                derivativesData[i],
                counterparties1[i],
                counterparties2[i],
                collateralData[i],
                valuationData[i]
            );
        }
    }
    
    // ========================================
    // Clearstream PMI Integration Functions (ICLEARSTREAMIntegration)
    // ========================================
    
    /**
     * @dev Initiate settlement through Clearstream PMI
     * @param _tradeReference Reference ID for the trade
     * @param _buyer Buyer address
     * @param _seller Seller address
     * @param _quantity Quantity of tokens to settle
     * @param _settlementAmount Settlement amount
     * @param _valueDate Value date for settlement
     * @return settlementId Clearstream settlement ID
     */
    function initiateSettlement(
        bytes32 _tradeReference,
        address _buyer,
        address _seller,
        uint256 _quantity,
        uint256 _settlementAmount,
        uint256 _valueDate
    ) external override onlyClearstreamOperator whenNotPaused returns (bytes32 settlementId) {
        if (_tradeReference == bytes32(0)) revert Errors.InvalidInput();
        if (_buyer == address(0) || _seller == address(0)) revert Errors.ZeroAddress();
        if (_quantity == 0) revert Errors.ZeroAmount();
        if (_settlementAmount == 0) revert Errors.ZeroAmount();
        if (_valueDate <= block.timestamp) revert Errors.InvalidDate();
        
        settlementId = keccak256(abi.encodePacked(
            _tradeReference,
            _buyer,
            _seller,
            _quantity,
            block.timestamp
        ));
        
        bytes20 buyerAccount = participantAccounts[_buyer];
        bytes20 sellerAccount = participantAccounts[_seller];
        
        if (buyerAccount == bytes20(0)) revert Errors.NoClearstreamAccount();
        if (sellerAccount == bytes20(0)) revert Errors.NoClearstreamAccount();
        
        clearstreamSettlements[settlementId] = ClearstreamSettlement({
            settlementId: settlementId,
            tradeReference: _tradeReference,
            buyer: _buyer,
            seller: _seller,
            quantity: _quantity,
            settlementAmount: _settlementAmount,
            status: ClearstreamSettlementStatus.PENDING,
            settlementDate: block.timestamp,
            valueDate: _valueDate,
            buyerAccount: buyerAccount,
            sellerAccount: sellerAccount,
            isin: ClearstreamLib.bytes12ToString(isinCode),
            instructionReference: bytes32(0)
        });
        
        emit ClearstreamSettlementInitiated(
            settlementId,
            _tradeReference,
            _buyer,
            _seller,
            _quantity,
            _settlementAmount,
            block.timestamp
        );
        
        // Auto-generate settlement instructions if enabled
        if (clearstreamConfig.autoSettlementEnabled) {
            _generateSettlementInstructions(settlementId);
        }
        
        return settlementId;
    }
    
    /**
     * @dev Generate settlement instructions for Clearstream
     * @param _settlementId Settlement ID to generate instructions for
     */
    function generateSettlementInstructions(
        bytes32 _settlementId
    ) external override onlyClearstreamOperator whenNotPaused {
        _generateSettlementInstructions(_settlementId);
    }
    
    /**
     * @dev Confirm settlement completion
     * @param _settlementId Settlement ID to confirm
     * @param _instructionReference Clearstream instruction reference
     */
    function confirmSettlement(
        bytes32 _settlementId,
        bytes32 _instructionReference
    ) external override onlyClearstreamOperator whenNotPaused {
        ClearstreamSettlement storage settlement = clearstreamSettlements[_settlementId];
        if (settlement.settlementId == bytes32(0)) revert Errors.SettlementNotFound();
        if (settlement.status != ClearstreamSettlementStatus.INSTRUCTED) revert Errors.InvalidSettlementStatus();
        
        settlement.status = ClearstreamSettlementStatus.CONFIRMED;
        settlement.instructionReference = _instructionReference;
        
        // Update positions
        _updateClearstreamPosition(settlement.buyer, int256(settlement.quantity), true);
        _updateClearstreamPosition(settlement.seller, -int256(settlement.quantity), false);
        
        settlementEvents[_settlementId].push(ClearstreamEvent({
            eventId: keccak256(abi.encodePacked(_settlementId, block.timestamp, "CONFIRMED")),
            eventType: ClearstreamEventType.SETTLEMENT_CONFIRMED,
            settlementId: _settlementId,
            eventDescription: "Settlement confirmed by Clearstream",
            eventTimestamp: block.timestamp,
            triggeredBy: msg.sender,
            referenceId: _instructionReference
        }));
        
        emit ClearstreamSettlementConfirmed(_settlementId, _instructionReference, block.timestamp);
    }
    
    /**
     * @dev Complete settlement process
     * @param _settlementId Settlement ID to complete
     */
    function completeSettlement(
        bytes32 _settlementId
    ) external override onlyClearstreamOperator whenNotPaused {
        ClearstreamSettlement storage settlement = clearstreamSettlements[_settlementId];
        if (settlement.settlementId == bytes32(0)) revert Errors.SettlementNotFound();
        if (settlement.status != ClearstreamSettlementStatus.CONFIRMED) revert Errors.InvalidSettlementStatus();
        
        settlement.status = ClearstreamSettlementStatus.SETTLED;
        
        settlementEvents[_settlementId].push(ClearstreamEvent({
            eventId: keccak256(abi.encodePacked(_settlementId, block.timestamp, "COMPLETED")),
            eventType: ClearstreamEventType.SETTLEMENT_COMPLETED,
            settlementId: _settlementId,
            eventDescription: "Settlement completed successfully",
            eventTimestamp: block.timestamp,
            triggeredBy: msg.sender,
            referenceId: settlement.instructionReference
        }));
        
        emit ClearstreamSettlementCompleted(_settlementId, block.timestamp);
    }
    
    /**
     * @dev Link investor to Clearstream CSD account
     * @param _investor Investor address
     * @param _csdAccount Clearstream CSD account
     */
    function linkClearstreamAccount(
        address _investor,
        bytes20 _csdAccount
    ) external override onlyClearstreamOperator {
        if (_investor == address(0)) revert Errors.ZeroAddress();
        if (_csdAccount == bytes20(0)) revert Errors.InvalidInput();
        
        participantAccounts[_investor] = _csdAccount;
        
        // Initialize position if not exists
        bytes32 positionKey = keccak256(abi.encodePacked(_csdAccount, isinCode));
        if (clearstreamPositions[positionKey].participantAccount == bytes20(0)) {
            clearstreamPositions[positionKey] = ClearstreamPosition({
                participantAccount: _csdAccount,
                isin: ClearstreamLib.bytes12ToString(isinCode),
                position: 0,
                availableBalance: 0,
                blockedBalance: 0,
                lastUpdate: block.timestamp
            });
        }
        
        emit ClearstreamAccountLinked(_investor, _csdAccount, block.timestamp);
    }
    
    /**
     * @dev Get Clearstream position for an account
     * @param _csdAccount Clearstream CSD account
     * @return position Clearstream position data
     */
    function getClearstreamPosition(
        bytes20 _csdAccount
    ) external view override returns (ClearstreamPosition memory position) {
        bytes32 positionKey = keccak256(abi.encodePacked(_csdAccount, isinCode));
        return clearstreamPositions[positionKey];
    }
    
    /**
     * @dev Update Clearstream configuration
     * @param _newConfig New Clearstream configuration
     */
    function updateClearstreamConfig(
        ClearstreamConfig memory _newConfig
    ) external override onlyClearstreamOperator {
        if (_newConfig.defaultCsdAccount == bytes20(0)) revert Errors.InvalidInput();
        
        clearstreamConfig = _newConfig;
        
        emit ClearstreamConfigUpdated(
            _newConfig.defaultCsdAccount,
            _newConfig.settlementCycle,
            _newConfig.autoSettlementEnabled,
            block.timestamp
        );
    }
    
    /**
     * @dev Add ISIN to whitelist
     * @param _isin ISIN code to add
     */
    function addISINToWhitelist(
        string memory _isin
    ) external onlyClearstreamOperator {
        if (bytes(_isin).length == 0) revert Errors.InvalidInput();
        
        isinWhitelist[keccak256(bytes(_isin))] = true;
        
        emit ISINWhitelisted(_isin, block.timestamp);
    }
    
    // ========================================
    // Internal Functions
    // ========================================
    
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        // Skip checks for minting/burning
        if (_from == address(0) || _to == address(0)) {
            return;
        }
        
        // KYC check for all transfers
        if (!investors[_to].isVerified) revert Errors.NotVerified();
        
        // Offering-specific restrictions
        if (currentOfferingType == OfferingType.REG_D_506C) {
            if (!investors[_to].isAccredited) revert Errors.NotAccredited();
        }
        
        if (currentOfferingType == OfferingType.REG_CF) {
            ComplianceLib.validateRegCFTransfer(
                investors,
                totalRaised,
                _to,
                _amount
            );
        }
        
        // Lockup period check
        if (block.timestamp < transferLocks[_from]) revert Errors.TokensLocked();
        
        // Rule 144A restrictions (qualified institutional buyers only)
        if (currentOfferingType == OfferingType.RULE_144A) {
            if (!investors[_to].isQIB) revert Errors.NotQIB();
        }
        
        // Additional CSA compliance checks for derivatives participants
        _checkCSATransferCompliance(_from, _to, _amount);
        
        // Clearstream position validation
        _validateClearstreamTransfer(_from, _to, _amount);
        
        // Report to DTCC
        _reportTradeToDTCC(_from, _to, _amount);
    }
    
    function _checkCSATransferCompliance(address _from, address _to, uint256 _amount) internal {
        // Check if either party is involved in derivatives reporting
        // This could trigger additional compliance requirements
        if (hasRole(DERIVATIVES_REPORTER, _from) || hasRole(DERIVATIVES_REPORTER, _to)) {
            // Additional compliance checks for derivatives participants
            require(
                investors[_to].isVerified && investors[_from].isVerified,
                "Both parties must be verified for derivatives-related transfers"
            );
            
            // Emit CSA compliance event
            bytes20 fromLEI = _getLEIForAddress(_from);
            bytes20 toLEI = _getLEIForAddress(_to);
            
            emit CSAComplianceCheck(_from, fromLEI, true, block.timestamp);
            emit CSAComplianceCheck(_to, toLEI, true, block.timestamp);
        }
    }
    
    function _validateClearstreamTransfer(address _from, address _to, uint256 _amount) internal {
        // Check if both parties have Clearstream accounts for institutional transfers
        bytes20 fromAccount = participantAccounts[_from];
        bytes20 toAccount = participantAccounts[_to];
        
        if (fromAccount != bytes20(0) || toAccount != bytes20(0)) {
            // At least one party is using Clearstream
            require(
                fromAccount != bytes20(0) && toAccount != bytes20(0),
                "Both parties must have Clearstream accounts for CSD transfers"
            );
            
            // Validate positions
            bytes32 fromPositionKey = keccak256(abi.encodePacked(fromAccount, isinCode));
            bytes32 toPositionKey = keccak256(abi.encodePacked(toAccount, isinCode));
            
            ClearstreamPosition storage fromPosition = clearstreamPositions[fromPositionKey];
            ClearstreamPosition storage toPosition = clearstreamPositions[toPositionKey];
            
            require(
                fromPosition.availableBalance >= _amount,
                "Insufficient available balance in Clearstream position"
            );
            
            // Update positions (will be finalized after settlement)
            fromPosition.availableBalance -= _amount;
            fromPosition.blockedBalance += _amount;
            toPosition.blockedBalance += _amount;
            
            emit ClearstreamTransferValidated(
                _from,
                _to,
                _amount,
                fromAccount,
                toAccount,
                block.timestamp
            );
        }
    }
    
    function _generateSettlementInstructions(bytes32 _settlementId) internal {
        ClearstreamSettlement storage settlement = clearstreamSettlements[_settlementId];
        if (settlement.settlementId == bytes32(0)) revert Errors.SettlementNotFound();
        
        settlement.status = ClearstreamSettlementStatus.INSTRUCTED;
        
        // Generate delivery instruction for seller
        bytes32 deliveryInstructionId = keccak256(abi.encodePacked(_settlementId, "DELIVERY"));
        settlementInstructions[_settlementId].push(ClearstreamInstruction({
            instructionId: deliveryInstructionId,
            instructionType: ClearstreamInstructionType.DELIVERY,
            settlementId: _settlementId,
            participant: settlement.seller,
            participantAccount: settlement.sellerAccount,
            quantity: settlement.quantity,
            amount: settlement.settlementAmount,
            status: ClearstreamInstructionStatus.SENT_TO_CSD,
            instructionDate: block.timestamp,
            valueDate: settlement.valueDate,
            isin: settlement.isin,
            tradeReference: settlement.tradeReference
        }));
        
        // Generate receipt instruction for buyer
        bytes32 receiptInstructionId = keccak256(abi.encodePacked(_settlementId, "RECEIPT"));
        settlementInstructions[_settlementId].push(ClearstreamInstruction({
            instructionId: receiptInstructionId,
            instructionType: ClearstreamInstructionType.RECEIPT,
            settlementId: _settlementId,
            participant: settlement.buyer,
            participantAccount: settlement.buyerAccount,
            quantity: settlement.quantity,
            amount: settlement.settlementAmount,
            status: ClearstreamInstructionStatus.SENT_TO_CSD,
            instructionDate: block.timestamp,
            valueDate: settlement.valueDate,
            isin: settlement.isin,
            tradeReference: settlement.tradeReference
        }));
        
        settlementEvents[_settlementId].push(ClearstreamEvent({
            eventId: keccak256(abi.encodePacked(_settlementId, block.timestamp, "INSTRUCTED")),
            eventType: ClearstreamEventType.INSTRUCTION_SENT,
            settlementId: _settlementId,
            eventDescription: "Settlement instructions sent to Clearstream",
            eventTimestamp: block.timestamp,
            triggeredBy: msg.sender,
            referenceId: deliveryInstructionId
        }));
        
        emit ClearstreamInstructionsGenerated(_settlementId, deliveryInstructionId, receiptInstructionId, block.timestamp);
    }
    
    function _updateClearstreamPosition(address _participant, int256 _amountDelta, bool _isAvailable) internal {
        bytes20 csdAccount = participantAccounts[_participant];
        if (csdAccount == bytes20(0)) return; // Skip if no Clearstream account
        
        bytes32 positionKey = keccak256(abi.encodePacked(csdAccount, isinCode));
        ClearstreamPosition storage position = clearstreamPositions[positionKey];
        
        if (position.participantAccount == bytes20(0)) {
            // Initialize position
            position.participantAccount = csdAccount;
            position.isin = ClearstreamLib.bytes12ToString(isinCode);
            position.position = 0;
            position.availableBalance = 0;
            position.blockedBalance = 0;
            position.lastUpdate = block.timestamp;
        }
        
        if (_amountDelta > 0) {
            if (_isAvailable) {
                position.availableBalance += uint256(_amountDelta);
            }
            position.position += uint256(_amountDelta);
        } else if (_amountDelta < 0) {
            uint256 amountDecrease = uint256(-_amountDelta);
            if (_isAvailable) {
                require(position.availableBalance >= amountDecrease, "Insufficient available balance");
                position.availableBalance -= amountDecrease;
            }
            require(position.position >= amountDecrease, "Insufficient position");
            position.position -= amountDecrease;
        }
        
        position.lastUpdate = block.timestamp;
        
        emit ClearstreamPositionUpdated(
            csdAccount,
            position.isin,
            position.position,
            position.availableBalance,
            position.blockedBalance,
            block.timestamp
        );
    }
    
    /**
     * @dev Get LEI for an address from the registry
     * @param _addr Address to lookup LEI for
     * @return LEI for the address
     */
    function _getLEIForAddress(address _addr) internal view returns (bytes20) {
        bytes20 lei = leiRegistry.getLEIForAddress(_addr);
        if (lei == bytes20(0)) {
            // If not in registry, return zero (should be handled by caller)
            return bytes20(0);
        }
        return lei;
    }
    
    /**
     * @dev Report trade to DTCC with validated price data
     * @param _from Address transferring tokens
     * @param _to Address receiving tokens
     * @param _amount Amount of tokens
     */
    function _reportTradeToDTCC(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        // Validate price data
        if (price <= 0) revert Errors.InvalidPrice();
        if (updatedAt == 0) revert Errors.PriceFeedError();
        if (answeredInRound < roundId) revert Errors.StalePrice();
        if (block.timestamp - updatedAt > PRICE_STALENESS_THRESHOLD) revert Errors.StalePrice();
        
        bytes32 dtccRef = keccak256(abi.encodePacked(
            _from, _to, _amount, block.timestamp, roundId
        ));
        
        // Additional CSA data reporting
        _reportCSATradeData(_from, _to, _amount, uint256(price));
        
        emit TradeReported(
            _from,
            _to,
            _amount,
            uint256(price),
            dtccRef,
            block.timestamp
        );
    }
    
    function _reportCSATradeData(address _from, address _to, uint256 _amount, uint256 price) internal {
        // This function would integrate with CSA reporting requirements
        bytes32 csaTradeRef = keccak256(abi.encodePacked(
            "CSA_TRADE",
            _from,
            _to,
            _amount,
            price,
            block.timestamp
        ));
        
        emit CSATradeDataReported(csaTradeRef, _from, _to, _amount, block.timestamp);
    }
    
    function _verifyIssuance(bytes32 _issuanceId, string memory _ipfsCID) internal {
        issuances[_issuanceId].verified = true;
        emit DACVerified(_issuanceId, _ipfsCID, block.timestamp);
    }
    
    function _generateCSAUTI(DerivativeData calldata derivativeData) internal view returns (bytes32) {
        return CSADerivativesLib.generateCSAUTI(
            derivativeData.upi,
            derivativeData.executionTimestamp,
            msg.sender,
            block.chainid
        );
    }
    
    function _validateCSACounterparty(CounterpartyData calldata counterparty) internal pure {
        require(CSADerivativesLib.validateCSACounterparty(
            counterparty.lei, 
            counterparty.walletAddress, 
            counterparty.jurisdiction
        ), "Invalid counterparty data");
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
    
    function getClearstreamSettlement(bytes32 settlementId) external view returns (ClearstreamSettlement memory) {
        return clearstreamSettlements[settlementId];
    }
    
    function getSettlementInstructions(bytes32 settlementId) external view returns (ClearstreamInstruction[] memory) {
        return settlementInstructions[settlementId];
    }
    
    function getSettlementEvents(bytes32 settlementId) external view returns (ClearstreamEvent[] memory) {
        return settlementEvents[settlementId];
    }
    
    // ========================================
    // Admin Functions
    // ========================================
    
    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Withdraw failed");
    }
    
    function updateOracleConfig(
        address _oracle,
        bytes32 _complianceJobId,
        uint256 _fee
    ) external onlyOwner {
        oracle = _oracle;
        jobId = _complianceJobId;
        fee = _fee;
    }
    
    function updateLEIRegistry(address newRegistry) external onlyOwner {
        leiRegistry = ILEIRegistry(newRegistry);
    }
    
    function updateUPIProvider(address newProvider) external onlyOwner {
        upiProvider = IUPIProvider(newProvider);
    }
    
    function updateTradeRepository(address newRepository) external onlyOwner {
        tradeRepository = ITradeRepository(newRepository);
    }
    
    function pause() external onlyCompliance {
        _pause();
    }
    
    function unpause() external onlyCompliance {
        _unpause();
    }
    
    // ========================================
    // Helper Functions
    // ========================================
    
    function generateTestLEI() external view returns (bytes20) {
        return CSADerivativesLib.generateTestLEI();
    }
    
    function generateTestUPI() external view returns (bytes12) {
        return CSADerivativesLib.generateTestUPI();
    }
    
    function generateTestUTI() external view returns (bytes32) {
        return CSADerivativesLib.generateTestUTI();
    }
    
    /**
     * @dev Get Net Asset Value (NAV) using Chainlink price feed
     * @return NAV in USD (scaled by price feed decimals)
     */
    function getNAV() public view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        // Validate price data
        if (price <= 0) revert Errors.InvalidPrice();
        if (updatedAt == 0) revert Errors.PriceFeedError();
        if (answeredInRound < roundId) revert Errors.StalePrice();
        if (block.timestamp - updatedAt > PRICE_STALENESS_THRESHOLD) revert Errors.StalePrice();
        
        if (totalSupply() == 0) return 0;
        return (totalSupply() * uint256(price)) / 10**priceFeed.decimals();
    }
}