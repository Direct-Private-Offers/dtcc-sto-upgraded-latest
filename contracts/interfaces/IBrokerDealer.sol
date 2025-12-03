// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBrokerDealer {
    function submitInvestment(
        address investor,
        uint256 amount,
        string memory currency,
        string memory investmentProduct
    ) external returns (bool success);
    
    function verifyFundsReceipt(
        address investor,
        uint256 amount
    ) external view returns (bool received);
    
    function getInvestorStatus(address investor) external view returns (string memory status);
    
    function processCommission(
        address broker,
        uint256 amount,
        string memory currency
    ) external returns (bool success);
}