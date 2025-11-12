// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUPIProvider {
    function isValidUPI(bytes12 upi) external view returns (bool);
    function generateUPI(string memory productType) external view returns (bytes12);
    function registerUPI(bytes12 upi, string memory metadata) external;
}