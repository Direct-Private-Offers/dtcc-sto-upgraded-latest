// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library TravelRuleLib {
    
    function validateTravelRuleData(
        address _originator,
        address _beneficiary,
        uint256 _amount
    ) internal pure returns (bool) {
        return _originator != address(0) && 
               _beneficiary != address(0) && 
               _amount > 0;
    }
    
    function shouldApplyTravelRule(
        address _originator,
        address _beneficiary,
        uint256 _amount,
        mapping(address => VASPInfo) storage vaspRegistry
    ) internal view returns (bool) {
        // Apply travel rule for cross-VASP transfers above threshold
        return (vaspRegistry[_originator].registered || vaspRegistry[_beneficiary].registered) &&
               _amount >= 1000 * 10**18; // $1000 threshold
    }
    
    function generateTransactionId(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_from, _to, _amount, _timestamp));
    }
}