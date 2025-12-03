// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library FINTRACLib {
    // High-risk countries list (simplified)
    bytes32 constant HIGH_RISK_COUNTRIES = keccak256("HIGH_RISK_JURISDICTIONS");
    
    /**
     * @dev Calculate risk rating based on jurisdiction and PEP status
     */
    function calculateRiskRating(string memory _jurisdiction, bool _pep) internal pure returns (uint256) {
        uint256 baseRating = 1; // Low risk
        
        // Check if high-risk jurisdiction
        if (isHighRiskCountry(_jurisdiction)) {
            baseRating = 4; // High risk
        }
        
        // Increase risk if PEP
        if (_pep) {
            baseRating = baseRating < 4 ? 4 : baseRating; // Minimum high risk for PEPs
        }
        
        return baseRating;
    }
    
    /**
     * @dev Check if jurisdiction is high-risk
     */
    function isHighRiskCountry(string memory _jurisdiction) internal pure returns (bool) {
        bytes32 jurisdictionHash = keccak256(abi.encodePacked(_jurisdiction));
        
        // Simplified check - in production, this would be a comprehensive list
        return (jurisdictionHash == keccak256(abi.encodePacked("IR")) ||
                jurisdictionHash == keccak256(abi.encodePacked("KP")) ||
                jurisdictionHash == keccak256(abi.encodePacked("SY")) ||
                jurisdictionHash == keccak256(abi.encodePacked("CU")));
    }
    
    /**
     * @dev Validate transaction for FINTRAC compliance
     */
    function validateTransaction(
        address _from,
        address _to,
        uint256 _amount,
        string memory _fromJurisdiction,
        string memory _toJurisdiction
    ) internal pure returns (bool) {
        // Check if cross-border transaction to high-risk country
        if (keccak256(abi.encodePacked(_fromJurisdiction)) != keccak256(abi.encodePacked(_toJurisdiction))) {
            if (isHighRiskCountry(_toJurisdiction)) {
                return false; // Block transactions to high-risk countries
            }
        }
        
        return true;
    }
    
    /**
     * @dev Generate FINTRAC report ID
     */
    function generateReportId(
        address _client,
        uint256 _amount,
        uint256 _timestamp,
        string memory _reportType
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _client,
            _amount,
            _timestamp,
            _reportType
        ));
    }
}