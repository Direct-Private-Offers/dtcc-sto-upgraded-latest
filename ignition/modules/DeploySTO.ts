import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Converts a string to a bytes32 hex string (right‑padded with zeros).
 */
function stringToBytes32(text: string): `0x${string}` {
  const encoder = new TextEncoder();
  const bytes = encoder.encode(text);
  if (bytes.length > 32) throw new Error("String too long for bytes32");
  const hex = Buffer.from(bytes).toString("hex").padEnd(64, "0");
  return `0x${hex}`;
}

const STOModule = buildModule("STOModule", (m) => {
  console.log({m})
  // ===== PARAMETERS =====
  const leiRegistryAddress = m.getParameter(
    "leiRegistryAddress",
    "0x0000000000000000000000000000000000000000"
  );
  
  const upiProviderAddress = m.getParameter(
    "upiProviderAddress",
    "0x0000000000000000000000000000000000000000"
  );
  
  const tradeRepositoryAddress = m.getParameter(
    "tradeRepositoryAddress",
    "0x0000000000000000000000000000000000000000"
  );

  // Network-specific price feed
  const priceFeed = m.getParameter(
    "priceFeed",
    "0x694AA1769357215DE4FAC081bf1f309aDC325306"
  );

  // Token parameters
  const tokenName = m.getParameter("tokenName", "DTCC Security Token");
  const tokenSymbol = m.getParameter("tokenSymbol", "DTCC");
  const granularity = m.getParameter("granularity", 1);
  
  // ISIN for whitelist
  const isin = m.getParameter("isin", "US1234567890");

  // ===== DEPLOY LIBRARIES =====
  const complianceLib = m.contract("ComplianceLib", [], {
    id: "ComplianceLib",
  });
  console.log({complianceLib})

  const csaDerivativesLib = m.contract("CSADerivativesLib", [], {
    id: "CSADerivativesLib",
  });

  const clearstreamLib = m.contract("ClearstreamLib", [], {
    id: "ClearstreamLib",
  });

  const dateTimeLib = m.contract("DateTimeLib", [], {
    id: "DateTimeLib",
  });

  // ===== DEPLOY MODULES WITH LIBRARIES =====
  const tokenCore = m.contract(
    "TokenCore",
    [tokenName, tokenSymbol, granularity],
    {
      id: "TokenCore",
      libraries: {
        ComplianceLib: complianceLib,
        CSADerivativesLib: csaDerivativesLib,
        ClearstreamLib: clearstreamLib,
        DateTimeLib: dateTimeLib,
      },
    }
  );

  const complianceManager = m.contract(
    "ComplianceManager",
    [leiRegistryAddress],
    {
      id: "ComplianceManager",
      libraries: {
        ComplianceLib: complianceLib,
        CSADerivativesLib: csaDerivativesLib,
        ClearstreamLib: clearstreamLib,
        DateTimeLib: dateTimeLib,
      },
    }
  );

  const derivativesManager = m.contract(
    "CSADerivativesManager",
    [tradeRepositoryAddress, upiProviderAddress],
    {
      id: "CSADerivativesManager",
      libraries: {
        ComplianceLib: complianceLib,
        CSADerivativesLib: csaDerivativesLib,
        ClearstreamLib: clearstreamLib,
        DateTimeLib: dateTimeLib,
      },
    }
  );

  const clearstreamManager = m.contract(
    "ClearstreamManager",
    [],
    {
      id: "ClearstreamManager",
      libraries: {
        ComplianceLib: complianceLib,
        CSADerivativesLib: csaDerivativesLib,
        ClearstreamLib: clearstreamLib,
        DateTimeLib: dateTimeLib,
      },
    }
  );

  // ===== DEPLOY MAIN ORCHESTRATOR =====
  const mainContract = m.contract(
    "DTCCCompliantSTO",
    [
      tokenCore,
      complianceManager,
      derivativesManager,
      clearstreamManager,
      priceFeed,
    ],
    {
      id: "DTCCCompliantSTO",
      libraries: {
        ComplianceLib: complianceLib,
        CSADerivativesLib: csaDerivativesLib,
        ClearstreamLib: clearstreamLib,
        DateTimeLib: dateTimeLib,
      },
    }
  );

  // ===== CONFIGURE ROLES AND INITIALIZE =====
  // Note: For role grants, you'll need to do these after deployment
  // either manually or through a separate script
  // Ignition doesn't support dynamic role hashing well

  return {
    complianceLib,
    csaDerivativesLib,
    clearstreamLib,
    dateTimeLib,
    tokenCore,
    complianceManager,
    derivativesManager,
    clearstreamManager,
    mainContract,
  };
});

export default STOModule;
