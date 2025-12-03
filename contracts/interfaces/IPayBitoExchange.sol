// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPayBitoExchange {
    function getExchangeRate(
        string memory sourceAsset,
        string memory targetAsset,
        uint256 amount,
        string memory region
    ) external view returns (uint256 exchangeRate, uint256 fee);
    
    function executeExchange(
        address user,
        string memory sourceAsset,
        string memory targetAsset,
        uint256 sourceAmount,
        uint256 targetAmount,
        uint256 fee
    ) external returns (bool success);
    
    function getRegionFees(string memory region) external view returns (uint256 feePercentage);
}