// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library ForexLib {
    // Sanctioned countries list
    bytes32 constant SANCTIONED_COUNTRIES = keccak256("SANCTIONED_JURISDICTIONS");
    
    /**
     * @dev Calculate spread percentage between two rates
     */
    function calculateSpread(uint256 rate1, uint256 rate2) internal pure returns (uint256 spreadPercentage) {
        if (rate1 == 0 || rate2 == 0) return type(uint256).max;
        
        uint256 difference = rate1 > rate2 ? rate1 - rate2 : rate2 - rate1;
        return (difference * 1e18) / ((rate1 + rate2) / 2);
    }
    
    /**
     * @dev Check if country is sanctioned
     */
    function isSanctionedCountry(string memory countryCode) internal pure returns (bool) {
        bytes32 countryHash = keccak256(abi.encodePacked(countryCode));
        
        // Simplified list - in production, use comprehensive OFAC list
        return (countryHash == keccak256(abi.encodePacked("IR")) || // Iran
                countryHash == keccak256(abi.encodePacked("KP")) || // North Korea
                countryHash == keccak256(abi.encodePacked("SY")) || // Syria
                countryHash == keccak256(abi.encodePacked("CU")));  // Cuba
    }
    
    /**
     * @dev Validate Forex rate against tolerance
     */
    function validateRateTolerance(
        uint256 marketRate,
        uint256 pspRate,
        uint256 maxTolerance
    ) internal pure returns (bool) {
        uint256 spread = calculateSpread(marketRate, pspRate);
        return spread <= maxTolerance;
    }
    
    /**
     * @dev Calculate settlement amount with fees
     */
    function calculateSettlementAmount(
        uint256 amount,
        uint256 exchangeRate,
        uint256 feePercentage
    ) internal pure returns (uint256 settlementAmount, uint256 feeAmount) {
        feeAmount = (amount * feePercentage) / 1e18;
        settlementAmount = (amount * exchangeRate) / 1e18 - feeAmount;
    }
    
    /**
     * @dev Generate region-specific fee multiplier
     */
    function getRegionFeeMultiplier(string memory region) internal pure returns (uint256) {
        bytes32 regionHash = keccak256(abi.encodePacked(region));
        
        if (regionHash == keccak256(abi.encodePacked("LATAM"))) {
            return 8 * 10**16; // 8% - Competitive LATAM pricing
        } else if (regionHash == keccak256(abi.encodePacked("CAN"))) {
            return 15 * 10**16; // 15% - Higher Canadian fees
        } else if (regionHash == keccak256(abi.encodePacked("US"))) {
            return 12 * 10**16; // 12% - US market
        } else if (regionHash == keccak256(abi.encodePacked("EU"))) {
            return 10 * 10**16; // 10% - European market
        } else {
            return 20 * 10**16; // 20% - Default higher fee
        }
    }
}