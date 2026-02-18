import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("\n" + "=".repeat(70));
  console.log("🚀 DPOSVG SIMPLE DEPLOYMENT - Arbitrum Sepolia Testnet");
  console.log("=".repeat(70) + "\n");

  // === ENVIRONMENT CHECK ===
  
  const requiredEnvVars = [
    'ARBITRUM_SEPOLIA_RPC_URL',
    'DEPLOYER_PRIVATE_KEY',
    'GNOSIS_SAFE_ADDRESS'
  ];

  const missing = requiredEnvVars.filter(v => !process.env[v]);
  if (missing.length > 0) {
    console.error("❌ Missing environment variables:");
    missing.forEach(v => console.error(`   - ${v}`));
    console.error("\nPlease set these in your .env file\n");
    process.exit(1);
  }

  // === DEPLOYER INFO ===
  
  const [deployer] = await ethers.getSigners();
  console.log("📋 Deployment Configuration:");
  console.log(`   Deployer: ${deployer.address}`);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`   Balance: ${ethers.formatEther(balance)} ETH`);
  
  if (balance === 0n) {
    console.error("\n❌ Deployer has no ETH!");
    console.error("   Get testnet ETH from: https://faucet.quicknode.com/arbitrum/sepolia\n");
    process.exit(1);
  }

  const GNOSIS_SAFE_ADDRESS = process.env.GNOSIS_SAFE_ADDRESS!;
  console.log(`   Gnosis Safe: ${GNOSIS_SAFE_ADDRESS}\n`);

  // === TOKEN CONFIGURATION ===
  
  const TOKEN_NAME = "DPO Security Venture Group";
  const TOKEN_SYMBOL = "DPOSVG";
  const OFFERING_TYPE = 1; // REG_D_506C

  console.log("🏷️  Token Details:");
  console.log(`   Name: ${TOKEN_NAME}`);
  console.log(`   Symbol: ${TOKEN_SYMBOL}`);
  console.log(`   Offering: REG_D_506C (Self-Certification)\n`);

  // === CHAINLINK CONFIG (Mock for testnet) ===
  
  const CHAINLINK_PRICE_FEED = "0x0000000000000000000000000000000000000000";
  const CHAINLINK_ORACLE = "0x0000000000000000000000000000000000000000";
  const JOB_ID = ethers.encodeBytes32String("");
  const LINK_FEE = ethers.parseEther("0");

  const deploymentData: any = {
    network: "arbitrum-sepolia",
    chainId: 421614,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {}
  };

  // === STEP 1: DEPLOY MOCK LEI REGISTRY ===
  
  console.log("📝 Step 1/4: Deploying Mock LEI Registry...");
  const MockLEIRegistry = await ethers.getContractFactory("MockLEIRegistry");
  const leiRegistry = await MockLEIRegistry.deploy();
  await leiRegistry.waitForDeployment();
  const leiAddress = await leiRegistry.getAddress();
  
  console.log(`   ✅ LEI Registry: ${leiAddress}\n`);
  deploymentData.contracts.leiRegistry = leiAddress;

  // === STEP 2: DEPLOY MOCK UPI PROVIDER ===
  
  console.log("📝 Step 2/4: Deploying Mock UPI Provider...");
  const MockUPIProvider = await ethers.getContractFactory("MockUPIProvider");
  const upiProvider = await MockUPIProvider.deploy();
  await upiProvider.waitForDeployment();
  const upiAddress = await upiProvider.getAddress();
  
  console.log(`   ✅ UPI Provider: ${upiAddress}\n`);
  deploymentData.contracts.upiProvider = upiAddress;

  // === STEP 3: DEPLOY MOCK TRADE REPOSITORY ===
  
  console.log("📝 Step 3/4: Deploying Mock Trade Repository...");
  const MockTradeRepository = await ethers.getContractFactory("MockTradeRepository");
  const tradeRepository = await MockTradeRepository.deploy();
  await tradeRepository.waitForDeployment();
  const tradeRepoAddress = await tradeRepository.getAddress();
  
  console.log(`   ✅ Trade Repository: ${tradeRepoAddress}\n`);
  deploymentData.contracts.tradeRepository = tradeRepoAddress;

  // === STEP 4: DEPLOY MAIN TOKEN CONTRACT ===
  
  console.log("📝 Step 4/4: Deploying DTCCCompliantSTO (DPOSVG Token)...");
  const DTCCCompliantSTO = await ethers.getContractFactory("DTCCCompliantSTO");
  
  console.log("   ⏳ Estimating gas...");
  
  const sto = await DTCCCompliantSTO.deploy(
    TOKEN_NAME,
    TOKEN_SYMBOL,
    GNOSIS_SAFE_ADDRESS,
    CHAINLINK_PRICE_FEED,
    CHAINLINK_ORACLE,
    JOB_ID,
    LINK_FEE,
    leiAddress,
    upiAddress,
    tradeRepoAddress
  );
  
  await sto.waitForDeployment();
  const stoAddress = await sto.getAddress();
  
  console.log(`   ✅ DPOSVG Token: ${stoAddress}\n`);
  deploymentData.contracts.dposvgToken = stoAddress;

  // === CONFIGURE CONTRACT ===
  
  console.log("⚙️  Configuring Contract...\n");

  // Set offering type
  console.log("   📝 Setting offering type to REG_D_506C...");
  const setOfferingTx = await sto.setOfferingType(OFFERING_TYPE);
  await setOfferingTx.wait();
  console.log("   ✅ Offering type set\n");

  // Grant roles to Gnosis Safe
  console.log("   📝 Granting roles to Gnosis Safe...");
  
  const COMPLIANCE_OFFICER = await sto.COMPLIANCE_OFFICER();
  const ISSUER_ROLE = await sto.ISSUER_ROLE();
  const QIB_VERIFIER = await sto.QIB_VERIFIER();

  const tx1 = await sto.grantRole(COMPLIANCE_OFFICER, GNOSIS_SAFE_ADDRESS);
  await tx1.wait();
  console.log("   ✅ Compliance Officer role granted");

  const tx2 = await sto.grantRole(ISSUER_ROLE, GNOSIS_SAFE_ADDRESS);
  await tx2.wait();
  console.log("   ✅ Issuer role granted");

  const tx3 = await sto.grantRole(QIB_VERIFIER, GNOSIS_SAFE_ADDRESS);
  await tx3.wait();
  console.log("   ✅ QIB Verifier role granted\n");

  deploymentData.governance = {
    gnosisSafe: GNOSIS_SAFE_ADDRESS,
    roles: {
      complianceOfficer: COMPLIANCE_OFFICER,
      issuerRole: ISSUER_ROLE,
      qibVerifier: QIB_VERIFIER
    }
  };

  // === DEPLOYMENT SUMMARY ===
  
  console.log("=".repeat(70));
  console.log("🎉 DEPLOYMENT SUCCESSFUL!");
  console.log("=".repeat(70));
  console.log(`Token Name:          ${TOKEN_NAME}`);
  console.log(`Token Symbol:        ${TOKEN_SYMBOL}`);
  console.log(`Contract Address:    ${stoAddress}`);
  console.log(`Network:             Arbitrum Sepolia (Testnet)`);
  console.log(`Chain ID:            421614`);
  console.log("=".repeat(70));
  console.log("\n📋 Contract Addresses:");
  console.log(`   DPOSVG Token:        ${stoAddress}`);
  console.log(`   LEI Registry:        ${leiAddress}`);
  console.log(`   UPI Provider:        ${upiAddress}`);
  console.log(`   Trade Repository:    ${tradeRepoAddress}`);
  console.log(`   Gnosis Safe:         ${GNOSIS_SAFE_ADDRESS}`);
  
  console.log("\n🔗 View on Arbiscan:");
  console.log(`   https://sepolia.arbiscan.io/address/${stoAddress}`);

  console.log("\n✅ NEXT STEPS:");
  console.log("   1. Verify contract on Arbiscan");
  console.log("   2. Test investor whitelist");
  console.log("   3. Issue test tokens");
  console.log("   4. Update Master Notebook with contract address");
  console.log("   5. Test multi-sig governance via Gnosis Safe UI\n");

  // === SAVE DEPLOYMENT DATA ===
  
  const outputPath = path.join(__dirname, "..", "deployment-sepolia.json");
  fs.writeFileSync(outputPath, JSON.stringify(deploymentData, null, 2));
  console.log(`💾 Deployment info saved to: deployment-sepolia.json\n`);

  console.log("=".repeat(70) + "\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n" + "=".repeat(70));
    console.error("❌ DEPLOYMENT FAILED");
    console.error("=".repeat(70));
    console.error(error);
    console.error("=".repeat(70) + "\n");
    process.exit(1);
  });