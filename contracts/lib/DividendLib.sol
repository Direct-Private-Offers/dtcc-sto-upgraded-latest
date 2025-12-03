// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library DividendLib {
    /**
     * @dev Calculate dividend per share
     */
    function calculatePerShareAmount(
        uint256 _totalAmount,
        uint256 _totalSupply
    ) internal pure returns (uint256) {
        if (_totalSupply == 0) return 0;
        return _totalAmount / _totalSupply;
    }
    
    /**
     * @dev Calculate dividend entitlement for holder
     */
    function calculateDividendEntitlement(
        uint256 _holderBalance,
        uint256 _perShareAmount
    ) internal pure returns (uint256) {
        return _holderBalance * _perShareAmount;
    }
    
    /**
     * @dev Validate dividend cycle dates
     */
    function validateDividendDates(
        uint256 _recordDate,
        uint256 _paymentDate
    ) internal view returns (bool) {
        return (_recordDate > block.timestamp && 
                _paymentDate > _recordDate);
    }
    
    /**
     * @dev Check if holder is eligible for dividend
     */
    function isEligibleForDividend(
        uint256 _recordDate,
        uint256 _holderBalance
    ) internal view returns (bool) {
        return (block.timestamp >= _recordDate && _holderBalance > 0);
    }
}