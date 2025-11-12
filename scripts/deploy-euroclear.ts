import { ethers } from "hardhat";
import { EuroclearClient } from "../src/api/euroclear/client";
import { Logger } from "../src/utils/logging";

const logger = new Logger("deployment");

async function main() {
  console.log("🚀 Deploying Euroclear Integration...");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Deployer balance:", (await deployer.provider.getBalance(deployer.address)).toString());

  // Test Euroclear API connection first
  console.log("🔗 Testing Euroclear API connection...");
  const euroclearClient = new EuroclearClient();
  
  try {
    const isHealthy = await euroclearClient.healthCheck();
    if (!isHealthy) {
      throw new Error("Euroclear API is not accessible");
    }
    console.log("✅ Euroclear API connection successful");
  } catch (error) {
    console.error("❌ Euroclear API connection failed:", error);
    process.exit(1);
  }

  // Deploy mock registries first
  console.log("🏗️ Deploying mock registries...");
  
  const LEIRegistry = await ethers.getContractFactory("MockLEIRegistry");
  const leiRegistry = await LEIRegistry.deploy();
  await leiRegistry.waitForDeployment();
  console.log("✅ LEI Registry deployed to:", await leiRegistry.getAddress());

  const UPIProvider = await ethers.getContractFactory("MockUPIProvider");
  const upiProvider = await UPIProvider.deploy();
  await upiProvider.waitForDeployment();
  console.log("✅ UPI Provider deployed to:", await upiProvider.getAddress());

  const TradeRepository = await ethers.getContractFactory("MockTradeRepository");
  const tradeRepository = await TradeRepository.deploy();
  await tradeRepository.waitForDeployment();
  console.log("✅ Trade Repository deployed to:", await tradeRepository.getAddress());

  // Deploy DTCCCompliantSTO
  console.log("🏗️ Deploying DTCCCompliantSTO contract...");
  
  const DTCCCompliantSTO = await ethers.getContractFactory("DTCCCompliantSTO");
  const dtccSTO = await DTCCCompliantSTO.deploy(
    "Euroclear Tokenized Securities",
    "ETS",
    ethers.parseEther("1000000000"), // 1B tokens
    0, // No default lockup
    2, // REG_CF offering type
    await leiRegistry.getAddress(),
    await upiProvider.getAddress(),
    await tradeRepository.getAddress()
  );

  await dtccSTO.waitForDeployment();
  console.log("✅ DTCCCompliantSTO deployed to:", await dtccSTO.getAddress());

  // Deploy EuroclearBridge
  console.log("🏗️ Deploying EuroclearBridge contract...");
  
  const EuroclearBridge = await ethers.getContractFactory("EuroclearBridge");
  const euroclearBridge = await EuroclearBridge.deploy(
    await dtccSTO.getAddress(),
    deployer.address // Initial oracle
  );

  await euroclearBridge.waitForDeployment();
  console.log("✅ EuroclearBridge deployed to:", await euroclearBridge.getAddress());

  // Setup roles
  console.log("🔐 Setting up roles...");
  
  const DEFAULT_ADMIN_ROLE = await euroclearBridge.DEFAULT_ADMIN_ROLE();
  const ORACLE_ROLE = await euroclearBridge.ORACLE_ROLE();
  const SETTLEMENT_ROLE = await euroclearBridge.SETTLEMENT_ROLE();
  const DERIVATIVES_ROLE = await euroclearBridge.DERIVATIVES_ROLE();

  await euroclearBridge.grantRole(ORACLE_ROLE, deployer.address);
  await euroclearBridge.grantRole(SETTLEMENT_ROLE, deployer.address);
  await euroclearBridge.grantRole(DERIVATIVES_ROLE, deployer.address);

  console.log("✅ Roles granted to deployer");

  // Register sample securities
  console.log("📝 Registering securities...");
  
  const securities = [
    {
      isin: "US0378331005", // Apple ISIN
      description: "Apple Inc. Common Stock",
      currency: "USD",
      issueDate: Math.floor(Date.now() / 1000),
      maturityDate: 0,
      totalSupply: ethers.parseEther("1000000"),
      issuerName: "Apple Inc.",
      upi: "0x5550495f4150504c450000", // UPI_APPLE in bytes12
      issuerLEI: "0x3534393330304558414d504c454c4549" // 549300EXAMPLELEI in bytes20
    },
    {
      isin: "US5949181045", // Microsoft ISIN
      description: "Microsoft Corporation Common Stock",
      currency: "USD",
      issueDate: Math.floor(Date.now() / 1000),
      maturityDate: 0,
      totalSupply: ethers.parseEther("500000"),
      issuerName: "Microsoft Corporation",
      upi: "0x5550495f4d534654000000", // UPI_MSFT in bytes12
      issuerLEI: "0x3534393330304d5346544c4549303031" // 549300MSFTLEI001 in bytes20
    }
  ];

  for (const security of securities) {
    const tx = await euroclearBridge.registerSecurity({
      isin: ethers.encodeBytes32String(security.isin),
      description: security.description,
      currency: security.currency,
      issueDate: security.issueDate,
      maturityDate: security.maturityDate,
      totalSupply: security.totalSupply,
      issuerName: security.issuerName,
      upi: security.upi,
      issuerLEI: security.issuerLEI
    });
    await tx.wait();
    console.log(`✅ Registered security: ${security.isin}`);
  }

  // Verify contracts
  console.log("🔍 Verifying contracts...");
  
  if (process.env.ARBISCAN_API_KEY) {
    try {
      // Wait for blocks to be indexed
      await new Promise(resolve => setTimeout(resolve, 30000));
      
      console.log("📋 Contracts deployed successfully!");
      console.log("📊 Deployment Summary:");
      console.log("======================");
      console.log("LEI Registry:", await leiRegistry.getAddress());
      console.log("UPI Provider:", await upiProvider.getAddress());
      console.log("Trade Repository:", await tradeRepository.getAddress());
      console.log("DTCCCompliantSTO:", await dtccSTO.getAddress());
      console.log("EuroclearBridge:", await euroclearBridge.getAddress());
      console.log("======================");
      
      logger.info("Deployment completed successfully", {
        leiRegistry: await leiRegistry.getAddress(),
        upiProvider: await upiProvider.getAddress(),
        tradeRepository: await tradeRepository.getAddress(),
        dtccSTO: await dtccSTO.getAddress(),
        euroclearBridge: await euroclearBridge.getAddress()
      });

    } catch (error) {
      console.error("Verification failed:", error);
    }
  }

  console.log("🎉 Euroclear integration deployment completed!");
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  logger.error("Deployment failed", { error: error.message });
  process.exit(1);
});