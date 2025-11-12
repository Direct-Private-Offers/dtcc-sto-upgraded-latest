// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ICSADerivatives.sol";

interface IDTCCCompliantSTO is ICSADerivatives {
    
   // Add this function to the IDTCCCompliantSTO interface
function issueTokens(
    address _investor,
    uint256 _amount,
    string calldata _ipfsCID,
    uint256 _lockupPeriod,
    bytes20 _csdAccount
) external returns (bytes32 issuanceId);

    function verifyInvestor(
        address _investor,
        string calldata _kycProviderURL,
        bool _refreshIfVerified
    ) external returns (bytes32 requestId);

    function fulfillVerification(
        bytes32 _requestId,
        bool _isAccredited
    ) external;

    function setTransferLock(
        address _investor,
        uint256 _unlockTime
    ) external;

    function forceTransfer(
        address _from,
        address _to,
        uint256 _amount,
        string calldata _reason
    ) external;

    function setOfferingType(OfferingType _offeringType) external;

    function verifyQIB(address _investor, bool _isQIB) external;

    function isQIB(address _investor) external view returns (bool);

    function getNAV() external view returns (uint256);
}