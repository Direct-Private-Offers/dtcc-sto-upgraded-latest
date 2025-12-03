// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library FINTREXLib {
    
    function calculateRiskScore(
        uint256 _transactionVolume,
        uint256 _frequency,
        string memory _jurisdiction
    ) internal pure returns (bytes32 riskScore) {
        uint256 baseRisk = _transactionVolume * _frequency / 1e18;
        
        // Adjust for jurisdiction risk
        if (keccak256(abi.encodePacked(_jurisdiction)) == keccak256(abi.encodePacked("HIGH_RISK"))) {
            baseRisk = baseRisk * 150 / 100;
        }
        
        return keccak256(abi.encodePacked(baseRisk));
    }
    
    function shouldGenerateAlert(
        bytes32 _riskScore,
        uint256 _amount,
        string memory _pattern
    ) internal pure returns (bool) {
        // Simple alert logic - can be enhanced
        return _amount > 100000 * 10**18 || 
               keccak256(abi.encodePacked(_pattern)) == keccak256(abi.encodePacked("SUSPICIOUS"));
    }
    
    function validateFINTREXConfig(
        address _oracle,
        uint256 _fee
    ) internal pure returns (bool) {
        return _oracle != address(0) && _fee > 0;
    }
}