// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ITradeRepository.sol";

/**
 * @title MockTradeRepository
 * @dev Mock implementation of Trade Repository for testing
 */
contract MockTradeRepository is ITradeRepository {
    mapping(bytes32 => bool) private reportedTrades;
    mapping(bytes32 => uint256) private correctionCounts;
    mapping(bytes32 => string[]) private tradeErrors;
    mapping(bytes32 => uint8) private tradeStatuses;
    
    event TradeSubmitted(bytes32 uti, bytes32 priorUti, bytes12 upi);
    event TradeCorrected(bytes32 uti, bytes32 priorUti);
    event ErrorReported(bytes32 uti, string reason);
    
    /**
     * @dev Submit a trade to the repository
     */
    function submitTrade(
        bytes32 uti,
        bytes32 priorUti,
        bytes12 upi,
        bytes20,
        bytes20,
        uint256,
        uint256,
        uint256,
        uint256,
        string calldata
    ) external override {
        reportedTrades[uti] = true;
        tradeStatuses[uti] = 1; // Active
        emit TradeSubmitted(uti, priorUti, upi);
    }
    
    /**
     * @dev Correct a trade
     */
    function correctTrade(bytes32 uti, bytes32 priorUti) external override {
        correctionCounts[uti]++;
        emit TradeCorrected(uti, priorUti);
    }
    
    /**
     * @dev Report an error for a trade
     */
    function reportError(bytes32 uti, string calldata reason) external override {
        tradeErrors[uti].push(reason);
        emit ErrorReported(uti, reason);
    }
    
    /**
     * @dev Get trade status
     * @param uti Unique Trade Identifier
     * @return Status code (0 = not found, 1 = active, 2 = corrected, 3 = error)
     */
    function getTradeStatus(bytes32 uti) external view override returns (uint8) {
        return tradeStatuses[uti];
    }
    
    /**
     * @dev Check if a trade has been reported
     * @param uti Unique Trade Identifier
     * @return true if trade is reported
     */
    function isTradeReported(bytes32 uti) external view returns (bool) {
        return reportedTrades[uti];
    }
    
    /**
     * @dev Get correction count for a trade
     * @param uti Unique Trade Identifier
     * @return Number of corrections
     */
    function getCorrectionCount(bytes32 uti) external view returns (uint256) {
        return correctionCounts[uti];
    }
    
    /**
     * @dev Get error reports for a trade
     * @param uti Unique Trade Identifier
     * @return Array of error reasons
     */
    function getTradeErrors(bytes32 uti) external view returns (string[] memory) {
        return tradeErrors[uti];
    }
}