// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenCore {
    // ERC20 Functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address owner, address spender, uint256 amount) external returns (bool);
    function transferFrom(address operator, address from, address to, uint256 amount) external returns (bool);
    
    // ERC1400 Partition Functions
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256);
    function partitionsOf(address tokenHolder) external view returns (bytes32[] memory);
    function totalSupplyByPartition(bytes32 partition) external view returns (uint256);
    function transferByPartition(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata operatorData
    ) external returns (bytes32);
    
    // Document Management
    function getDocument(bytes32 documentName) external view returns (string memory, bytes32, uint256);
    function setDocument(bytes32 documentName, string calldata uri, bytes32 documentHash) external;
    
    // Operator Management
    function isOperator(address operator, address tokenHolder) external view returns (bool);
    function authorizeOperator(address operator, address tokenHolder) external;
    function revokeOperator(address operator, address tokenHolder) external;
    
    // Mint/Burn
    function mint(address to, uint256 amount, bytes32 partition) external;
    function burn(address from, uint256 amount, bytes32 partition) external;
    
    // Default Partitions
    function getDefaultPartitions() external view returns (bytes32[] memory);
    function setDefaultPartitions(bytes32[] calldata partitions) external;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TransferByPartition(
        bytes32 indexed fromPartition, 
        address operator, 
        address indexed from, 
        address indexed to, 
        uint256 value, 
        bytes data, 
        bytes operatorData
    );
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 documentHash);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
    event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);
}
