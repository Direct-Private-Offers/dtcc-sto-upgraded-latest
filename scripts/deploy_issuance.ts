import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("🚀 Deploying FullIssuanceContract...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying from account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "ETH\n");

  // Configuration from environment variables
  const issuer = process.env.ISSUER_ADDRESS || deployer.address;
  const complianceOfficer = process.env.COMPLIANCE_OFFICER_ADDRESS || deployer.address;
  const settlementOperator = process.env.SETTLEMENT_OPERATOR_ADDRESS || deployer.address;

  console.log("👥 Role Addresses:");
  console.log("   Issuer:", issuer);
  console.log("   Compliance Officer:", complianceOfficer);
  console.log("   Settlement Operator:", settlementOperator);
  console.log("");

  // Identifiers configuration
  const identifiers = {
    isin: process.env.TEST_ISIN || "US0378331005",
    lei: process.env.TEST_LEI || "549300EXAMPLELEI001",
    upi: process.env.TEST_UPI || "UPISWAP00001",
    cusip: "037833100",
    clearstreamId: process.env.CLEARSTREAM_CSD_ID || "CLSTM12345",
    euroclearId: process.env.EUROCLEAR_CLIENT_ID || "EURCL98765",
    internalAssetId: "DPO-2025-001",
  };

  console.log("🏷️  Identifiers:");
  console.log("   ISIN:", identifiers.isin);
  console.log("   LEI:", identifiers.lei);
  console.log("   UPI:", identifiers.upi);
  console.log("   Internal Asset ID:", identifiers.internalAssetId);
  console.log("");

  // Offering configuration
  const now = Math.floor(Date.now() / 1000);
  const lockupPeriod = parseInt(process.env.LOCKUP_PERIOD || "7776000"); // 90 days default
  const maxRaiseAmount = process.env.MAX_RAISE_AMOUNT || "5000000";
  
  const offeringConfig = {
    offeringType: process.env.OFFERING_TYPE || "REG_D_506C",
    maxRaiseAmount: ethers.parseUnits(maxRaiseAmount, 18),
    lockupPeriod: lockupPeriod,
    startTimestamp: now,
    endTimestamp: now + 2592000, // 30 days from now
    baseCurrency: "USD",
  };

  console.log("📊 Offering Configuration:");
  console.log("   Type:", offeringConfig.offeringType);
  console.log("   Max Raise:", ethers.formatUnits(offeringConfig.maxRaiseAmount, 18), "tokens");
  console.log("   Lockup Period:", lockupPeriod / 86400, "days");
  console.log("   Start:", new Date(offeringConfig.startTimestamp * 1000).toISOString());
  console.log("   End:", new Date(offeringConfig.endTimestamp * 1000).toISOString());
  console.log("");

  // Document references (IPFS CIDs)
  const documents = {
    termSheetCid: "QmTermSheet123",
    offeringMemorandumCid: "QmMemorandum456",
    subscriptionAgreementCid: "QmSubscriptionAgreement789",
    kycPolicyCid: "QmKYCPolicy012",
  };

  console.log("📄 Document References:");
  console.log("   Term Sheet:", documents.termSheetCid);
  console.log("   Offering Memorandum:", documents.offeringMemorandumCid);
  console.log("");

  // Compliance module (use zero address for no external compliance module)
  const complianceModule = ethers.ZeroAddress;

  console.log("🔧 Deploying contract...");
  const FullIssuanceContract = await ethers.getContractFactory("FullIssuanceContract");
  
  const contract = await FullIssuanceContract.deploy(
    issuer,
    complianceOfficer,
    settlementOperator,
    identifiers,
    offeringConfig,
    documents,
    complianceModule
  );

  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();

  console.log("\n✅ FullIssuanceContract deployed successfully!");
  console.log("📍 Contract Address:", contractAddress);
  console.log("");

  // Save deployment info
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: (await ethers.provider.getNetwork()).chainId.toString(),
    contractAddress: contractAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    roles: {
      issuer,
      complianceOfficer,
      settlementOperator,
    },
    identifiers,
    offeringConfig: {
      ...offeringConfig,
      maxRaiseAmount: offeringConfig.maxRaiseAmount.toString(),
    },
  };

  console.log("💾 Deployment Summary:");
  console.log(JSON.stringify(deploymentInfo, null, 2));
  console.log("");

  // Verification info
  console.log("🔍 To verify on block explorer:");
  console.log(`npx hardhat verify --network <network> ${contractAddress} \\`);
  console.log(`  "${issuer}" \\`);
  console.log(`  "${complianceOfficer}" \\`);
  console.log(`  "${settlementOperator}" \\`);
  console.log(`  '${JSON.stringify(identifiers)}' \\`);
  console.log(`  '${JSON.stringify({...offeringConfig, maxRaiseAmount: offeringConfig.maxRaiseAmount.toString()})}' \\`);
  console.log(`  '${JSON.stringify(documents)}' \\`);
  console.log(`  "${complianceModule}"`);
  console.log("");

  console.log("✨ Deployment complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
