// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ITokenCore.sol";

contract TokenCore is AccessControl, ITokenCore {
    bytes32 public constant TOKEN_OPERATOR = keccak256("TOKEN_OPERATOR");
    
    string private _name;
    string private _symbol;
    uint256 private _granularity;
    uint256 private _totalSupply;
    uint8 private constant _decimals = 18;
    
    // ERC20 mappings
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // ERC1400 Partition mappings
    mapping(bytes32 => uint256) private _totalSupplyByPartition;
    mapping(address => mapping(bytes32 => uint256)) private _balanceOfByPartition;
    mapping(address => bytes32[]) private _partitionsOf;
    bytes32[] private _totalPartitions;
    bytes32[] private _defaultPartitions;
    
    // Document management
    struct Doc {
        string docURI;
        bytes32 docHash;
        uint256 timestamp;
    }
    mapping(bytes32 => Doc) private _documents;
    bytes32[] private _documentNames;
    
    // Operator management
    mapping(address => mapping(address => bool)) private _authorizedOperators;
    
    // REMOVE THESE DUPLICATE EVENTS - they're in ITokenCore
    // event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    // event RevokedOperator(address indexed operator, address indexed tokenHolder);
    // event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    // event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    // event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
    // event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);
    
    // Modifier for operator authorization
    modifier onlyOperatorOrSelf(address tokenHolder) {
        require(
            msg.sender == tokenHolder || 
            _authorizedOperators[msg.sender][tokenHolder] ||
            hasRole(TOKEN_OPERATOR, msg.sender),
            "Not authorized"
        );
        _;
    }
    
    constructor(string memory name_, string memory symbol_, uint256 granularity_) {
        require(granularity_ >= 1, "Granularity must be >= 1");
        _name = name_;
        _symbol = symbol_;
        _granularity = granularity_;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TOKEN_OPERATOR, msg.sender);
    }
    
    // ERC20 Functions
    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function decimals() external pure returns (uint8) { return _decimals; }
    function totalSupply() external view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) external view returns (uint256) { return _balances[account]; }
    
    function transfer(address from, address to, uint256 amount) external onlyOperatorOrSelf(from) returns (bool) {
        _transfer(from, to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address owner, address spender, uint256 amount) external onlyOperatorOrSelf(owner) returns (bool) {
        require(spender != address(0), "Invalid spender");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }
    
    function transferFrom(address operator, address from, address to, uint256 amount) external returns (bool) {
        require(
            operator == from || 
            _authorizedOperators[operator][from] ||
            amount <= _allowances[from][operator] ||
            hasRole(TOKEN_OPERATOR, operator),
            "Insufficient allowance"
        );
        
        if (_allowances[from][operator] >= amount) {
            _allowances[from][operator] -= amount;
        }
        
        _transfer(from, to, amount);
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        require(_balances[from] >= amount, "Insufficient balance");
        require(amount % _granularity == 0, "Invalid granularity");
        
        _balances[from] -= amount;
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
    }
    
    // Mint/Burn functions (callable only by operators)
    function mint(address to, uint256 amount, bytes32 partition) external onlyRole(TOKEN_OPERATOR) {
        require(to != address(0), "Mint to zero");
        require(amount % _granularity == 0, "Invalid granularity");
        
        _totalSupply += amount;
        _balances[to] += amount;
        
        if (partition != bytes32(0)) {
            _addToPartition(to, partition, amount);
        }
        
        emit Transfer(address(0), to, amount);
        emit Issued(msg.sender, to, amount, "");
    }
    
    function burn(address from, uint256 amount, bytes32 partition) external onlyRole(TOKEN_OPERATOR) {
        require(from != address(0), "Burn from zero");
        require(_balances[from] >= amount, "Insufficient balance");
        
        _balances[from] -= amount;
        _totalSupply -= amount;
        
        if (partition != bytes32(0)) {
            _removeFromPartition(from, partition, amount);
        }
        
        emit Transfer(from, address(0), amount);
        emit Redeemed(msg.sender, from, amount, "");
    }
    
    // Partition functions
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256) {
        return _balanceOfByPartition[tokenHolder][partition];
    }
    
    function partitionsOf(address tokenHolder) external view returns (bytes32[] memory) {
        return _partitionsOf[tokenHolder];
    }
    
    function totalSupplyByPartition(bytes32 partition) external view returns (uint256) {
        return _totalSupplyByPartition[partition];
    }
    
    function transferByPartition(
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata operatorData
    ) external onlyOperatorOrSelf(from) returns (bytes32) {
        require(_balanceOfByPartition[from][partition] >= value, "Insufficient partition balance");
        
        _removeFromPartition(from, partition, value);
        _transfer(from, to, value);
        _addToPartition(to, partition, value);
        
        emit TransferByPartition(partition, operator, from, to, value, data, operatorData);
        
        return partition;
    }
    
    function _addToPartition(address to, bytes32 partition, uint256 value) internal {
        if (_balanceOfByPartition[to][partition] == 0) {
            _partitionsOf[to].push(partition);
        }
        _balanceOfByPartition[to][partition] += value;
        
        if (_totalSupplyByPartition[partition] == 0) {
            _totalPartitions.push(partition);
        }
        _totalSupplyByPartition[partition] += value;
    }
    
    function _removeFromPartition(address from, bytes32 partition, uint256 value) internal {
        _balanceOfByPartition[from][partition] -= value;
        _totalSupplyByPartition[partition] -= value;
        
        if (_balanceOfByPartition[from][partition] == 0) {
            _removePartitionFromUser(from, partition);
        }
        if (_totalSupplyByPartition[partition] == 0) {
            _removeTotalPartition(partition);
        }
    }
    
    function _removePartitionFromUser(address user, bytes32 partition) internal {
        bytes32[] storage userPartitions = _partitionsOf[user];
        for (uint i = 0; i < userPartitions.length; i++) {
            if (userPartitions[i] == partition) {
                userPartitions[i] = userPartitions[userPartitions.length - 1];
                userPartitions.pop();
                break;
            }
        }
    }
    
    function _removeTotalPartition(bytes32 partition) internal {
        for (uint i = 0; i < _totalPartitions.length; i++) {
            if (_totalPartitions[i] == partition) {
                _totalPartitions[i] = _totalPartitions[_totalPartitions.length - 1];
                _totalPartitions.pop();
                break;
            }
        }
    }
    
    // Operator management
    function isOperator(address operator, address tokenHolder) external view returns (bool) {
        return operator == tokenHolder || _authorizedOperators[operator][tokenHolder] || hasRole(TOKEN_OPERATOR, operator);
    }
    
    function authorizeOperator(address operator, address tokenHolder) external onlyOperatorOrSelf(tokenHolder) {
        require(operator != tokenHolder, "Cannot authorize self");
        _authorizedOperators[operator][tokenHolder] = true;
        emit AuthorizedOperator(operator, tokenHolder);
    }
    
    function revokeOperator(address operator, address tokenHolder) external onlyOperatorOrSelf(tokenHolder) {
        require(operator != tokenHolder, "Cannot revoke self");
        _authorizedOperators[operator][tokenHolder] = false;
        emit RevokedOperator(operator, tokenHolder);
    }
    
    // Document management
    function getDocument(bytes32 documentName) external view returns (string memory, bytes32, uint256) {
        require(bytes(_documents[documentName].docURI).length > 0, "Document does not exist");
        Doc memory doc = _documents[documentName];
        return (doc.docURI, doc.docHash, doc.timestamp);
    }
    
    function setDocument(bytes32 documentName, string calldata uri, bytes32 documentHash) external onlyRole(TOKEN_OPERATOR) {
        _documents[documentName] = Doc(uri, documentHash, block.timestamp);
        
        bool found = false;
        for (uint i = 0; i < _documentNames.length; i++) {
            if (_documentNames[i] == documentName) {
                found = true;
                break;
            }
        }
        if (!found) {
            _documentNames.push(documentName);
        }
        
        emit DocumentUpdated(documentName, uri, documentHash);
    }
    
    function getDefaultPartitions() external view returns (bytes32[] memory) {
        return _defaultPartitions;
    }
    
    function setDefaultPartitions(bytes32[] calldata partitions) external onlyRole(TOKEN_OPERATOR) {
        _defaultPartitions = partitions;
    }
}
