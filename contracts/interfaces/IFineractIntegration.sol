// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * @title FineractOracle
 * @dev Chainlink Oracle for Fineract API integration
 * This contract enables secure API calls to Fineract through Chainlink nodes
 */
contract FineractOracle is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;
    
    // Chainlink configuration
    bytes32 private jobId;
    uint256 private fee;
    
    // Fineract API configuration
    struct ApiConfig {
        string baseUrl;
        string tenantIdentifier;
        string apiKey;
        bool encrypted;
    }
    
    // Mappings for request tracking
    mapping(bytes32 => address) private requestToCallback;
    mapping(bytes32 => string) private requestToEndpoint;
    
    // Events
    event FineractApiRequest(bytes32 indexed requestId, string endpoint, address callback);
    event FineractApiResponse(bytes32 indexed requestId, bytes response);
    event FineractApiError(bytes32 indexed requestId, string error);
    
    /**
     * @dev Constructor
     * @param _linkToken LINK token address
     * @param _oracle Chainlink oracle address
     * @param _jobId Chainlink job ID for HTTP GET
     */
    constructor(
        address _linkToken,
        address _oracle,
        bytes32 _jobId
    ) ConfirmedOwner(msg.sender) {
        setChainlinkToken(_linkToken);
        setChainlinkOracle(_oracle);
        jobId = _jobId;
        fee = 0.1 * 10**18; // 0.1 LINK
    }
    
    /**
     * @dev Make Fineract API call through Chainlink
     * @param _endpoint Fineract API endpoint
     * @param _method HTTP method (GET, POST, PUT, DELETE)
     * @param _data Request data for POST/PUT
     * @param _callback Callback contract address
     */
    function callFineractApi(
        string memory _endpoint,
        string memory _method,
        string memory _data,
        address _callback
    ) external onlyOwner returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );
        
        // Set Fineract API endpoint
        req.add("endpoint", _endpoint);
        req.add("method", _method);
        
        if (bytes(_data).length > 0) {
            req.add("data", _data);
        }
        
        // Add authentication headers
        req.add("headers", string(abi.encodePacked(
            '{"Fineract-Platform-TenantId":"default",',
            '"Content-Type":"application/json",',
            '"Authorization":"Basic "}'
        )));
        
        requestId = sendChainlinkRequest(req, fee);
        
        // Store request info
        requestToCallback[requestId] = _callback;
        requestToEndpoint[requestId] = _endpoint;
        
        emit FineractApiRequest(requestId, _endpoint, _callback);
        
        return requestId;
    }
    
    /**
     * @dev Chainlink callback function
     * @param _requestId Request ID
     * @param _response API response
     */
    function fulfill(
        bytes32 _requestId,
        bytes memory _response
    ) public recordChainlinkFulfillment(_requestId) {
        address callback = requestToCallback[_requestId];
        
        if (callback != address(0)) {
            // Call the callback contract
            (bool success, ) = callback.call(
                abi.encodeWithSignature(
                    "onFineractApiResponse(bytes32,bytes)",
                    _requestId,
                    _response
                )
            );
            
            if (!success) {
                emit FineractApiError(_requestId, "Callback failed");
            }
        }
        
        emit FineractApiResponse(_requestId, _response);
        
        // Clean up
        delete requestToCallback[_requestId];
        delete requestToEndpoint[_requestId];
    }
    
    /**
     * @dev Update Chainlink configuration
     * @param _oracle New oracle address
     * @param _jobId New job ID
     * @param _fee New fee amount
     */
    function updateChainlinkConfig(
        address _oracle,
        bytes32 _jobId,
        uint256 _fee
    ) external onlyOwner {
        setChainlinkOracle(_oracle);
        jobId = _jobId;
        fee = _fee;
    }
    
    /**
     * @dev Cancel pending request
     * @param _requestId Request ID to cancel
     * @param _payment Payment to oracle for cancellation
     * @param _callbackFunctionId Callback function ID
     * @param _expiration Expiration time
     */
    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) external onlyOwner {
        cancelChainlinkRequest(
            _requestId,
            _payment,
            _callbackFunctionId,
            _expiration
        );
        
        // Clean up
        delete requestToCallback[_requestId];
        delete requestToEndpoint[_requestId];
    }
    
    /**
     * @dev Get request info
     * @param _requestId Request ID
     */
    function getRequestInfo(bytes32 _requestId) external view returns (
        address callback,
        string memory endpoint
    ) {
        return (
            requestToCallback[_requestId],
            requestToEndpoint[_requestId]
        );
    }
}