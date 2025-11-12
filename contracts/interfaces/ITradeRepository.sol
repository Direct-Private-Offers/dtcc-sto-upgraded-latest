// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITradeRepository {
    function submitTrade(
        bytes32 uti,
        bytes32 priorUti,
        bytes12 upi,
        bytes20 lei1,
        bytes20 lei2,
        uint256 effectiveDate,
        uint256 expirationDate,
        uint256 executionTimestamp,
        uint256 notionalAmount,
        string calldata notionalCurrency
    ) external;

    function correctTrade(bytes32 uti, bytes32 priorUti) external;
    function reportError(bytes32 uti, string calldata reason) external;
    function getTradeStatus(bytes32 uti) external view returns (uint8 status);
}