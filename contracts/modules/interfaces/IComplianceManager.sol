// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/ICSADerivatives.sol";

interface IComplianceManager {
    // KYC Management
    function setKYC(address user, bool approved, uint64 expiry) external;
    function batchSetKYC(address[] calldata users, bool[] calldata approved, uint64[] calldata expiries) external;
    function isKYCValid(address user) external view returns (bool);
    
    // Investor Management
    function verifyInvestor(address investor, string calldata kycProviderURL) external returns (bytes32);
    function setAccreditedStatus(address investor, bool accredited) external;
    function setQIBStatus(address investor, bool isQIB) external;
    function isAccredited(address investor) external view returns (bool);
    function isQIB(address investor) external view returns (bool);
    
    // Transfer Restrictions
    function validateTransfer(address from, address to, uint256 amount) external view;
    function setTransferLock(address investor, uint256 unlockTime) external;
    function getTransferLock(address investor) external view returns (uint256);
    
    // Offering Type
    function setOfferingType(ICSADerivatives.OfferingType offeringType) external;
    function getOfferingType() external view returns (ICSADerivatives.OfferingType);
    
    // Track investment - ADD THIS
    function recordInvestment(address investor, uint256 amount) external;
    
    // Helper - ADD THIS
    function getLEIForAddress(address addr) external view returns (bytes20);
    
    // Events
    event InvestorVerified(address indexed investor, bool accredited, uint256 timestamp);
    event QIBVerified(address indexed investor, bool isQIB, uint256 timestamp);
    event TransferLockUpdated(address indexed investor, uint256 unlockTime);
    event OfferingTypeSet(ICSADerivatives.OfferingType offeringType, uint256 timestamp);
}
