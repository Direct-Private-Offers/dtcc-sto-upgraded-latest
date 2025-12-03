// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITravelRule {
    function reportTransfer(TravelRuleData memory _data) external;
    function verifyTransfer(bytes32 _transactionId) external returns (bool verified);
    function getVASPInfo(address _vasp) external returns (VASPInfo memory);
}

struct TravelRuleData {
    bytes32 transactionId;
    address originator;
    address beneficiary;
    uint256 amount;
    string originatorName;
    string originatorAddress;
    string originatorAccount;
    string beneficiaryName;
    string beneficiaryAddress;
    string beneficiaryAccount;
    bytes originatorVASP;
    bytes beneficiaryVASP;
    uint256 timestamp;
    bool ruleApplied;
}

struct VASPInfo {
    string name;
    string jurisdiction;
    bytes20 lei;
    string addressLine;
    bool registered;
    uint256 registrationDate;
}