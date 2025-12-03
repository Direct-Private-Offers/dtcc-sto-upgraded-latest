// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library MultiSigLib {
    
    function validateMultiSigRequest(
        address[] memory _signers,
        uint256 _requiredApprovals
    ) internal pure returns (bool) {
        return _signers.length > 0 && 
               _requiredApprovals > 0 && 
               _requiredApprovals <= _signers.length;
    }
    
    function hasRequiredApprovals(
        mapping(bytes32 => mapping(address => bool)) storage approvals,
        bytes32 _requestId,
        address[] memory _signers,
        uint256 _requiredApprovals
    ) internal view returns (bool) {
        uint256 approvalCount = 0;
        for (uint i = 0; i < _signers.length; i++) {
            if (approvals[_requestId][_signers[i]]) {
                approvalCount++;
            }
        }
        return approvalCount >= _requiredApprovals;
    }
    
    function generateRequestId(
        address _requester,
        uint256 _action,
        uint256 _timestamp,
        bytes memory _callData
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_requester, _action, _timestamp, _callData));
    }
}