// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/ICSADerivatives.sol";

interface ICSADerivativesManager {
    function reportDerivative(
        ICSADerivatives.DerivativeData calldata derivativeData,
        ICSADerivatives.CounterpartyData calldata counterparty1,
        ICSADerivatives.CounterpartyData calldata counterparty2,
        ICSADerivatives.CollateralData calldata collateralData,
        ICSADerivatives.ValuationData calldata valuationData
    ) external returns (bytes32 uti);
    
    function correctDerivative(
        bytes32 uti,
        bytes32 priorUti,
        ICSADerivatives.DerivativeData calldata correctedData
    ) external;
    
    function reportError(
        bytes32 uti,
        string calldata reason
    ) external;
    
    function reportPosition(
        bytes32 positionId,
        bytes32[] calldata underlyingUtis,
        ICSADerivatives.ValuationData calldata valuationData
    ) external;
    
    function batchReportDerivatives(
        ICSADerivatives.DerivativeData[] calldata derivativesData,
        ICSADerivatives.CounterpartyData[] calldata counterparties1,
        ICSADerivatives.CounterpartyData[] calldata counterparties2,
        ICSADerivatives.CollateralData[] calldata collateralData,
        ICSADerivatives.ValuationData[] calldata valuationData
    ) external;
    
    // View Functions
    function getDerivative(bytes32 uti) external view returns (ICSADerivatives.DerivativeData memory);
    function getDerivativeCorrections(bytes32 uti) external view returns (bytes32[] memory);
    function getDerivativeErrors(bytes32 uti) external view returns (string[] memory);
    function getPosition(bytes32 positionId) external view returns (ICSADerivatives.ValuationData memory);
    
    // Events
    event DerivativeReported(bytes32 indexed uti, address indexed reporter, uint256 timestamp);
    event DerivativeCorrected(bytes32 indexed uti, bytes32 indexed priorUti, uint256 timestamp);
    event ErrorReported(bytes32 indexed uti, string reason, uint256 timestamp);
}
