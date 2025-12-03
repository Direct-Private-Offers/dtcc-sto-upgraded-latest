// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library PSPOrchestrationLib {
    function validateFlow(
        uint256 flowType,
        uint256 amount,
        string memory currency
    ) internal pure returns (bool) {
        // Flow type validation
        if (flowType > 6) { // Max flow type enum value
            return false;
        }
        
        // Amount validation
        if (amount == 0) {
            return false;
        }
        
        // Currency validation
        bytes memory currencyBytes = bytes(currency);
        if (currencyBytes.length == 0 || currencyBytes.length > 10) {
            return false;
        }
        
        return true;
    }
    
    function calculatePSPFee(
        uint256 amount,
        uint256 feePercentage
    ) internal pure returns (uint256) {
        return (amount * feePercentage) / 1e18;
    }
    
    function generateFlowReference(
        address customer,
        uint256 flowType,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(customer, flowType, timestamp));
    }
    
    function validateDailyLimit(
        uint256 currentDailyTotal,
        uint256 newAmount,
        uint256 maxDailyLimit
    ) internal pure returns (bool) {
        return (currentDailyTotal + newAmount) <= maxDailyLimit;
    }
}