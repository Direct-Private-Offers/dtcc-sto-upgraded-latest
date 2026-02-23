// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/ICLEARSTREAMIntegration.sol";

interface IClearstreamManager {
    function initiateSettlement(
        bytes32 tradeReference,
        address buyer,
        address seller,
        uint256 quantity,
        uint256 settlementAmount,
        uint256 valueDate
    ) external returns (bytes32 settlementId);
    
    function generateSettlementInstructions(bytes32 settlementId) external;
    function confirmSettlement(bytes32 settlementId, bytes32 instructionReference) external;
    function completeSettlement(bytes32 settlementId) external;
    
    function linkClearstreamAccount(address investor, bytes20 csdAccount) external;
    function getClearstreamPosition(bytes20 csdAccount) external view returns (ICLEARSTREAMIntegration.ClearstreamPosition memory);
    
    function updateClearstreamConfig(ICLEARSTREAMIntegration.ClearstreamConfig memory newConfig) external;
    function addISINToWhitelist(string memory isin) external;
    
    // Events
    event ClearstreamSettlementInitiated(bytes32 indexed settlementId, address buyer, address seller, uint256 quantity);
    event ClearstreamAccountLinked(address indexed investor, bytes20 csdAccount);
    event ClearstreamConfigUpdated(bytes20 newCsdAccount, uint256 settlementCycle);
    event ClearstreamInstructionsGenerated(bytes32 indexed settlementId, bytes32 deliveryId, bytes32 receiptId);
    event ClearstreamPositionUpdated(bytes20 indexed account, string isin, uint256 newPosition);
}
