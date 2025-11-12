import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import DeploySTOModule from "./DeploySTO.js";

const SetupRolesModule = buildModule("SetupRolesModule", (m) => {
  const { dtccCompliantSTO } = m.useModule(DeploySTOModule);

  // Setup additional roles for testing
  const accounts = m.getAccount(1);
  const accounts2 = m.getAccount(2);
  const accounts3 = m.getAccount(3);

  m.call(dtccCompliantSTO, "grantRole", [
    m.staticCall(dtccCompliantSTO, "ISSUER_ROLE", []),
    accounts
  ]);

  m.call(dtccCompliantSTO, "grantRole", [
    m.staticCall(dtccCompliantSTO, "DERIVATIVES_REPORTER", []),
    accounts2
  ]);

  m.call(dtccCompliantSTO, "grantRole", [
    m.staticCall(dtccCompliantSTO, "COMPLIANCE_OFFICER", []),
    accounts3
  ]);

  return { dtccCompliantSTO };
});

export default SetupRolesModule;