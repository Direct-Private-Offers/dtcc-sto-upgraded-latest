// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IIssuanceContract {
    function recordCommitment(
        address investor,
        uint256 amount,
        string calldata currency,
        string calldata paymentRef
    ) external;

    function issueUnits(address investor, uint256 units) external;

    function recordSettlement(
        address investor,
        uint256 units,
        string calldata settlementSystem,
        string calldata externalRef
    ) external;
}
