// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IClearstreamManager.sol";
import "../interfaces/ICLEARSTREAMIntegration.sol";
import "../lib/ClearstreamLib.sol";

/**
 * @title ClearstreamManager
 * @dev Ultra-optimized to avoid stack too deep errors
 */
contract ClearstreamManager is AccessControl, IClearstreamManager {
    bytes32 public constant CLEARSTREAM_OPERATOR = keccak256("CLEARSTREAM_OPERATOR");
    
    // Clearstream PMI Integration
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamSettlement) public clearstreamSettlements;
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamInstruction[]) public settlementInstructions;
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamEvent[]) public settlementEvents;
    mapping(bytes32 => ICLEARSTREAMIntegration.ClearstreamPosition) public clearstreamPositions;
    mapping(address => bytes20) public participantAccounts;
    mapping(bytes32 => bool) public isinWhitelist;
    
    // Clearstream Configuration
    ICLEARSTREAMIntegration.ClearstreamConfig public clearstreamConfig;
    bytes12 public isinCode;
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CLEARSTREAM_OPERATOR, msg.sender);
    }
    
    function initiateSettlement(
        bytes32 tradeReference,
        address buyer,
        address seller,
        uint256 quantity,
        uint256 settlementAmount,
        uint256 valueDate
    ) external override onlyRole(CLEARSTREAM_OPERATOR) returns (bytes32 settlementId) {
        // Basic validation
        if (tradeReference == bytes32(0) || buyer == address(0) || seller == address(0) || 
            quantity == 0 || settlementAmount == 0 || valueDate <= block.timestamp) {
            revert("Invalid params");
        }
        
        settlementId = keccak256(abi.encodePacked(tradeReference, buyer, seller, quantity, block.timestamp));
        
        bytes20 buyerAccount = participantAccounts[buyer];
        bytes20 sellerAccount = participantAccounts[seller];
        
        if (buyerAccount == bytes20(0) || sellerAccount == bytes20(0)) {
            revert("No Clearstream account");
        }
        
        // Store settlement
        ICLEARSTREAMIntegration.ClearstreamSettlement storage s = clearstreamSettlements[settlementId];
        s.settlementId = settlementId;
        s.tradeReference = tradeReference;
        s.buyer = buyer;
        s.seller = seller;
        s.quantity = quantity;
        s.settlementAmount = settlementAmount;
        s.status = ICLEARSTREAMIntegration.ClearstreamSettlementStatus.PENDING;
        s.settlementDate = block.timestamp;
        s.valueDate = valueDate;
        s.buyerAccount = buyerAccount;
        s.sellerAccount = sellerAccount;
        s.isin = ClearstreamLib.bytes12ToString(isinCode);
        s.instructionReference = bytes32(0);
        
        emit ClearstreamSettlementInitiated(settlementId, buyer, seller, quantity);
        
        if (clearstreamConfig.autoSettlementEnabled) {
            this.generateSettlementInstructions(settlementId);
        }
        
        return settlementId;
    }
    
    function generateSettlementInstructions(bytes32 settlementId) external override onlyRole(CLEARSTREAM_OPERATOR) {
        ICLEARSTREAMIntegration.ClearstreamSettlement storage s = clearstreamSettlements[settlementId];
        if (s.settlementId == bytes32(0)) revert("Settlement not found");
        
        s.status = ICLEARSTREAMIntegration.ClearstreamSettlementStatus.INSTRUCTED;
        
        bytes32 deliveryId = keccak256(abi.encodePacked(settlementId, "DELIVERY"));
        bytes32 receiptId = keccak256(abi.encodePacked(settlementId, "RECEIPT"));
        
        // Add delivery instruction
        settlementInstructions[settlementId].push();
        ICLEARSTREAMIntegration.ClearstreamInstruction storage di = settlementInstructions[settlementId][settlementInstructions[settlementId].length - 1];
        di.instructionId = deliveryId;
        di.instructionType = ICLEARSTREAMIntegration.ClearstreamInstructionType.DELIVERY;
        di.settlementId = settlementId;
        di.participant = s.seller;
        di.participantAccount = s.sellerAccount;
        di.quantity = s.quantity;
        di.amount = s.settlementAmount;
        di.status = ICLEARSTREAMIntegration.ClearstreamInstructionStatus.SENT_TO_CSD;
        di.instructionDate = block.timestamp;
        di.valueDate = s.valueDate;
        di.isin = s.isin;
        di.tradeReference = s.tradeReference;
        
        // Add receipt instruction
        settlementInstructions[settlementId].push();
        ICLEARSTREAMIntegration.ClearstreamInstruction storage ri = settlementInstructions[settlementId][settlementInstructions[settlementId].length - 1];
        ri.instructionId = receiptId;
        ri.instructionType = ICLEARSTREAMIntegration.ClearstreamInstructionType.RECEIPT;
        ri.settlementId = settlementId;
        ri.participant = s.buyer;
        ri.participantAccount = s.buyerAccount;
        ri.quantity = s.quantity;
        ri.amount = s.settlementAmount;
        ri.status = ICLEARSTREAMIntegration.ClearstreamInstructionStatus.SENT_TO_CSD;
        ri.instructionDate = block.timestamp;
        ri.valueDate = s.valueDate;
        ri.isin = s.isin;
        ri.tradeReference = s.tradeReference;
        
        // Add event
        settlementEvents[settlementId].push();
        ICLEARSTREAMIntegration.ClearstreamEvent storage ev = settlementEvents[settlementId][settlementEvents[settlementId].length - 1];
        ev.eventId = keccak256(abi.encodePacked(settlementId, block.timestamp, "INSTRUCTED"));
        ev.eventType = ICLEARSTREAMIntegration.ClearstreamEventType.INSTRUCTION_SENT;
        ev.settlementId = settlementId;
        ev.eventDescription = "Instructions sent";
        ev.eventTimestamp = block.timestamp;
        ev.triggeredBy = msg.sender;
        ev.referenceId = deliveryId;
        
        emit ClearstreamInstructionsGenerated(settlementId, deliveryId, receiptId);
    }
    
    function confirmSettlement(bytes32 settlementId, bytes32 instructionReference) external override onlyRole(CLEARSTREAM_OPERATOR) {
        ICLEARSTREAMIntegration.ClearstreamSettlement storage s = clearstreamSettlements[settlementId];
        if (s.settlementId == bytes32(0) || s.status != ICLEARSTREAMIntegration.ClearstreamSettlementStatus.INSTRUCTED) {
            revert("Invalid settlement status");
        }
        
        s.status = ICLEARSTREAMIntegration.ClearstreamSettlementStatus.CONFIRMED;
        s.instructionReference = instructionReference;
        
        _updatePosition(s.buyer, int256(s.quantity), true);
        _updatePosition(s.seller, -int256(s.quantity), false);
        
        // Add event
        settlementEvents[settlementId].push();
        ICLEARSTREAMIntegration.ClearstreamEvent storage ev = settlementEvents[settlementId][settlementEvents[settlementId].length - 1];
        ev.eventId = keccak256(abi.encodePacked(settlementId, block.timestamp, "CONFIRMED"));
        ev.eventType = ICLEARSTREAMIntegration.ClearstreamEventType.SETTLEMENT_CONFIRMED;
        ev.settlementId = settlementId;
        ev.eventDescription = "Settlement confirmed";
        ev.eventTimestamp = block.timestamp;
        ev.triggeredBy = msg.sender;
        ev.referenceId = instructionReference;
    }
    
    function completeSettlement(bytes32 settlementId) external override onlyRole(CLEARSTREAM_OPERATOR) {
        ICLEARSTREAMIntegration.ClearstreamSettlement storage s = clearstreamSettlements[settlementId];
        if (s.settlementId == bytes32(0) || s.status != ICLEARSTREAMIntegration.ClearstreamSettlementStatus.CONFIRMED) {
            revert("Invalid settlement status");
        }
        
        s.status = ICLEARSTREAMIntegration.ClearstreamSettlementStatus.SETTLED;
        
        // Add event
        settlementEvents[settlementId].push();
        ICLEARSTREAMIntegration.ClearstreamEvent storage ev = settlementEvents[settlementId][settlementEvents[settlementId].length - 1];
        ev.eventId = keccak256(abi.encodePacked(settlementId, block.timestamp, "COMPLETED"));
        ev.eventType = ICLEARSTREAMIntegration.ClearstreamEventType.SETTLEMENT_COMPLETED;
        ev.settlementId = settlementId;
        ev.eventDescription = "Settlement completed";
        ev.eventTimestamp = block.timestamp;
        ev.triggeredBy = msg.sender;
        ev.referenceId = s.instructionReference;
    }
    
    function linkClearstreamAccount(address investor, bytes20 csdAccount) external override onlyRole(CLEARSTREAM_OPERATOR) {
        if (investor == address(0) || csdAccount == bytes20(0)) revert("Invalid input");
        
        participantAccounts[investor] = csdAccount;
        
        bytes32 positionKey = keccak256(abi.encodePacked(csdAccount, isinCode));
        ICLEARSTREAMIntegration.ClearstreamPosition storage position = clearstreamPositions[positionKey];
        
        if (position.participantAccount == bytes20(0)) {
            position.participantAccount = csdAccount;
            position.isin = ClearstreamLib.bytes12ToString(isinCode);
            position.position = 0;
            position.availableBalance = 0;
            position.blockedBalance = 0;
            position.lastUpdate = block.timestamp;
        }
        
        emit ClearstreamAccountLinked(investor, csdAccount);
    }
    
    function getClearstreamPosition(bytes20 csdAccount) external view override returns (ICLEARSTREAMIntegration.ClearstreamPosition memory) {
        bytes32 positionKey = keccak256(abi.encodePacked(csdAccount, isinCode));
        return clearstreamPositions[positionKey];
    }
    
    function updateClearstreamConfig(ICLEARSTREAMIntegration.ClearstreamConfig memory newConfig) external override onlyRole(CLEARSTREAM_OPERATOR) {
        if (newConfig.defaultCsdAccount == bytes20(0)) revert("Invalid CSD account");
        clearstreamConfig = newConfig;
        emit ClearstreamConfigUpdated(newConfig.defaultCsdAccount, newConfig.settlementCycle);
    }
    
    function addISINToWhitelist(string memory isin) external override onlyRole(CLEARSTREAM_OPERATOR) {
        if (bytes(isin).length == 0) revert("Invalid ISIN");
        isinWhitelist[keccak256(bytes(isin))] = true;
    }
    
    // Internal helper - kept minimal
    function _updatePosition(address participant, int256 delta, bool isAvailable) internal {
        bytes20 csdAccount = participantAccounts[participant];
        if (csdAccount == bytes20(0)) return;
        
        bytes32 key = keccak256(abi.encodePacked(csdAccount, isinCode));
        ICLEARSTREAMIntegration.ClearstreamPosition storage position = clearstreamPositions[key];
        
        if (position.participantAccount == bytes20(0)) {
            position.participantAccount = csdAccount;
            position.isin = ClearstreamLib.bytes12ToString(isinCode);
        }
        
        if (delta > 0) {
            if (isAvailable) position.availableBalance += uint256(delta);
            position.position += uint256(delta);
        } else if (delta < 0) {
            uint256 decrease = uint256(-delta);
            if (isAvailable) {
                if (position.availableBalance < decrease) revert("Insufficient available");
                position.availableBalance -= decrease;
            }
            if (position.position < decrease) revert("Insufficient position");
            position.position -= decrease;
        }
        
        position.lastUpdate = block.timestamp;
        emit ClearstreamPositionUpdated(csdAccount, position.isin, position.position);
    }
    
    // View Functions
    function getSettlement(bytes32 settlementId) external view returns (ICLEARSTREAMIntegration.ClearstreamSettlement memory) {
        return clearstreamSettlements[settlementId];
    }
    
    function getInstructions(bytes32 settlementId) external view returns (ICLEARSTREAMIntegration.ClearstreamInstruction[] memory) {
        return settlementInstructions[settlementId];
    }
    
    function getEvents(bytes32 settlementId) external view returns (ICLEARSTREAMIntegration.ClearstreamEvent[] memory) {
        return settlementEvents[settlementId];
    }
    
    // Admin Functions
    function setIsinCode(bytes12 newIsinCode) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isinCode = newIsinCode;
    }
}
