// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISanctionsScreening {
    function screenAddress(address _addr) external returns (bool isSanctioned);
    function screenTransaction(address _from, address _to, uint256 _amount) external returns (bool allowed);
    function batchScreen(address[] calldata _addresses) external returns (bool[] memory results);
}