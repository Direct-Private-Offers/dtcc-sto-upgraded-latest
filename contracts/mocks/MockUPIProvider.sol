// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IUPIProvider.sol";

/**
 * @title MockUPIProvider
 * @dev Mock implementation of UPI Provider for testing
 */
contract MockUPIProvider is IUPIProvider {
    mapping(bytes12 => bool) private validUPIs;
    
    event UPIRegistered(bytes12 upi, bool isValid);
    
    /**
     * @dev Register a UPI with metadata
     * @param upi Universal Product Identifier
     * @param metadata Product metadata (ignored in mock)
     */
    function registerUPI(bytes12 upi, string memory) external override {
        validUPIs[upi] = true;
        emit UPIRegistered(upi, true);
    }
    
    /**
     * @dev Check if a UPI is valid
     * @param upi Universal Product Identifier
     * @return true if UPI is valid
     */
    function isValidUPI(bytes12 upi) external view override returns (bool) {
        return validUPIs[upi];
    }
    
    /**
     * @dev Generate a UPI for a product type
     * @param productType Product type string
     * @return Generated UPI
     */
    function generateUPI(string memory productType) external view override returns (bytes12) {
        return bytes12(keccak256(abi.encodePacked(productType, block.timestamp, msg.sender)));
    }
    
    /**
     * @dev Register a UPI (backward compatible for tests)
     * @param upi Universal Product Identifier
     */
    function registerUPI(bytes12 upi) external {
        validUPIs[upi] = true;
        emit UPIRegistered(upi, true);
    }
    
    /**
     * @dev Generate a test UPI (helper for testing)
     * @return Generated test UPI
     */
    function generateTestUPI() external view returns (bytes12) {
        return bytes12(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
    }
    
    /**
     * @dev Batch register multiple UPIs
     * @param upis Array of UPIs to register
     */
    function batchRegisterUPIs(bytes12[] calldata upis) external {
        for (uint i = 0; i < upis.length; i++) {
            validUPIs[upis[i]] = true;
        }
    }
}