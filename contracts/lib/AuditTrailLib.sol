// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library AuditTrailLib {
    struct AuditEntry {
        bytes32 entryId;
        address actor;
        string action;
        bytes32 target;
        uint256 timestamp;
        string details;
        bytes32 previousState;
        bytes32 newState;
    }
    
    function createAuditEntry(
        address actor,
        string memory action,
        bytes32 target,
        string memory details,
        bytes32 previousState,
        bytes32 newState
    ) internal view returns (AuditEntry memory) {
        return AuditEntry({
            entryId: keccak256(abi.encodePacked(actor, action, block.timestamp)),
            actor: actor,
            action: action,
            target: target,
            timestamp: block.timestamp,
            details: details,
            previousState: previousState,
            newState: newState
        });
    }
    
    function validateAuditAction(string memory action) internal pure returns (bool) {
        bytes memory actionBytes = bytes(action);
        return actionBytes.length > 0 && actionBytes.length <= 100;
    }
}