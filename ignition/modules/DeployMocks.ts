import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DeployMocksModule = buildModule("DeployMocksModule", (m) => {
  const mockLEIRegistry = m.contract("MockLEIRegistry", []);
  const mockUPIProvider = m.contract("MockUPIProvider", []);
  const mockTradeRepository = m.contract("MockTradeRepository", []);

  return { mockLEIRegistry, mockUPIProvider, mockTradeRepository };
});

export default DeployMocksModule;