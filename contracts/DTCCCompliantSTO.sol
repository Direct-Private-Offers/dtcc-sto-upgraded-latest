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
import "./interfaces/ILEIRegistry.sol";
import "./interfaces/IUPIProvider.sol";
import "./interfaces/ITradeRepository.sol";

import "./lib/ComplianceLib.sol";
import "./lib/CSADerivativesLib.sol";
import "./lib/DateTimeLib.sol";
import "./utils/Errors.sol";

/**
 * @title DTCCCompliantSTO
 * @dev Comprehensive security token with CSA derivatives compliance
 * Combines ERC1400 security token features with CSA derivatives reporting
 * @notice This contract handles security token issuance, compliance verification,
 *         and CSA derivatives reporting in compliance with DTCC regulations
 */
contract DTCCCompliantSTO is 
    ERC1400, 
    ChainlinkClient, 
    ConfirmedOwner, 
    AccessControl, 
    Pausable,
    ReentrancyGuard,
    IDTCCCompliantSTO,
    ICSADerivatives
{
    using ComplianceLib for *;
    using CSADerivativesLib for *;
    using DateTimeLib for *;
    
    // Roles
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant QIB_VERIFIER = keccak256("QIB_VERIFIER");
    bytes32 public constant DERIVATIVES_REPORTER = keccak256("DERIVATIVES_REPORTER");
    
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
    
    // Constants (Arbitrum Mainnet)
    address public constant ARB_LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant ARB_ORACLE = 0x2362A262148518Ce69600Cc5a6032aC8391233f5;
    bytes32 public constant COMPLIANCE_JOB = "53f9755920cd451a8fe46f5087468395";
    bytes32 public constant DAC_VERIFICATION_JOB = "a79995d8583345d5b0a3cdcce84b7da5";
    
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
    
    modifier onlyValidLEI(bytes20 lei) {
        require(leiRegistry.isValidLEI(lei), "Invalid LEI");
        _;
    }
    
    modifier onlyValidUPI(bytes12 upi) {
        require(upiProvider.isValidUPI(upi), "Invalid UPI");
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
     * @dev Constructor for DTCCCompliantSTO
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _initialSupply Initial token supply
     * @param _defaultLockup Default lockup period in seconds
     * @param _offeringType Type of securities offering (Reg D, Reg CF, etc.)
     * @param _leiRegistry Address of LEI registry contract
     * @param _upiProvider Address of UPI provider contract
     * @param _tradeRepository Address of trade repository contract
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _defaultLockup,
        OfferingType _offeringType,
        address _leiRegistry,
        address _upiProvider,
        address _tradeRepository
    ) 
        ERC1400(_name, _symbol)
        ConfirmedOwner(msg.sender)
    {
        if (_leiRegistry == address(0)) revert Errors.ZeroAddress();
        if (_upiProvider == address(0)) revert Errors.ZeroAddress();
        if (_tradeRepository == address(0)) revert Errors.ZeroAddress();
        
        _mint(msg.sender, _initialSupply);
        
        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(COMPLIANCE_OFFICER, msg.sender);
        _setupRole(ISSUER_ROLE, msg.sender);
        _setupRole(QIB_VERIFIER, msg.sender);
        _setupRole(DERIVATIVES_REPORTER, msg.sender);
        
        // Set external registries
        leiRegistry = ILEIRegistry(_leiRegistry);
        upiProvider = IUPIProvider(_upiProvider);
        tradeRepository = ITradeRepository(_tradeRepository);
        
        // Set offering type
        currentOfferingType = _offeringType;
        if (_offeringType == OfferingType.REG_CF) {
            regCFMaxRaise = 5_000_000 * 10**18;
        }
        
        // Chainlink Setup
        setChainlinkToken(ARB_LINK);
        setChainlinkOracle(ARB_ORACLE);
        priceFeed = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612); // ETH/USD
        fee = 0.1 * 10**18; // 0.1 LINK
        jobId = COMPLIANCE_JOB;
        
        // Set default lockup
        transferLocks[msg.sender] = block.timestamp + _defaultLockup;
        
        emit OfferingTypeSet(_offeringType, block.timestamp);
    }
    
    // ========================================
    // Security Token Functions (IDTCCCompliantSTO)
    // ========================================
    
    /**
     * @dev Issue security tokens to an investor
     * @param _investor Address of the investor receiving tokens
     * @param _amount Amount of tokens to issue
     * @param _ipfsCID IPFS CID of the issuance document
     * @param _lockupPeriod Lockup period in seconds (0 for no lockup)
     * @return issuanceId Unique identifier for this issuance
     */
    function issueTokens(
        address _investor,
        uint256 _amount,
        string calldata _ipfsCID,
        uint256 _lockupPeriod
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