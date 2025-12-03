// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ICLEARSTREAMIntegration.sol";
import "./utils/Errors.sol";

/**
 * @title ClearstreamLib
 * @dev Library for Clearstream PMI (Post-Trade Management and Integration) operations
 * Provides utilities for settlement, corporate actions, and position management
 */
library ClearstreamLib {
    using Strings for uint256;
    
    // Clearstream constants
    bytes32 constant CLEARSTREAM_PARTICIPANT_PREFIX = keccak256("CLEARSTREAM_PARTICIPANT");
    bytes32 constant VALID_ISIN_CODES = keccak256("VALID_ISIN_LIST");
    
    /**
     * @dev Validate ISIN (International Securities Identification Number)
     */
    function validateISIN(string memory _isin) internal pure returns (bool) {
        bytes memory isinBytes = bytes(_isin);
        
        // ISIN must be 12 characters
        if (isinBytes.length != 12) return false;
        
        // First 2 characters must be letters (country code)
        if (!_isLetter(isinBytes[0]) || !_isLetter(isinBytes[1])) return false;
        
        // Next 9 characters must be alphanumeric
        for (uint256 i = 2; i < 11; i++) {
            if (!_isAlphanumeric(isinBytes[i])) return false;
        }
        
        // Last character must be a digit (check digit)
        if (!_isDigit(isinBytes[11])) return false;
        
        return true;
    }
    
    /**
     * @dev Generate participant account number
     */
    function generateParticipantAccount(
        address _participant,
        string memory _countryCode
    ) internal pure returns (bytes20) {
        return bytes20(keccak256(abi.encodePacked(
            CLEARSTREAM_PARTICIPANT_PREFIX,
            _participant,
            _countryCode,
            block.timestamp
        )));
    }
    
    /**
     * @dev Validate settlement instruction
     */
    function validateSettlementInstruction(
        ICLEARSTREAMIntegration.ClearstreamInstruction memory _instruction
    ) internal pure returns (bool, string memory) {
        if (_instruction.instructionId == bytes32(0)) {
            return (false, "Invalid instruction ID");
        }
        
        if (_instruction.settlementId == bytes32(0)) {
            return (false, "Invalid settlement ID");
        }
        
        if (_instruction.instructionDate == 0) {
            return (false, "Invalid instruction date");
        }
        
        if (_instruction.settlementDate == 0) {
            return (false, "Invalid settlement date");
        }
        
        if (_instruction.settlementDate < _instruction.instructionDate) {
            return (false, "Settlement date must be after instruction date");
        }
        
        if (_instruction.amount == 0) {
            return (false, "Invalid amount");
        }
        
        if (bytes(_instruction.isin).length == 0) {
            return (false, "ISIN required");
        }
        
        if (!validateISIN(_instruction.isin)) {
            return (false, "Invalid ISIN format");
        }
        
        if (_instruction.participantAccount == bytes20(0)) {
            return (false, "Invalid participant account");
        }
        
        if (_instruction.counterpartyAccount == bytes20(0)) {
            return (false, "Invalid counterparty account");
        }
        
        return (true, "");
    }
    
    /**
     * @dev Calculate settlement status based on dates and conditions
     */
    function calculateSettlementStatus(
        uint256 _settlementDate,
        uint256 _currentDate,
        ICLEARSTREAMIntegration.ClearstreamInstructionStatus _instructionStatus
    ) internal pure returns (ICLEARSTREAMIntegration.ClearstreamSettlementStatus) {
        if (_instructionStatus == ICLEARSTREAMIntegration.ClearstreamInstructionStatus.REJECTED) {
            return ICLEARSTREAMIntegration.ClearstreamSettlementStatus.CANCELLED;
        }
        
        if (_instructionStatus == ICLEARSTREAMIntegration.ClearstreamInstructionStatus.CANCELLED) {
            return ICLEARSTREAMIntegration.ClearstreamSettlementStatus.CANCELLED;
        }
        
        if (_instructionStatus == ICLEARSTREAMIntegration.ClearstreamInstructionStatus.EXECUTED) {
            return ICLEARSTREAMIntegration.ClearstreamSettlementStatus.SETTLED;
        }
        
        if (_instructionStatus == ICLEARSTREAMIntegration.ClearstreamInstructionStatus.CONFIRMED_BY_CSD) {
            return ICLEARSTREAMIntegration.ClearstreamSettlementStatus.CONFIRMED;
        }
        
        if (_instructionStatus == ICLEARSTREAMIntegration.ClearstreamInstructionStatus.SENT_TO_CSD) {
            return ICLEARSTREAMIntegration.ClearstreamSettlementStatus.INSTRUCTED;
        }
        
        if (_currentDate >= _settlementDate) {
            return ICLEARSTREAMIntegration.ClearstreamSettlementStatus.FAILED;
        }
        
        return ICLEARSTREAMIntegration.ClearstreamSettlementStatus.PENDING;
    }
    
    /**
     * @dev Generate settlement ID
     */
    function generateSettlementId(
        string memory _isin,
        uint256 _settlementDate,
        address _participant,
        address _counterparty
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "CLEARSTREAM_SETTLEMENT",
            _isin,
            _settlementDate,
            _participant,
            _counterparty,
            block.timestamp
        ));
    }
    
    /**
     * @dev Generate instruction ID
     */
    function generateInstructionId(
        bytes32 _settlementId,
        ICLEARSTREAMIntegration.ClearstreamInstructionType _instructionType
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _settlementId,
            uint256(_instructionType),
            block.timestamp
        ));
    }
    
    /**
     * @dev Calculate position after settlement
     */
    function calculatePositionUpdate(
        ICLEARSTREAMIntegration.ClearstreamPosition memory _currentPosition,
        ICLEARSTREAMIntegration.ClearstreamInstruction memory _instruction,
        bool _isDelivery
    ) internal pure returns (ICLEARSTREAMIntegration.ClearstreamPosition memory) {
        ICLEARSTREAMIntegration.ClearstreamPosition memory newPosition = _currentPosition;
        
        if (_isDelivery) {
            // Delivery: reduce position
            if (newPosition.quantity >= _instruction.amount) {
                newPosition.quantity -= _instruction.amount;
                newPosition.availableQuantity -= _instruction.amount;
            } else {
                // This should not happen if validation is correct
                newPosition.quantity = 0;
                newPosition.availableQuantity = 0;
            }
        } else {
            // Receipt: increase position
            newPosition.quantity += _instruction.amount;
            newPosition.availableQuantity += _instruction.amount;
        }
        
        newPosition.lastUpdated = block.timestamp;
        
        return newPosition;
    }
    
    /**
     * @dev Validate corporate action
     */
    function validateCorporateAction(
        ICLEARSTREAMIntegration.CorporateAction memory _action
    ) internal pure returns (bool, string memory) {
        if (_action.actionId == bytes32(0)) {
            return (false, "Invalid action ID");
        }
        
        if (bytes(_action.isin).length == 0) {
            return (false, "ISIN required");
        }
        
        if (!validateISIN(_action.isin)) {
            return (false, "Invalid ISIN format");
        }
        
        if (_action.recordDate == 0) {
            return (false, "Invalid record date");
        }
        
        if (_action.executionDate == 0) {
            return (false, "Invalid execution date");
        }
        
        if (_action.executionDate < _action.recordDate) {
            return (false, "Execution date must be after record date");
        }
        
        if (bytes(_action.details).length == 0) {
            return (false, "Details required");
        }
        
        if (_action.entitlementRatio == 0) {
            return (false, "Invalid entitlement ratio");
        }
        
        return (true, "");
    }
    
    /**
     * @dev Process corporate action on position
     */
    function processCorporateAction(
        ICLEARSTREAMIntegration.ClearstreamPosition memory _position,
        ICLEARSTREAMIntegration.CorporateAction memory _action
    ) internal pure returns (ICLEARSTREAMIntegration.ClearstreamPosition memory) {
        ICLEARSTREAMIntegration.ClearstreamPosition memory newPosition = _position;
        
        // Apply entitlement ratio
        if (_action.actionType == ICLEARSTREAMIntegration.CorporateActionType.STOCK_SPLIT ||
            _action.actionType == ICLEARSTREAMIntegration.CorporateActionType.RIGHTS_OFFERING) {
            // Increase position based on ratio
            uint256 newQuantity = _position.quantity * _action.entitlementRatio / 1e18;
            uint256 increase = newQuantity - _position.quantity;
            
            newPosition.quantity = newQuantity;
            newPosition.availableQuantity += increase;
        } else if (_action.actionType == ICLEARSTREAMIntegration.CorporateActionType.MERGER ||
                   _action.actionType == ICLEARSTREAMIntegration.CorporateActionType.ACQUISITION) {
            // Position may be converted to different ISIN
            // This is simplified - in reality, this would be more complex
            newPosition.isin = _action.details; // Using details field for new ISIN
        }
        
        newPosition.lastUpdated = block.timestamp;
        
        return newPosition;
    }
    
    /**
     * @dev Check if settlement can be cancelled
     */
    function canCancelSettlement(
        ICLEARSTREAMIntegration.ClearstreamSettlementStatus _status,
        uint256 _settlementDate,
        uint256 _currentDate
    ) internal pure returns (bool) {
        return (_status == ICLEARSTREAMIntegration.ClearstreamSettlementStatus.PENDING ||
                _status == ICLEARSTREAMIntegration.ClearstreamSettlementStatus.INSTRUCTED) &&
               _currentDate < _settlementDate;
    }
    
    /**
     * @dev Generate Clearstream event
     */
    function generateEvent(
        bytes32 _settlementId,
        ICLEARSTREAMIntegration.ClearstreamEventType _eventType,
        string memory _description,
        bytes memory _data
    ) internal view returns (ICLEARSTREAMIntegration.ClearstreamEvent memory) {
        return ICLEARSTREAMIntegration.ClearstreamEvent({
            eventId: keccak256(abi.encodePacked(
                _settlementId,
                uint256(_eventType),
                block.timestamp
            )),
            settlementId: _settlementId,
            eventType: _eventType,
            description: _description,
            eventData: _data,
            timestamp: block.timestamp,
            triggeredBy: msg.sender
        });
    }
    
    /**
     * @dev Format Clearstream message
     */
    function formatClearstreamMessage(
        string memory _messageType,
        bytes32 _referenceId,
        string memory _content
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"messageType":"',
            _messageType,
            '","referenceId":"',
            _toHexString(_referenceId),
            '","timestamp":"',
            block.timestamp.toString(),
            '","content":"',
            _content,
            '"}'
        ));
    }
    
    /**
     * @dev Check if date is a valid business day (simplified)
     */
    function isValidBusinessDay(uint256 _timestamp) internal pure returns (bool) {
        // Simplified check - in production, use a proper calendar
        uint256 dayOfWeek = (_timestamp / 86400 + 4) % 7; // 0 = Sunday
        
        // Exclude weekends (0 = Sunday, 6 = Saturday)
        return dayOfWeek != 0 && dayOfWeek != 6;
    }
    
    /**
     * @dev Calculate next business day
     */
    function nextBusinessDay(uint256 _timestamp) internal pure returns (uint256) {
        uint256 nextDay = _timestamp + 86400;
        
        while (!isValidBusinessDay(nextDay)) {
            nextDay += 86400;
        }
        
        return nextDay;
    }
    
    /**
     * @dev Validate participant account
     */
    function validateParticipantAccount(bytes20 _account) internal pure returns (bool) {
        // Check if account follows Clearstream format (starts with CS)
        bytes memory accountBytes = abi.encodePacked(_account);
        
        if (accountBytes.length < 2) return false;
        
        // Simplified check - first bytes should indicate Clearstream
        return accountBytes[0] == 0x43 && accountBytes[1] == 0x53; // "CS" in hex
    }
    
    // Helper functions
    function _isLetter(bytes1 _char) private pure returns (bool) {
        return (_char >= 0x41 && _char <= 0x5A) || // A-Z
               (_char >= 0x61 && _char <= 0x7A);   // a-z
    }
    
    function _isDigit(bytes1 _char) private pure returns (bool) {
        return _char >= 0x30 && _char <= 0x39; // 0-9
    }
    
    function _isAlphanumeric(bytes1 _char) private pure returns (bool) {
        return _isLetter(_char) || _isDigit(_char);
    }
    
    function _toHexString(bytes32 _bytes) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);
        
        for (uint256 i = 0; i < 32; i++) {
            str[i * 2] = alphabet[uint8(_bytes[i] >> 4)];
            str[i * 2 + 1] = alphabet[uint8(_bytes[i] & 0x0f)];
        }
        
        return string(str);
    }
    
    /**
     * @dev Check if instruction type matches settlement type
     */
    function isValidInstructionForSettlement(
        ICLEARSTREAMIntegration.ClearstreamInstructionType _instructionType,
        bool _isDelivery
    ) internal pure returns (bool) {
        if (_isDelivery) {
            return _instructionType == ICLEARSTREAMIntegration.ClearstreamInstructionType.DELIVERY ||
                   _instructionType == ICLEARSTREAMIntegration.ClearstreamInstructionType.PAYMENT;
        } else {
            return _instructionType == ICLEARSTREAMIntegration.ClearstreamInstructionType.RECEIPT ||
                   _instructionType == ICLEARSTREAMIntegration.ClearstreamInstructionType.RECEIVE_FUNDS;
        }
    }
    
    /**
     * @dev Calculate collateral requirements
     */
    function calculateCollateralRequirement(
        uint256 _positionValue,
        uint256 _haircutRate,
        uint256 _concentrationLimit
    ) internal pure returns (uint256 requiredCollateral) {
        // Basic collateral calculation
        requiredCollateral = (_positionValue * _haircutRate) / 1e18;
        
        // Apply concentration limits
        uint256 concentrationRequirement = (_positionValue * _concentrationLimit) / 1e18;
        
        if (concentrationRequirement > requiredCollateral) {
            requiredCollateral = concentrationRequirement;
        }
        
        return requiredCollateral;
    }
}