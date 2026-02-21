// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ICSADerivatives.sol";

library CSADerivativesLib {
    
    // Generates a CSA UTI based on input parameters
    function generateCSAUTI(
        bytes12 upi,
        uint256 executionTimestamp,
        address reporter,
        uint256 chainId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(upi, executionTimestamp, reporter, chainId));
    }

    // Checks if a CSA effective date is valid (within 1 year from now)
    function isValidCSADate(uint256 date, uint256 currentTimestamp) internal pure returns (bool) {
        return date > 0 && date <= currentTimestamp + 365 days;
    }

    // Checks if execution timestamp is in the past (or now)
    function isValidExecutionTimestamp(uint256 timestamp, uint256 currentTimestamp) internal pure returns (bool) {
        return timestamp > 0 && timestamp <= currentTimestamp;
    }

    // Notional amount must be positive
    function isValidCSANotionalAmount(uint256 amount) internal pure returns (bool) {
        return amount > 0;
    }

    // Currency code must be exactly 3 characters
    function isValidCSACurrency(string memory currency) internal pure returns (bool) {
        return bytes(currency).length == 3;
    }

    // Counterparty validation
    function validateCSACounterparty(
        bytes20 lei,
        address walletAddress,
        string memory jurisdiction
    ) internal pure returns (bool) {
        return lei != bytes20(0) && walletAddress != address(0) && bytes(jurisdiction).length >= 2;
    }

    // Collateral validation
    function validateCollateralData(
        ICSADerivatives.CollateralData memory collateral
    ) internal pure returns (bool) {
        return collateral.valuationTimestamp > 0 &&
               bytes(collateral.collateralCurrency).length == 3 &&
               bytes(collateral.collateralType).length > 0;
    }

    // Valuation validation
    function validateValuationData(
        ICSADerivatives.ValuationData memory valuation
    ) internal pure returns (bool) {
        return valuation.valuationTimestamp > 0 &&
               bytes(valuation.valuationCurrency).length == 3 &&
               bytes(valuation.valuationModel).length > 0;
    }

    // Test functions – require block timestamp and msg.sender, so cannot be pure
    function generateTestLEI(address sender, uint256 currentTimestamp) internal pure returns (bytes20) {
        return bytes20(keccak256(abi.encodePacked(currentTimestamp, sender)));
    }

    function generateTestUPI(uint256 currentTimestamp) internal pure returns (bytes12) {
        return bytes12(keccak256(abi.encodePacked("UPI", currentTimestamp)));
    }

    function generateTestUTI(address sender, uint256 currentTimestamp) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("UTI", currentTimestamp, sender));
    }
}
