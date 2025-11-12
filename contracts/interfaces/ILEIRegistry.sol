// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILEIRegistry {
    function isValidLEI(bytes20 lei) external view returns (bool);
    function getLEIForAddress(address addr) external view returns (bytes20);
    function registerLEI(bytes20 lei, address entity) external;
    function updateLEI(bytes20 oldLEI, bytes20 newLEI) external;
}