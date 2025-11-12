// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ILEIRegistry.sol";

/**
 * @title MockLEIRegistry
 * @dev Mock implementation of LEI Registry for testing
 */
contract MockLEIRegistry is ILEIRegistry {
    mapping(bytes20 => bool) private validLEIs;
    mapping(bytes20 => bool) private activeLEIs;
    mapping(address => bytes20) private addressToLEI;
    
    event LEIRegistered(bytes20 lei, bool isValid);
    event LEIStatusUpdated(bytes20 lei, bool isActive);
    
    /**
     * @dev Register a LEI for an entity
     * @param lei Legal Entity Identifier
     * @param entity Address of the entity
     */
    function registerLEI(bytes20 lei, address entity) external override {
        validLEIs[lei] = true;
        activeLEIs[lei] = true;
        if (entity != address(0)) {
            addressToLEI[entity] = lei;
        }
        emit LEIRegistered(lei, true);
    }
    
    /**
     * @dev Check if a LEI is valid
     * @param lei Legal Entity Identifier
     * @return true if LEI is valid
     */
    function isValidLEI(bytes20 lei) external view override returns (bool) {
        return validLEIs[lei];
    }
    
    /**
     * @dev Get LEI for an address
     * @param addr Address to lookup
     * @return LEI for the address (or zero if not found)
     */
    function getLEIForAddress(address addr) external view override returns (bytes20) {
        return addressToLEI[addr];
    }
    
    /**
     * @dev Update LEI (for testing)
     * @param oldLEI Old LEI
     * @param newLEI New LEI
     */
    function updateLEI(bytes20 oldLEI, bytes20 newLEI) external override {
        require(validLEIs[oldLEI], "LEI not registered");
        validLEIs[oldLEI] = false;
        validLEIs[newLEI] = true;
        activeLEIs[newLEI] = activeLEIs[oldLEI];
    }
    
    /**
     * @dev Check if LEI is active
     * @param lei Legal Entity Identifier
     * @return true if LEI is active
     */
    function isActiveLEI(bytes20 lei) external view returns (bool) {
        return activeLEIs[lei];
    }
    
    /**
     * @dev Update LEI status
     * @param lei Legal Entity Identifier
     * @param isActive Whether LEI is active
     */
    function updateLEIStatus(bytes20 lei, bool isActive) external {
        require(validLEIs[lei], "LEI not registered");
        activeLEIs[lei] = isActive;
        emit LEIStatusUpdated(lei, isActive);
    }
    
    /**
     * @dev Register LEI (backward compatible for tests)
     * @param lei Legal Entity Identifier
     * @param isActive Whether LEI is active
     */
    function registerLEI(bytes20 lei, bool isActive) external {
        validLEIs[lei] = true;
        activeLEIs[lei] = isActive;
        emit LEIRegistered(lei, true);
    }
    
    /**
     * @dev Register LEI for an address (helper for testing)
     * @param lei Legal Entity Identifier
     * @param entity Address of the entity
     * @param isActive Whether LEI is active
     */
    function registerLEI(bytes20 lei, address entity, bool isActive) external {
        validLEIs[lei] = true;
        activeLEIs[lei] = isActive;
        if (entity != address(0)) {
            addressToLEI[entity] = lei;
        }
        emit LEIRegistered(lei, true);
    }
    
    /**
     * @dev Helper function for testing
     * @return test LEI
     */
    function generateTestLEI() external view returns (bytes20) {
        return bytes20(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
    }
}