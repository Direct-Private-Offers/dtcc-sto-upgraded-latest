// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ICSADerivatives.sol";

library ComplianceLib {
    
    function validateInvestorForOffering(
        mapping(address => ICSADerivatives.Investor) storage investors,
        uint256 nonAccreditedInvestorCount,
        ICSADerivatives.OfferingType offeringType,
        address investor,
        uint256 amount
    ) internal view {
        require(investor != address(0), "Invalid investor address");
        
        if (offeringType == ICSADerivatives.OfferingType.REG_D_506C) {
            require(investors[investor].isAccredited, "Reg D 506(c) requires accredited investors");
        }
        
        if (offeringType == ICSADerivatives.OfferingType.REG_CF) {
            require(amount <= 5_000_000 * 10**18, "Reg CF investment too large");
            // Additional Reg CF checks would go here
        }
        
        if (offeringType == ICSADerivatives.OfferingType.RULE_144A) {
            require(investors[investor].isQIB, "Rule 144A requires QIBs only");
        }
    }

    function validateRegCFTransfer(
        mapping(address => ICSADerivatives.Investor) storage investors,
        uint256 totalRaised,
        address to,
        uint256 amount
    ) internal view {
        // Reg CF specific transfer restrictions
        require(investors[to].isVerified, "Reg CF requires verified investors");
        // Additional transfer logic for Reg CF
    }

    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(abi.encodePacked(addr));
    }

    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[2 + i * 2 + 1] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}