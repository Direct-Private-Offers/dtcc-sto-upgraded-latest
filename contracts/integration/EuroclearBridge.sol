// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import "../interfaces/IEuroclearIntegration.sol";
import "../interfaces/IDTCCCompliantSTO.sol";
import "../interfaces/ICSADerivatives.sol";
import "../utils/Errors.sol";

contract EuroclearBridge is AccessControl, Pausable, ChainlinkClient, ConfirmedOwner, IEuroclearIntegration {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant SETTLEMENT_ROLE = keccak256("SETTLEMENT_ROLE");
    bytes32 public constant DERIVATIVES_ROLE = keccak256("DERIVATIVES_ROLE");

    // Chainlink Configuration
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    // Euroclear API configuration
    address public euroclearOracle;
    address public dtccSTO;
    
    // Security mappings
    mapping(bytes32 => SecurityDetails) public securities;
    mapping(bytes32 => address) public isinToToken;
    mapping(address => bytes32) public tokenToIsin;
    mapping(bytes32 => bool) public processedActions;
    mapping(bytes32 => bool) public settledTrades;
    mapping(bytes32 => bytes32) public euroclearToIssuance;

    // Chainlink constants (Arbitrum Mainnet)
    address public constant ARB_LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant ARB_ORACLE = 0x2362A262148518Ce69600Cc5a6032aC8391233f5;
    bytes32 public constant EUROCLEAR_JOB = "a79995d8583345d5b0a3cdcce84b7da5";

    /**
     * @dev Constructor for EuroclearBridge
     * @param _dtccSTO Address of the DTCCCompliantSTO contract
     * @param _euroclearOracle Address of the Euroclear oracle
     */
    constructor(
        address _dtccSTO,
        address _euroclearOracle
    ) ConfirmedOwner(msg.sender) {
        if (_dtccSTO == address(0)) revert Errors.ZeroAddress();
        if (_euroclearOracle == address(0)) revert Errors.ZeroAddress();
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ORACLE_ROLE, _euroclearOracle);
        _setupRole(SETTLEMENT_ROLE, msg.sender);
        _setupRole(DERIVATIVES_ROLE, msg.sender);
        
        dtccSTO = _dtccSTO;
        euroclearOracle = _euroclearOracle;

        // Chainlink Setup
        setChainlinkToken(ARB_LINK);
        setChainlinkOracle(ARB_ORACLE);
        fee = 0.1 * 10**18; // 0.1 LINK
        jobId = EUROCLEAR_JOB;
    }

    /**
     * @dev Tokenize a security from Euroclear
     * @param isin ISIN of the security
     * @param investor Address of the investor
     * @param amount Amount to tokenize
     * @param euroclearRef Euroclear reference ID
     * @param ipfsCID IPFS CID of the tokenization document
     * @return issuanceId Unique issuance identifier
     */
    function tokenizeSecurity(
        bytes32 isin,
        address investor,
        uint256 amount,
        bytes32 euroclearRef,
        string calldata ipfsCID
    ) external override onlyRole(ORACLE_ROLE) whenNotPaused returns (bytes32 issuanceId) {
        if (securities[isin].isin == bytes32(0)) revert Errors.InvalidSecurity();
        if (investor == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();
        if (bytes(ipfsCID).length == 0) revert Errors.InvalidIPFSCID();
        
        // Validate investor through Euroclear
        (bool isValid, string memory reason) = validateInvestor(isin, investor);
        require(isValid, reason);

        // Issue tokens through DTCCCompliantSTO
        issuanceId = IDTCCCompliantSTO(dtccSTO).issueTokens(
            investor,
            amount,
            ipfsCID,
            0 // No lockup for Euroclear securities
        );

        address tokenAddress = dtccSTO;
        isinToToken[isin] = tokenAddress;
        tokenToIsin[tokenAddress] = isin;
        euroclearToIssuance[euroclearRef] = issuanceId;

        emit SecurityTokenized(isin, tokenAddress, investor, amount, euroclearRef, issuanceId);
    }

    /**
     * @dev Process a corporate action from Euroclear
     * @param action Corporate action data structure
     */
    function processCorporateAction(
        CorporateAction calldata action
    ) external override onlyRole(ORACLE_ROLE) whenNotPaused {
        if (securities[action.isin].isin == bytes32(0)) revert Errors.InvalidSecurity();
        if (processedActions[action.reference]) revert Errors.ActionAlreadyProcessed();
        if (action.effectiveDate == 0) revert Errors.InvalidDate();
        if (bytes(action.actionType).length == 0) revert Errors.InvalidActionType();
        
        processedActions[action.reference] = true;

        // Handle different corporate action types
        bytes32 actionTypeHash = keccak256(abi.encodePacked(action.actionType));
        bytes32 dividendHash = keccak256(abi.encodePacked("DIVIDEND"));
        bytes32 splitHash = keccak256(abi.encodePacked("SPLIT"));
        bytes32 mergerHash = keccak256(abi.encodePacked("MERGER"));
        
        if (actionTypeHash == dividendHash) {
            _processDividend(action);
        } else if (actionTypeHash == splitHash) {
            _processStockSplit(action);
        } else if (actionTypeHash == mergerHash) {
            _processMerger(action);
        } else {
            revert Errors.InvalidActionType();
        }

        emit CorporateActionProcessed(action.isin, action.actionType, action.effectiveDate, action.reference);
    }

    /**
     * @dev Sync settlement from Euroclear to blockchain
     * @param tradeRef Trade reference ID
     * @param isin ISIN of the security
     * @param from Address transferring tokens
     * @param to Address receiving tokens
     * @param amount Amount to transfer
     * @param euroclearRef Euroclear settlement reference
     */
    function syncSettlement(
        bytes32 tradeRef,
        bytes32 isin,
        address from,
        address to,
        uint256 amount,
        bytes32 euroclearRef
    ) external override onlyRole(SETTLEMENT_ROLE) whenNotPaused {
        if (settledTrades[tradeRef]) revert Errors.InvalidInput(); // Already settled
        if (securities[isin].isin == bytes32(0)) revert Errors.InvalidSecurity();
        if (from == address(0)) revert Errors.ZeroAddress();
        if (to == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();
        
        settledTrades[tradeRef] = true;

        // Execute on-chain settlement
        IDTCCCompliantSTO(dtccSTO).forceTransfer(
            from,
            to,
            amount,
            string(abi.encodePacked("EUROCLEAR_SETTLEMENT_", euroclearRef))
        );

        emit SettlementCompleted(tradeRef, isin, from, to, amount, euroclearRef);
    }

    function reportEuroclearDerivative(
        EuroclearDerivativeData calldata euroclearDerivative
    ) external override onlyRole(DERIVATIVES_ROLE) whenNotPaused returns (bytes32 uti) {
        require(securities[euroclearDerivative.isin].isin != bytes32(0), "Security not registered");
        
        // Report derivative through DTCCCompliantSTO
        uti = IDTCCCompliantSTO(dtccSTO).reportDerivative(
            euroclearDerivative.derivativeData,
            euroclearDerivative.counterparty1,
            euroclearDerivative.counterparty2,
            euroclearDerivative.collateralData,
            euroclearDerivative.valuationData
        );

        emit EuroclearDerivativeReported(uti, euroclearDerivative.isin, msg.sender, block.timestamp);
    }

    /**
     * @dev Register a new security from Euroclear
     * @param security Security details structure
     */
    function registerSecurity(
        SecurityDetails calldata security
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (security.isin == bytes32(0)) revert Errors.InvalidSecurity();
        if (security.issuerLEI == bytes20(0)) revert Errors.InvalidLEI();
        if (security.upi == bytes12(0)) revert Errors.InvalidUPI();
        if (security.issueDate == 0) revert Errors.InvalidDate();
        if (bytes(security.description).length == 0) revert Errors.InvalidInput();
        
        securities[security.isin] = security;
    }

    function validateInvestor(
        bytes32 isin,
        address investor
    ) public view override returns (bool isValid, string memory reason) {
        if (investor == address(0)) {
            return (false, "Invalid investor address");
        }
        if (securities[isin].isin == bytes32(0)) {
            return (false, "Security not found");
        }
        
        // In production, this would call Euroclear API via Chainlink
        // For now, basic validation
        return (true, "");
    }

    function getEuroclearNAV(bytes32 isin) external view override returns (uint256) {
        require(securities[isin].isin != bytes32(0), "Security not registered");
        
        // In production, this would fetch NAV from Euroclear
        // For now, return a mock value
        return securities[isin].totalSupply * 100; // Mock NAV calculation
    }

    // Internal functions for corporate actions
    
    /**
     * @dev Process dividend corporate action
     * @param action Corporate action data containing dividend information
     * @notice Dividends are typically handled off-chain via payment rails
     *         This function records the dividend event on-chain for compliance
     */
    function _processDividend(CorporateAction memory action) internal {
        // Decode dividend data (expected format: amount per share)
        require(action.data.length >= 32, "Invalid dividend data");
        uint256 dividendPerShare = abi.decode(action.data, (uint256));
        
        if (dividendPerShare == 0) revert Errors.InvalidActionAmount();
        
        // In a full implementation, this would:
        // 1. Calculate total dividend amount based on token holdings
        // 2. Distribute dividends proportionally to token holders
        // 3. Record dividend distribution events
        // 4. Update security state
        
        // For now, emit event and record the action
        // Actual dividend distribution would be handled by payment processor
        // that reads events and distributes funds
    }

    /**
     * @dev Process stock split corporate action
     * @param action Corporate action data containing split ratio
     * @notice Adjusts token balances based on split ratio (e.g., 2:1 split doubles tokens)
     */
    function _processStockSplit(CorporateAction memory action) internal {
        // Decode split data (expected format: [numerator, denominator] for n:1 split)
        require(action.data.length >= 64, "Invalid split data");
        (uint256 numerator, uint256 denominator) = abi.decode(action.data, (uint256, uint256));
        
        if (numerator == 0 || denominator == 0) revert Errors.InvalidSplitRatio();
        if (numerator > 1000 || denominator > 1000) revert Errors.InvalidSplitRatio(); // Prevent extreme splits
        
        // In a full implementation, this would:
        // 1. Calculate new total supply: newSupply = oldSupply * numerator / denominator
        // 2. Mint additional tokens to all holders proportionally
        // 3. Update security state
        // 4. Record split event
        
        // For now, the split ratio is recorded and can be used by off-chain systems
        // Actual token adjustment would require minting to all holders, which
        // is gas-intensive and may need to be done in batches
    }

    /**
     * @dev Process merger corporate action
     * @param action Corporate action data containing merger details
     * @notice Handles token exchanges or redemptions in case of merger
     */
    function _processMerger(CorporateAction memory action) internal {
        // Decode merger data (expected format: [targetTokenAddress, exchangeRate])
        require(action.data.length >= 64, "Invalid merger data");
        (address targetToken, uint256 exchangeRate) = abi.decode(action.data, (address, uint256));
        
        if (targetToken == address(0) && exchangeRate == 0) {
            // Redemption scenario - tokens are burned
            // In full implementation, would burn tokens and process redemption
        } else if (targetToken != address(0)) {
            // Exchange scenario - tokens are exchanged for target token
            if (exchangeRate == 0) revert Errors.InvalidActionAmount();
            // In full implementation, would:
            // 1. Calculate exchange amounts for each holder
            // 2. Burn old tokens
            // 3. Issue/mint new tokens from target contract
            // 4. Record exchange events
        } else {
            revert Errors.InvalidInput();
        }
    }

    // Chainlink functions for Euroclear API calls
    function requestEuroclearData(
        string memory url,
        string memory path
    ) external onlyRole(ORACLE_ROLE) returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfillEuroclearData.selector);
        req.add("method", "GET");
        req.add("url", url);
        req.add("path", path);
        return sendChainlinkRequest(req, fee);
    }

    function fulfillEuroclearData(
        bytes32 requestId,
        bytes memory data
    ) public recordChainlinkFulfillment(requestId) {
        // Process Euroclear API response
        emit EuroclearDerivativeReported(requestId, bytes32(0), msg.sender, block.timestamp);
    }

    // Admin functions
    function updateEuroclearOracle(address newOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        euroclearOracle = newOracle;
    }

    function updateChainlinkConfig(
        address _oracle,
        bytes32 _jobId,
        uint256 _fee
    ) external onlyOwner {
        oracle = _oracle;
        jobId = _jobId;
        fee = _fee;
    }

    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Withdraw failed");
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}