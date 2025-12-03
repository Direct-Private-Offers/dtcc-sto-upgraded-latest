// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDPOGLOBALIntegration {
    // Events
    event CrossChainSwapInitiated(
        bytes32 indexed swapId,
        address indexed user,
        address sourceToken,
        address targetToken,
        uint256 sourceAmount,
        uint256 targetChain,
        uint256 timestamp
    );
    
    event CrossChainSwapCompleted(
        bytes32 indexed swapId,
        address indexed user,
        uint256 targetAmount,
        uint256 timestamp
    );
    
    event TokenInterlisted(string indexed isin, address indexed exchange, uint256 timestamp);

    // Functions
    function crossChainSwap(
        address _sourceToken,
        address _targetToken,
        uint256 _sourceAmount,
        uint256 _targetChain
    ) external returns (bytes32 swapId);
    
    function interlistToken(string calldata _isin, address _exchange) external;
}