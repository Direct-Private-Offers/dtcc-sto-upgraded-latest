// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFineractCallback {
    /**
     * @dev Callback for Fineract API responses
     * @param _requestId Request ID
     * @param _response API response data
     */
    function onFineractApiResponse(
        bytes32 _requestId,
        bytes memory _response
    ) external;
    
    /**
     * @dev Callback for Fineract API errors
     * @param _requestId Request ID
     * @param _error Error message
     */
    function onFineractApiError(
        bytes32 _requestId,
        string memory _error
    ) external;
}