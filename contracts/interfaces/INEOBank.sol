// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface INEOBank {
    function openAccount(address customer, uint256 initialDeposit, string memory currency) external returns (bool success);
    function processTransfer(address from, address to, uint256 amount, string memory currency) external returns (bool success);
    function getAccountBalance(address customer, string memory currency) external view returns (uint256 balance);
    function validateKYC(address customer, uint256 amount) external view returns (bool approved);
    function checkCompliance(address customer, uint256 amount, string memory targetCountry) external view returns (bool compliant);
}