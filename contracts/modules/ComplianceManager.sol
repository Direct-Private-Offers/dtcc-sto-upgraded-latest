// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IComplianceManager.sol";
import "../interfaces/ILEIRegistry.sol";
import "../lib/ComplianceLib.sol";

contract ComplianceManager is AccessControl, IComplianceManager {
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant QIB_VERIFIER = keccak256("QIB_VERIFIER");
    
    struct KYCStatus {
        bool isApproved;
        uint64 expiry;
        uint256 lastUpdated;
    }
    
    struct InvestorData {
        bool isVerified;
        bool isAccredited;
        bool isQIB;
        uint256 verificationDate;
        uint256 lastKycRefresh;
        uint256 totalInvested;
        bytes32[] issuanceIds;
    }
    
    // KYC Registry
    mapping(address => KYCStatus) public kycRegistry;
    mapping(address => InvestorData) public investors;
    mapping(address => uint256) public transferLocks;
    
    // Offering Configuration
    ICSADerivatives.OfferingType public currentOfferingType;
    uint256 public regCFMaxRaise = 5_000_000 * 10 ** 18;
    uint256 public totalRaised;
    uint256 public nonAccreditedInvestorCount;
    
    // External dependencies
    ILEIRegistry public leiRegistry;
    
    constructor(address leiRegistry_) {
        require(leiRegistry_ != address(0), "Invalid LEI registry");
        leiRegistry = ILEIRegistry(leiRegistry_);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER, msg.sender);
        _grantRole(QIB_VERIFIER, msg.sender);
    }
    
    // KYC Management
    function setKYC(address user, bool approved, uint64 expiry) external onlyRole(COMPLIANCE_OFFICER) {
        require(user != address(0), "Invalid user");
        
        kycRegistry[user] = KYCStatus({
            isApproved: approved,
            expiry: expiry,
            lastUpdated: block.timestamp
        });
        
        investors[user].isVerified = approved;
        investors[user].verificationDate = block.timestamp;
        investors[user].lastKycRefresh = block.timestamp;
        
        emit InvestorVerified(user, investors[user].isAccredited, block.timestamp);
    }
    
    function batchSetKYC(
        address[] calldata users,
        bool[] calldata approved,
        uint64[] calldata expiries
    ) external onlyRole(COMPLIANCE_OFFICER) {
        require(users.length == approved.length && users.length == expiries.length, "Array length mismatch");
        require(users.length <= 100, "Batch size too large");
        
        for (uint i = 0; i < users.length; i++) {
            kycRegistry[users[i]] = KYCStatus(approved[i], expiries[i], block.timestamp);
            investors[users[i]].isVerified = approved[i];
            investors[users[i]].verificationDate = block.timestamp;
            investors[users[i]].lastKycRefresh = block.timestamp;
            
            emit InvestorVerified(users[i], investors[users[i]].isAccredited, block.timestamp);
        }
    }
    
    function isKYCValid(address user) public view returns (bool) {
        KYCStatus memory status = kycRegistry[user];
        if (!status.isApproved) return false;
        if (status.expiry > 0 && block.timestamp > status.expiry) return false;
        return true;
    }
    
    // Investor Management
    function verifyInvestor(address investor, string calldata /*kycProviderURL*/) external onlyRole(COMPLIANCE_OFFICER) returns (bytes32) {
        investors[investor].isVerified = true;
        investors[investor].verificationDate = block.timestamp;
        investors[investor].lastKycRefresh = block.timestamp;
        
        kycRegistry[investor] = KYCStatus(true, uint64(block.timestamp + 365 days), block.timestamp);
        
        emit InvestorVerified(investor, investors[investor].isAccredited, block.timestamp);
        return keccak256(abi.encodePacked(investor, block.timestamp));
    }
    
    function setAccreditedStatus(address investor, bool accredited) external onlyRole(COMPLIANCE_OFFICER) {
        investors[investor].isAccredited = accredited;
    }
    
    function setQIBStatus(address investor, bool isQIB_) external onlyRole(QIB_VERIFIER) {
        investors[investor].isQIB = isQIB_;
        emit QIBVerified(investor, isQIB_, block.timestamp);
    }
    
    function isAccredited(address investor) external view returns (bool) {
        return investors[investor].isAccredited;
    }
    
    function isQIB(address investor) external view returns (bool) {
        return investors[investor].isQIB;
    }
    
    // Transfer Validation
    function validateTransfer(address from, address to, uint256 amount) external view {
        require(isKYCValid(to), "Receiver not KYC approved");
        require(isKYCValid(from), "Sender not KYC approved");
        require(block.timestamp >= transferLocks[from], "Tokens locked");
        
        if (currentOfferingType == ICSADerivatives.OfferingType.REG_D_506C) {
            require(investors[to].isAccredited, "Receiver not accredited");
        }
        
        if (currentOfferingType == ICSADerivatives.OfferingType.REG_CF) {
            require(investors[to].isVerified, "Reg CF requires verified investors");
            require(amount <= regCFMaxRaise - totalRaised, "Reg CF limit exceeded");
        }
        
        if (currentOfferingType == ICSADerivatives.OfferingType.RULE_144A) {
            require(investors[to].isQIB, "Receiver not QIB");
        }
    }
    
    function setTransferLock(address investor, uint256 unlockTime) external onlyRole(COMPLIANCE_OFFICER) {
        transferLocks[investor] = unlockTime;
        emit TransferLockUpdated(investor, unlockTime);
    }
    
    function getTransferLock(address investor) external view returns (uint256) {
        return transferLocks[investor];
    }
    
    // Offering Type
    function setOfferingType(ICSADerivatives.OfferingType offeringType) external onlyRole(COMPLIANCE_OFFICER) {
        currentOfferingType = offeringType;
        emit OfferingTypeSet(offeringType, block.timestamp);
    }
    
    function getOfferingType() external view returns (ICSADerivatives.OfferingType) {
        return currentOfferingType;
    }
    
    // Track investment
    function recordInvestment(address investor, uint256 amount) external onlyRole(COMPLIANCE_OFFICER) {
        investors[investor].totalInvested += amount;
        totalRaised += amount;
    }
    
    // Helper to get LEI
    function getLEIForAddress(address addr) external view returns (bytes20) {
        return leiRegistry.getLEIForAddress(addr);
    }
}
