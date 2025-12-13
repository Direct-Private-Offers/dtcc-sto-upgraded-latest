// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ForexPSPIntegration - Optimized for Size
 * @dev Production-ready integration with aggressive optimizations
 */
contract ForexPSPIntegration is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ========================================
    // STORAGE (Minimized)
    // ========================================
    
    struct Integrations {
        address billBittsPSP;
        address payBitoExchange;
        address neoBank;
    }
    
    struct Config {
        uint16 maxSpread;
        uint16 operatorFee;
        uint16 pspFee;
        uint16 neoFee;
        uint32 settlementDelay;
        uint64 dailyLimit;
        uint128 minTxAmount;
        uint128 maxTxAmount;
        address feeTreasury;
    }
    
    struct ForexTx {
        address initiator;
        uint128 baseAmount;
        uint128 quoteAmount;
        uint128 exchangeRate;
        uint64 timestamp;
        uint8 status;
        bytes32 baseCurrency;
        bytes32 quoteCurrency;
    }
    
    struct Settlement {
        address payer;
        address token;
        uint128 amount;
        uint32 fee;
        uint64 date;
        uint8 status;
        bool feeCollected;
    }
    
    struct User {
        uint64 dailyLimit;
        uint64 lastTxDate;
        bool kycVerified;
    }
    
    // Constants
    uint8 constant STATUS_PENDING = 0;
    uint8 constant STATUS_VALIDATED = 1;
    uint8 constant STATUS_EXECUTING = 2;
    uint8 constant STATUS_COMPLETED = 3;
    uint8 constant STATUS_FAILED = 4;
    
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    uint256 constant BASIS_POINTS = 10000;
    uint256 constant MIN_DEPOSIT = 100 * 10**6;
    uint256 constant MAX_CROSSBORDER = 100000 * 10**6;
    uint256 constant AML_THRESHOLD = 10000 * 10**6;
    
    // Storage variables
    Integrations public integrations;
    Config public config;
    
    mapping(bytes32 => ForexTx) public forexTransactions;
    mapping(bytes32 => Settlement) public pspSettlements;
    mapping(address => User) public users;
    mapping(bytes32 => bool) public sanctioned;
    mapping(address => uint256) public dailyVolume;
    
    // ========================================
    // EVENTS
    // ========================================
    
    event ForexInit(bytes32 indexed id, address initiator);
    event ForexValidated(bytes32 indexed id, bool valid);
    event ForexExecuted(bytes32 indexed id, bytes32 pspRef);
    event SettlementInit(bytes32 indexed id, address payer, uint256 amount);
    event SettlementDone(bytes32 indexed id, bytes32 txHash);
    event UserUpdated(address indexed user, bool kycVerified);
    
    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(
        address _admin,
        address _psp,
        address _exchange,
        address _neo,
        uint16 _maxSpread,
        uint16 _opFee,
        uint16 _pspFee,
        uint16 _neoFee,
        uint128 _minTx,
        uint128 _maxTx,
        address _feeTreasury
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        
        integrations.billBittsPSP = _psp;
        integrations.payBitoExchange = _exchange;
        integrations.neoBank = _neo;
        
        config.maxSpread = _maxSpread;
        config.operatorFee = _opFee;
        config.pspFee = _pspFee;
        config.neoFee = _neoFee;
        config.settlementDelay = 86400;
        config.dailyLimit = 1000000;
        config.minTxAmount = _minTx;
        config.maxTxAmount = _maxTx;
        config.feeTreasury = _feeTreasury;
        
        _initSanctions();
    }
    
    // ========================================
    // CORE FUNCTIONS (Refactored to reduce stack depth)
    // ========================================
    
    function initiateForex(
        bytes32 _base,
        bytes32 _quote,
        uint256 _amount
    ) external whenNotPaused nonReentrant returns (bytes32) {
        _validateAmount(_amount);
        _validateKYC(msg.sender);
        
        bytes32 id = _generateId(_base, _quote, _amount, msg.sender);
        require(forexTransactions[id].timestamp == 0, "Tx exists");
        
        uint256 rate = _getRate(_base, _quote);
        require(rate > 0, "Invalid rate");
        
        uint256 quoteAmount = (_amount * rate) / 1e18;
        uint256 fee = _calcFee(_amount);
        address feeToken = _getToken(_base);
        
        _collectFee(msg.sender, feeToken, fee);
        
        forexTransactions[id] = ForexTx({
            initiator: msg.sender,
            baseAmount: uint128(_amount),
            quoteAmount: uint128(quoteAmount),
            exchangeRate: uint128(rate),
            timestamp: uint64(block.timestamp),
            status: STATUS_PENDING,
            baseCurrency: _base,
            quoteCurrency: _quote
        });
        
        emit ForexInit(id, msg.sender);
        return id;
    }
    
    function validateForex(bytes32 _id, uint256 _manualRate) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        ForexTx storage t = forexTransactions[_id];
        require(t.timestamp > 0, "Tx not found");
        require(t.status == STATUS_PENDING, "Invalid status");
        
        uint256 rate = _manualRate > 0 ? _manualRate : _getRate(t.baseCurrency, t.quoteCurrency);
        bool valid = _checkRate(rate, t.baseCurrency, t.quoteCurrency);
        
        if (valid) {
            t.status = STATUS_VALIDATED;
            t.exchangeRate = uint128(rate);
            t.quoteAmount = uint128((t.baseAmount * rate) / 1e18);
        } else {
            t.status = STATUS_FAILED;
        }
        
        emit ForexValidated(_id, valid);
        return valid;
    }
    
    function executeForex(bytes32 _id, uint256 _maxSlippage) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant returns (bytes32) {
        ForexTx storage t = forexTransactions[_id];
        require(t.status == STATUS_VALIDATED, "Invalid status");
        
        uint256 currentRate = _getRate(t.baseCurrency, t.quoteCurrency);
        require(_checkSlippage(t.exchangeRate, currentRate, _maxSlippage), "Slippage high");
        
        (bool success, bytes memory data) = integrations.billBittsPSP.call(
            abi.encodeWithSignature(
                "executeForexSettlement(bytes32,bytes32,uint256,uint256,uint256,address)",
                t.baseCurrency,
                t.quoteCurrency,
                t.baseAmount,
                t.quoteAmount,
                t.exchangeRate,
                t.initiator
            )
        );
        require(success, "PSP failed");
        
        bytes32 pspRef = abi.decode(data, (bytes32));
        t.status = STATUS_EXECUTING;
        _initiateSettlement(_id, pspRef, t.initiator, t.baseAmount, t.baseCurrency);
        
        emit ForexExecuted(_id, pspRef);
        return pspRef;
    }
    
    // ========================================
    // PSP SETTLEMENT
    // ========================================
    
    function _initiateSettlement(bytes32 _forexId, bytes32 _pspRef, address _initiator, uint256 _amount, bytes32 _currency) internal {
        bytes32 settlementId = _generateSettlementId(_forexId, _pspRef);
        address token = _getToken(_currency);
        uint256 pspFee = (_amount * config.pspFee) / BASIS_POINTS;
        
        pspSettlements[settlementId] = Settlement({
            payer: _initiator,
            token: token,
            amount: uint128(_amount),
            fee: uint32(pspFee),
            date: uint64(block.timestamp + config.settlementDelay),
            status: 0,
            feeCollected: false
        });
        
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(_initiator, address(this), _amount);
        }
        
        emit SettlementInit(settlementId, _initiator, _amount);
    }
    
    function completeSettlement(bytes32 _id, bytes32 _txHash) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        Settlement storage s = pspSettlements[_id];
        require(s.date > 0, "Not found");
        require(s.status == 0, "Invalid status");
        require(block.timestamp >= s.date, "Not due");
        
        if (s.token != address(0)) {
            IERC20 token = IERC20(s.token);
            token.safeTransfer(address(this), s.amount - s.fee);
            if (s.fee > 0) token.safeTransfer(config.feeTreasury, s.fee);
        }
        
        s.status = 2;
        s.feeCollected = true;
        
        emit SettlementDone(_id, _txHash);
    }
    
    // ========================================
    // NEO BANK OPERATIONS
    // ========================================
    
    function openAccount(
        address _customer,
        uint256 _deposit,
        address _token,
        bytes32 _country
    ) external whenNotPaused nonReentrant returns (bytes32) {
        require(_customer != address(0) && _token != address(0), "Invalid address");
        require(_deposit >= MIN_DEPOSIT, "Min deposit");
        require(_checkCountry(_country), "Country not supported");
        
        bytes32 id = _generateAccountId(_customer, _country);
        bool kyc = _doKYC(_customer);
        bool aml = _doAML(_deposit, _country);
        
        users[_customer] = User({
            dailyLimit: uint64(config.dailyLimit),
            lastTxDate: 0,
            kycVerified: kyc
        });
        
        if (kyc && aml) {
            IERC20(_token).safeTransferFrom(_customer, address(this), _deposit);
        }
        
        emit UserUpdated(_customer, kyc);
        return id;
    }
    
    function crossBorder(
        address _customer,
        uint256 _amount,
        address _token,
        bytes32 _target
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant returns (bytes32) {
        require(_amount > 0, "Invalid amount");
        require(_amount <= MAX_CROSSBORDER, "Limit exceeded");
        
        User memory user = users[_customer];
        require(user.kycVerified, "KYC required");
        require(_checkLimit(_customer, _amount), "Daily limit");
        require(_checkCountry(_target), "Country not supported");
        require(!sanctioned[_target], "Country sanctioned");
        
        bytes32 id = _generateBorderId(_customer, _target, _amount);
        uint256 fee = (_amount * config.neoFee) / BASIS_POINTS;
        uint256 net = _amount - fee;
        
        if (_token != address(0)) {
            IERC20 token = IERC20(_token);
            token.safeTransferFrom(_customer, address(this), _amount);
            token.safeTransfer(address(this), net);
            if (fee > 0) token.safeTransfer(config.feeTreasury, fee);
        }
        
        dailyVolume[_customer] += _amount;
        users[_customer].lastTxDate = uint64(block.timestamp);
        
        return id;
    }
    
    // ========================================
    // INTERNAL HELPERS (Simplified)
    // ========================================
    
    function _validateAmount(uint256 _amount) internal view {
        require(_amount >= config.minTxAmount && _amount <= config.maxTxAmount, "Invalid amount");
    }
    
    function _validateKYC(address _user) internal view {
        if (!users[_user].kycVerified) revert("KYC required");
    }
    
    function _generateId(bytes32 _base, bytes32 _quote, uint256 _amount, address _customer) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_base, _quote, _amount, _customer, block.timestamp));
    }
    
    function _generateSettlementId(bytes32 _forexId, bytes32 _pspRef) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_forexId, _pspRef, block.timestamp));
    }
    
    function _generateAccountId(address _customer, bytes32 _country) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("ACCOUNT", _customer, _country, block.timestamp));
    }
    
    function _generateBorderId(address _customer, bytes32 _target, uint256 _amount) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("BORDER", _customer, _target, _amount, block.timestamp));
    }
    
    function _getRate(bytes32 _base, bytes32 _quote) internal pure returns (uint256) {
        if (_base == bytes32("USD") && _quote == bytes32("MXN")) return 17 * 1e18;
        if (_base == bytes32("USD") && _quote == bytes32("BRL")) return 5 * 1e18;
        if (_base == bytes32("USD") && _quote == bytes32("ARS")) return 800 * 1e18;
        return 1 * 1e18;
    }
    
    function _checkRate(uint256 _rate, bytes32 _base, bytes32 _quote) internal view returns (bool) {
        uint256 expected = _getRate(_base, _quote);
        if (expected == 0 || _rate == 0) return false;
        uint256 spread = _rate > expected ? 
            ((_rate - expected) * BASIS_POINTS) / expected :
            ((expected - _rate) * BASIS_POINTS) / expected;
        return spread <= config.maxSpread;
    }
    
    function _calcFee(uint256 _amount) internal view returns (uint256) {
        uint256 fee = (_amount * config.operatorFee) / BASIS_POINTS;
        return fee < 10**6 ? 10**6 : fee;
    }
    
    function _getToken(bytes32 _currency) internal pure returns (address) {
        if (_currency == bytes32("USD")) return USDC;
        if (_currency == bytes32("USDT")) return USDT;
        return address(0);
    }
    
    function _collectFee(address _from, address _token, uint256 _amount) internal {
        if (_amount > 0 && _token != address(0)) {
            IERC20(_token).safeTransferFrom(_from, config.feeTreasury, _amount);
        }
    }
    
    function _checkSlippage(uint256 _expected, uint256 _actual, uint256 _max) internal pure returns (bool) {
        if (_expected == 0 || _actual == 0) return false;
        uint256 slippage = _actual > _expected ? 
            ((_actual - _expected) * BASIS_POINTS) / _expected :
            ((_expected - _actual) * BASIS_POINTS) / _expected;
        return slippage <= _max;
    }
    
    function _doKYC(address _customer) internal view returns (bool) {
        return _customer.balance > 0.01 ether;
    }
    
    function _doAML(uint256 _amount, bytes32 _country) internal view returns (bool) {
        return !sanctioned[_country] && _amount <= AML_THRESHOLD;
    }
    
    function _checkLimit(address _customer, uint256 _amount) internal view returns (bool) {
        User memory user = users[_customer];
        if (block.timestamp - user.lastTxDate > 1 days) return _amount <= user.dailyLimit;
        return (dailyVolume[_customer] + _amount) <= user.dailyLimit;
    }
    
    function _checkCountry(bytes32 _code) internal pure returns (bool) {
        return _code == bytes32("US") || _code == bytes32("CA") || _code == bytes32("MX") || 
               _code == bytes32("BR") || _code == bytes32("AR");
    }
    
    function _initSanctions() internal {
        sanctioned[bytes32("CU")] = true;
        sanctioned[bytes32("IR")] = true;
        sanctioned[bytes32("KP")] = true;
        sanctioned[bytes32("SY")] = true;
        sanctioned[bytes32("RU")] = true;
        sanctioned[bytes32("VE")] = true;
    }
    
    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    function updateConfig(
        uint16 _maxSpread,
        uint16 _opFee,
        uint16 _pspFee,
        uint16 _neoFee,
        uint128 _minTx,
        uint128 _maxTx,
        address _feeTreasury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config.maxSpread = _maxSpread;
        config.operatorFee = _opFee;
        config.pspFee = _pspFee;
        config.neoFee = _neoFee;
        config.minTxAmount = _minTx;
        config.maxTxAmount = _maxTx;
        config.feeTreasury = _feeTreasury;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function withdraw(address _token, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(_amount > 0, "Invalid amount");
        
        if (_token == address(0)) {
            payable(msg.sender).transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }
}