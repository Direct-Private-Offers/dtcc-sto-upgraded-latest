import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "ethers";
import DeployMocksModule from "./DeployMocks.js";

const DeploySTOModule = buildModule("DeploySTOModule", (m) => {
  const { mockLEIRegistry, mockUPIProvider, mockTradeRepository } = m.useModule(DeployMocksModule);

  const dtccCompliantSTO = m.contract("DTCCCompliantSTO", [
    "CompliantSecurityToken",
    "CST",
    parseEther("1000000"),
    90 * 24 * 60 * 60, // 90 days lockup
    0, // REG_D_506B
    mockLEIRegistry,
    mockUPIProvider,
    mockTradeRepository
  ]);

  m.call(dtccCompliantSTO, "grantRole", [
    m.staticCall(dtccCompliantSTO, "ISSUER_ROLE", []),
    m.getAccount(0)
  ]);

  m.call(dtccCompliantSTO, "grantRole", [
    m.staticCall(dtccCompliantSTO, "COMPLIANCE_OFFICER", []),
    m.getAccount(0)
  ]);

  m.call(dtccCompliantSTO, "grantRole", [
    m.staticCall(dtccCompliantSTO, "DERIVATIVES_REPORTER", []),
    m.getAccount(0)
  ]);

  return { dtccCompliantSTO, mockLEIRegistry, mockUPIProvider, mockTradeRepository };
});

export default DeploySTOModule;