// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMonitoringHub {
    function logTransaction(
        address participant,
        uint256 amount,
        uint256 transactionType,
        uint256 timestamp
    ) external returns (bool logged);
    
    function generateAlert(
        address subject,
        uint256 amount,
        string memory alertType,
        string memory description
    ) external returns (bytes32 alertId);
    
    function getRiskScore(address participant) external view returns (uint256 riskScore);
    
    function updateMonitoringRules(string memory ruleSet) external returns (bool updated);
}