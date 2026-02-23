// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


// Minimal interfaces to reduce imports
interface ITokenCoreMinimal {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function approve(address, address, uint256) external returns (bool);
    function transferFrom(address, address, address, uint256) external returns (bool);
    function balanceOfByPartition(bytes32, address) external view returns (uint256);
    function partitionsOf(address) external view returns (bytes32[] memory);
    function transferByPartition(bytes32, address, address, address, uint256, bytes calldata, string calldata) external returns (bytes32);
    function mint(address, uint256, bytes32) external;
    function getDefaultPartitions() external view returns (bytes32[] memory);
}

interface IComplianceManagerMinimal {
    function validateTransfer(address, address, uint256) external;
    function isAccredited(address) external view returns (bool);
    function setTransferLock(address, uint256) external;
    function recordInvestment(address, uint256) external;
    function verifyInvestor(address, string calldata) external returns (bytes32);
    function setQIBStatus(address, bool) external;
    function isQIB(address) external view returns (bool);
    function setKYC(address, bool, uint64) external;
    function isKYCValid(address) external view returns (bool);
    function setOfferingType(uint8) external;
}

interface ICSADerivativesManagerMinimal {
    function reportDerivative(
        bytes calldata, bytes calldata, bytes calldata, bytes calldata, bytes calldata
    ) external returns (bytes32);
    function correctDerivative(bytes32, bytes32, bytes calldata) external;
    function reportError(bytes32, string calldata) external;
    function reportPosition(bytes32, bytes32[] calldata, bytes calldata) external;
    function batchReportDerivatives(
        bytes[] calldata, bytes[] calldata, bytes[] calldata, bytes[] calldata, bytes[] calldata
    ) external;
}

interface IClearstreamManagerMinimal {
    function initiateSettlement(bytes32, address, address, uint256, uint256, uint256) external returns (bytes32);
    function generateSettlementInstructions(bytes32) external;
    function confirmSettlement(bytes32, bytes32) external;
    function completeSettlement(bytes32) external;
    function linkClearstreamAccount(address, bytes20) external;
}

// Minimal Pausable - single slot
abstract contract MinimalPausable {
    bool private _paused;
    modifier whenNotPaused() { require(!_paused, "1"); _; }
    function _pause() internal { _paused = true; }
    function _unpause() internal { _paused = false; }
}

// Minimal ReentrancyGuard - single slot
abstract contract MinimalReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status != 2, "2");
        _status = 2;
        _;
        _status = 1;
    }
}

contract DTCCCompliantSTO is AccessControl, MinimalPausable, MinimalReentrancyGuard {
    bytes32 constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Storage - grouped to minimize slots
    ITokenCoreMinimal public tokenCore;
    IComplianceManagerMinimal public complianceManager;
    ICSADerivativesManagerMinimal public derivativesManager;
    IClearstreamManagerMinimal public clearstreamManager;
    AggregatorV3Interface public priceFeed;
    
    uint256 constant PRICE_STALENESS_THRESHOLD = 3600;
    
    struct Issuance {
        address investor;
        uint96 amount;      // 96 bits for amount
        uint64 timestamp;    // 64 bits for timestamp
        uint64 lockupEnd;    // 64 bits for lockup
        bool verified;
        bool accredited;
        string ipfsCID;      // Separate slot
    }
    
    mapping(bytes32 => Issuance) public issuances;
    mapping(address => bytes32[]) public investorIssuances;
    
    event ModulesUpdated(address,address,address,address);
    
    constructor(
        address tokenCore_,
        address complianceManager_,
        address derivativesManager_,
        address clearstreamManager_,
        address priceFeed_
    ) {
        tokenCore = ITokenCoreMinimal(tokenCore_);
        complianceManager = IComplianceManagerMinimal(complianceManager_);
        derivativesManager = ICSADerivativesManagerMinimal(derivativesManager_);
        clearstreamManager = IClearstreamManagerMinimal(clearstreamManager_);
        priceFeed = AggregatorV3Interface(priceFeed_);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    // Delegated functions - minimal stack usage
    function name() external view returns (string memory) { return tokenCore.name(); }
    function symbol() external view returns (string memory) { return tokenCore.symbol(); }
    function decimals() external pure returns (uint8) { return 18; }
    function totalSupply() external view returns (uint256) { return tokenCore.totalSupply(); }
    function balanceOf(address a) external view returns (uint256) { return tokenCore.balanceOf(a); }
    
    function transfer(address to, uint256 amt) external whenNotPaused returns (bool) {
        complianceManager.validateTransfer(msg.sender, to, amt);
        return tokenCore.transfer(msg.sender, to, amt);
    }
    
    function allowance(address o, address s) external view returns (uint256) { return tokenCore.allowance(o, s); }
    
    function approve(address s, uint256 amt) external whenNotPaused returns (bool) {
        return tokenCore.approve(msg.sender, s, amt);
    }
    
    function transferFrom(address f, address t, uint256 amt) external whenNotPaused returns (bool) {
        complianceManager.validateTransfer(f, t, amt);
        return tokenCore.transferFrom(msg.sender, f, t, amt);
    }
    
    function balanceOfByPartition(bytes32 p, address h) external view returns (uint256) {
        return tokenCore.balanceOfByPartition(p, h);
    }
    
    function partitionsOf(address h) external view returns (bytes32[] memory) {
        return tokenCore.partitionsOf(h);
    }
    
    function transferByPartition(bytes32 p, address t, uint256 v, bytes calldata d) external whenNotPaused returns (bytes32) {
        complianceManager.validateTransfer(msg.sender, t, v);
        return tokenCore.transferByPartition(p, msg.sender, msg.sender, t, v, d, "");
    }
    
    // Optimized issuance - minimal stack variables
    function issueTokens(
        address i,
        uint256 a,
        string calldata c,
        uint256 l,
        bytes20 ca
    ) external onlyRole(ISSUER_ROLE) whenNotPaused returns (bytes32 id) {
        require(i != address(0) && a > 0, "0");
        
        id = keccak256(abi.encodePacked(i, block.timestamp, a, c));
        
        issuances[id] = Issuance({
            investor: i,
            amount: uint96(a),
            timestamp: uint64(block.timestamp),
            lockupEnd: l > 0 ? uint64(block.timestamp + l) : 0,
            verified: false,
            accredited: complianceManager.isAccredited(i),
            ipfsCID: c
        });
        
        investorIssuances[i].push(id);
        
        // Mint
        bytes32[] memory dp = tokenCore.getDefaultPartitions();
        require(dp.length > 0, "4");
        tokenCore.mint(i, a, dp[0]);
        
        if (l > 0) complianceManager.setTransferLock(i, block.timestamp + l);
        if (ca != bytes20(0)) clearstreamManager.linkClearstreamAccount(i, ca);
        
        complianceManager.recordInvestment(i, a);
    }
    
    // Compliance functions - single line where possible
    function verifyInvestor(address i, string calldata u, bool) external onlyRole(COMPLIANCE_OFFICER) returns (bytes32) {
        return complianceManager.verifyInvestor(i, u);
    }
    
    function setTransferLock(address i, uint256 t) external onlyRole(COMPLIANCE_OFFICER) {
        complianceManager.setTransferLock(i, t);
    }
    
    function forceTransfer(address f, address t, uint256 a, string calldata r) 
        external onlyRole(COMPLIANCE_OFFICER) nonReentrant whenNotPaused {
        require(bytes(r).length > 0, "3");
        tokenCore.transferFrom(msg.sender, f, t, a);
    }
    
    function setOfferingType(uint8 o) external onlyRole(COMPLIANCE_OFFICER) {
        complianceManager.setOfferingType(o);
    }
    
    function verifyQIB(address i, bool b) external onlyRole(COMPLIANCE_OFFICER) {
        complianceManager.setQIBStatus(i, b);
    }
    
    function isQIB(address i) external view returns (bool) { return complianceManager.isQIB(i); }
    function setKYC(address u, bool a, uint64 e) external onlyRole(COMPLIANCE_OFFICER) { complianceManager.setKYC(u, a, e); }
    function isKYCValid(address u) public view returns (bool) { return complianceManager.isKYCValid(u); }
    
    // Derivative functions - using bytes for minimal stack
    function reportDerivative(
        bytes calldata d1, bytes calldata d2, bytes calldata d3, bytes calldata d4, bytes calldata d5
    ) external onlyRole(ISSUER_ROLE) whenNotPaused returns (bytes32) {
        return derivativesManager.reportDerivative(d1, d2, d3, d4, d5);
    }
    
    function correctDerivative(bytes32 u, bytes32 p, bytes calldata d) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.correctDerivative(u, p, d);
    }
    
    function reportError(bytes32 u, string calldata r) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.reportError(u, r);
    }
    
    function reportPosition(bytes32 p, bytes32[] calldata u, bytes calldata v) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.reportPosition(p, u, v);
    }
    
    function batchReportDerivatives(
        bytes[] calldata d1, bytes[] calldata d2, bytes[] calldata d3, bytes[] calldata d4, bytes[] calldata d5
    ) external onlyRole(ISSUER_ROLE) whenNotPaused {
        derivativesManager.batchReportDerivatives(d1, d2, d3, d4, d5);
    }
    
    // Clearstream functions
    function initiateSettlement(bytes32 t, address b, address s, uint256 q, uint256 a, uint256 v) 
        external onlyRole(ISSUER_ROLE) whenNotPaused returns (bytes32) {
        return clearstreamManager.initiateSettlement(t, b, s, q, a, v);
    }
    
    function generateSettlementInstructions(bytes32 i) external onlyRole(ISSUER_ROLE) whenNotPaused {
        clearstreamManager.generateSettlementInstructions(i);
    }
    
    function confirmSettlement(bytes32 i, bytes32 r) external onlyRole(ISSUER_ROLE) whenNotPaused {
        clearstreamManager.confirmSettlement(i, r);
    }
    
    function completeSettlement(bytes32 i) external onlyRole(ISSUER_ROLE) whenNotPaused {
        clearstreamManager.completeSettlement(i);
    }
    
    function linkClearstreamAccount(address i, bytes20 a) external onlyRole(COMPLIANCE_OFFICER) {
        clearstreamManager.linkClearstreamAccount(i, a);
    }
    
    // View functions
    function getNAV() public view returns (uint256) {
        (, int256 p, , uint256 u, ) = priceFeed.latestRoundData();
        require(p > 0 && block.timestamp - u <= PRICE_STALENESS_THRESHOLD, "5");
        
        uint256 ts = tokenCore.totalSupply();
        if (ts == 0) return 0;
        
        return (ts * uint256(p)) / 10 ** priceFeed.decimals();
    }
    
    function getInvestorIssuances(address i) external view returns (bytes32[] memory) {
        return investorIssuances[i];
    }
    
    function updateModules(address t, address c, address d, address cl) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (t != address(0)) tokenCore = ITokenCoreMinimal(t);
        if (c != address(0)) complianceManager = IComplianceManagerMinimal(c);
        if (d != address(0)) derivativesManager = ICSADerivativesManagerMinimal(d);
        if (cl != address(0)) clearstreamManager = IClearstreamManagerMinimal(cl);
        emit ModulesUpdated(t, c, d, cl);
    }
    
    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }
    function fulfillVerification(bytes32, bool) external pure { revert("0"); }
}
