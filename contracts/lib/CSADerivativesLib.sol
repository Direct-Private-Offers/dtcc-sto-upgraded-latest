// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library CSADerivativesLib {
    
    function generateCSAUTI(
        bytes12 upi,
        uint256 executionTimestamp,
        address reporter,
        uint256 chainId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            upi,
            executionTimestamp,
            reporter,
            chainId
        ));
    }

    function isValidCSADate(uint256 date) internal pure returns (bool) {
        return date > 0 && date <= block.timestamp + 365 days;
    }

    function isValidExecutionTimestamp(uint256 timestamp) internal pure returns (bool) {
        return timestamp > 0 && timestamp <= block.timestamp;
    }

    function isValidCSANotionalAmount(uint256 amount) internal pure returns (bool) {
        return amount > 0;
    }

    function isValidCSACurrency(string memory currency) internal pure returns (bool) {
        bytes memory b = bytes(currency);
        return b.length == 3;
    }

    function validateCSACounterparty(
        bytes20 lei,
        address walletAddress,
        string memory jurisdiction
    ) internal pure returns (bool) {
        return lei != bytes20(0) && 
               walletAddress != address(0) && 
               bytes(jurisdiction).length >= 2;
    }

    function validateCollateralData(
        ICSADerivatives.CollateralData memory collateral
    ) internal pure returns (bool) {
        return collateral.valuationTimestamp > 0 && 
               bytes(collateral.collateralCurrency).length == 3 &&
               bytes(collateral.collateralType).length > 0;
    }

    function validateValuationData(
        ICSADerivatives.ValuationData memory valuation
    ) internal pure returns (bool) {
        return valuation.valuationTimestamp > 0 && 
               bytes(valuation.valuationCurrency).length == 3 &&
               bytes(valuation.valuationModel).length > 0;
    }

    function generateTestLEI() internal view returns (bytes20) {
        return bytes20(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
    }

    function generateTestUPI() internal view returns (bytes12) {
        return bytes12(keccak256(abi.encodePacked("UPI", block.timestamp)));
    }

    function generateTestUTI() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("UTI", block.timestamp, msg.sender));
    }
}