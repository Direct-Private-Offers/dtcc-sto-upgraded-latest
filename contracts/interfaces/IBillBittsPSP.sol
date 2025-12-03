// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBillBittsPSP {
    function executeForexSettlement(
        string memory baseCurrency,
        string memory quoteCurrency,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 exchangeRate
    ) external returns (bytes32 pspReference);
    
    function processSettlement(
        address payer,
        address payee,
        uint256 amount,
        string memory currency
    ) external returns (bool success);
    
    function getPSPRate(
        string memory baseCurrency,
        string memory quoteCurrency
    ) external view returns (uint256 rate, uint256 fee);
}