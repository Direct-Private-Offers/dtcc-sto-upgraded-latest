// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library ClearstreamLib {

    struct SettlementData {
        address sender;
        address receiver;
        uint256 amount;
        bytes32 referenceId;
        uint256 timestamp;
    }

    /**
     * @dev Convert a string to bytes12 (padded/truncated as needed)
     * @param str The input string
     * @return bytes12 representation
     */
    function stringToBytes12(string memory str) internal pure returns (bytes12) {
        bytes memory strBytes = bytes(str);
        bytes12 result;
        
        // Copy up to 12 bytes
        for (uint i = 0; i < strBytes.length && i < 12; i++) {
            result |= bytes12(bytes1(strBytes[i]) << (8 * (11 - i)));
        }
        
        return result;
    }

    /**
     * @dev Convert bytes12 to string
     * @param input The bytes12 input
     * @return string representation
     */
    function bytes12ToString(bytes12 input) internal pure returns (string memory) {
        bytes memory result = new bytes(12);
        for (uint i = 0; i < 12; i++) {
            result[i] = bytes1(input << (8 * i) >> (8 * 11));
        }
        return string(result);
    }

    function validateSettlement(SettlementData memory data)
        internal
        pure
        returns (bool)
    {
        require(data.sender != address(0), "Invalid sender");
        require(data.receiver != address(0), "Invalid receiver");
        require(data.amount > 0, "Invalid amount");
        return true;
    }

    function generateReferenceId(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(sender, receiver, amount, nonce)
        );
    }
}
