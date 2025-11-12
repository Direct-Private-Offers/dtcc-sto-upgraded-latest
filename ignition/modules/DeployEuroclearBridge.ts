import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DeployEuroclearBridgeModule = buildModule("DeployEuroclearBridgeModule", (m) => {
  const deployer = m.getAccount(0);
  
  // First deploy DTCCCompliantSTO
  const dtccSTO = m.contract("DTCCCompliantSTO", [
    "EuroclearTokenizedSecurities",
    "ETS",
    m.getParameter("initialSupply", 1000000000), // 1B tokens
    0, // No lockup
    0, // REG_D_506B
    m.getParameter("leiRegistry"), // Mock LEI registry
    m.getParameter("upiProvider"), // Mock UPI provider  
    m.getParameter("tradeRepository") // Mock trade repo
  ], {
    from: deployer
  });

  // Deploy Euroclear Bridge
  const euroclearBridge = m.contract("EuroclearBridge", [
    dtccSTO,
    m.getParameter("euroclearOracle") // Oracle address for Euroclear calls
  ], {
    from: deployer
  });

  // Setup roles
  const DEFAULT_ADMIN_ROLE = m.staticCall(euroclearBridge, "DEFAULT_ADMIN_ROLE", []);
  const ORACLE_ROLE = m.staticCall(euroclearBridge, "ORACLE_ROLE", []);
  const SETTLEMENT_ROLE = m.staticCall(euroclearBridge, "SETTLEMENT_ROLE", []);

  // Grant roles to deployer
  m.call(euroclearBridge, "grantRole", [DEFAULT_ADMIN_ROLE, deployer]);
  m.call(euroclearBridge, "grantRole", [ORACLE_ROLE, deployer]);
  m.call(euroclearBridge, "grantRole", [SETTLEMENT_ROLE, deployer]);

  return { dtccSTO, euroclearBridge };
});

export default DeployEuroclearBridgeModule;