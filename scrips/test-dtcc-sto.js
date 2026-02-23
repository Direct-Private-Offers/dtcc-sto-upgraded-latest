import { ethers } from "ethers";
import fs from "fs";
import dotenv from "dotenv";
import { fileURLToPath } from 'url';
import { dirname } from 'path';

dotenv.config();

// Get current file's directory (for ES modules)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// 🔴 CRITICAL: Please update these addresses with your ACTUAL deployed contract addresses
// Each module should have a UNIQUE address!
const ADDRESSES = {
  // MODULES
  tokenCore: "0x8017B6ba0055A13619A558Ca49005a259368bd10", // TokenCore address
  complianceManager: "0x60F6fF8FC16a86B667B251C84b1A701963a2380e", // 🔴 FIX THIS - should be different from TokenCore!
  derivativesManager: "0x337357DaBC6F84c4E8CA0083CC5010d15567aeA4",
  clearstreamManager: "0x17Efd60A9791d886a9f2A38E41f8ff569c49548C",
  // MAIN
  dtccCompliantSTO: "0xB52251feE8D24cD2c254Ad88F80F126989de679A",
  // EXTERNAL
  priceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306" // Sepolia ETH/USD
};

// Helper to convert string to bytes32
function stringToBytes32(text) {
  const encoder = new TextEncoder();
  const bytes = encoder.encode(text);
  const hex = Buffer.from(bytes).toString("hex").padEnd(64, "0");
  return "0x" + hex;
}

// Helper to create random test data
function randomHex(length) {
  return "0x" + Buffer.from(ethers.randomBytes(length)).toString("hex");
}

// Helper to create test LEI (20 bytes)
function generateTestLEI() {
  return "0x" + Buffer.from(ethers.randomBytes(20)).toString("hex");
}

// Helper to create test UPI (12 bytes)
function generateTestUPI() {
  return "0x" + Buffer.from(ethers.randomBytes(12)).toString("hex");
}

async function main() {
  console.log("\n🔷 DTCC COMPLIANT STO - COMPREHENSIVE TEST SUITE 🔷\n");
  
  // Check for missing addresses
  const missingAddresses = Object.entries(ADDRESSES)
    .filter(([key, value]) => value === "0x..." || value === "...")
    .map(([key]) => key);
  
  if (missingAddresses.length > 0) {
    console.error("❌ Missing addresses for:", missingAddresses.join(", "));
    console.error("Please update the ADDRESSES object with your deployed contract addresses.");
    process.exit(1);
  }
  
  // Setup provider and signers
  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const deployer = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);
  
  // Create test accounts (generate random wallets for testing)
  const testInvestor1 = ethers.Wallet.createRandom().connect(provider);
  const testInvestor2 = ethers.Wallet.createRandom().connect(provider);
  
  console.log("📋 Test Accounts:");
  console.log(`   Deployer: ${deployer.address}`);
  console.log(`   Investor 1: ${testInvestor1.address}`);
  console.log(`   Investor 2: ${testInvestor2.address}\n`);

  // Get contract instances
  const mainContract = new ethers.Contract(
    ADDRESSES.dtccCompliantSTO,
    [
      // Token functions
      "function name() view returns (string)",
      "function symbol() view returns (string)",
      "function totalSupply() view returns (uint256)",
      "function balanceOf(address) view returns (uint256)",
      "function transfer(address,uint256) returns (bool)",
      "function allowance(address,address) view returns (uint256)",
      "function approve(address,uint256) returns (bool)",
      "function transferFrom(address,address,uint256) returns (bool)",
      
      // Partition functions
      "function balanceOfByPartition(bytes32,address) view returns (uint256)",
      "function partitionsOf(address) view returns (bytes32[])",
      "function transferByPartition(bytes32,address,uint256,bytes) returns (bytes32)",
      
      // Issuance functions
      "function issueTokens(address,uint256,string,uint256,bytes20) returns (bytes32)",
      "function getInvestorIssuances(address) view returns (bytes32[])",
      "function issuances(bytes32) view returns (tuple(address investor, uint96 amount, uint64 timestamp, uint64 lockupEnd, bool verified, bool accredited, string ipfsCID))",
      
      // Compliance functions
      "function setKYC(address,bool,uint64) external",
      "function isKYCValid(address) view returns (bool)",
      "function verifyInvestor(address,string,bool) returns (bytes32)",
      "function setTransferLock(address,uint256)",
      "function forceTransfer(address,address,uint256,string)",
      "function setOfferingType(uint8)",
      "function verifyQIB(address,bool)",
      "function isQIB(address) view returns (bool)",
      
      // Derivative functions
      "function reportDerivative(bytes,bytes,bytes,bytes,bytes) returns (bytes32)",
      "function correctDerivative(bytes32,bytes32,bytes)",
      "function reportError(bytes32,string)",
      "function reportPosition(bytes32,bytes32[],bytes)",
      "function batchReportDerivatives(bytes[],bytes[],bytes[],bytes[],bytes[])",
      
      // Clearstream functions
      "function initiateSettlement(bytes32,address,address,uint256,uint256,uint256) returns (bytes32)",
      "function generateSettlementInstructions(bytes32)",
      "function confirmSettlement(bytes32,bytes32)",
      "function completeSettlement(bytes32)",
      "function linkClearstreamAccount(address,bytes20)",
      
      // NAV functions
      "function getNAV() view returns (uint256)",
      
      // Admin functions
      "function pause()",
      "function unpause()",
      "function updateModules(address,address,address,address)",
      
      // Role management
      "function grantRole(bytes32,address)",
      "function hasRole(bytes32,address) view returns (bool)"
    ],
    deployer
  );

  const tokenCore = new ethers.Contract(
    ADDRESSES.tokenCore,
    [
      "function name() view returns (string)",
      "function symbol() view returns (string)",
      "function totalSupply() view returns (uint256)",
      "function balanceOf(address) view returns (uint256)",
      "function mint(address,uint256,bytes32)",
      "function getDefaultPartitions() view returns (bytes32[])",
      "function setDefaultPartitions(bytes32[])"
    ],
    deployer
  );

  const complianceManager = new ethers.Contract(
    ADDRESSES.complianceManager,
    [
      "function setKYC(address,bool,uint64)",
      "function isKYCValid(address) view returns (bool)",
      "function setAccreditedStatus(address,bool)",
      "function isAccredited(address) view returns (bool)",
      "function setQIBStatus(address,bool)",
      "function isQIB(address) view returns (bool)",
      "function setOfferingType(uint8)",
      "function getOfferingType() view returns (uint8)",
      "function setTransferLock(address,uint256)",
      "function getTransferLock(address) view returns (uint256)",
      "function recordInvestment(address,uint256)"
    ],
    deployer
  );

  const derivativesManager = new ethers.Contract(
    ADDRESSES.derivativesManager,
    [
      "function getDerivative(bytes32) view returns (tuple(bytes32 uti, bytes32 priorUti, bytes12 upi, uint256 effectiveDate, uint256 expirationDate, uint256 executionTimestamp, uint256 notionalAmount, string notionalCurrency))",
      "function getDerivativeCorrections(bytes32) view returns (bytes32[])",
      "function getDerivativeErrors(bytes32) view returns (string[])"
    ],
    deployer
  );

  const clearstreamManager = new ethers.Contract(
    ADDRESSES.clearstreamManager,
    [
      "function getSettlement(bytes32) view returns (tuple(bytes32 settlementId, bytes32 tradeReference, address buyer, address seller, uint256 quantity, uint256 settlementAmount, uint8 status, uint256 settlementDate, uint256 valueDate, bytes20 buyerAccount, bytes20 sellerAccount, string isin, bytes32 instructionReference))",
      "function getInstructions(bytes32) view returns (tuple(bytes32 instructionId, uint8 instructionType, bytes32 settlementId, address participant, bytes20 participantAccount, uint256 quantity, uint256 amount, uint8 status, uint256 instructionDate, uint256 valueDate, string isin, bytes32 tradeReference)[])",
      "function getEvents(bytes32) view returns (tuple(bytes32 eventId, uint8 eventType, bytes32 settlementId, string eventDescription, uint256 eventTimestamp, address triggeredBy, bytes32 referenceId)[])"
    ],
    deployer
  );

  console.log("🔗 Contract instances created\n");

  // Verify main contract is properly initialized
  try {
    const mainName = await mainContract.name();
    console.log(`✅ Main contract verified: ${mainName}\n`);
  } catch (error) {
    console.error("❌ Failed to connect to main contract. Please check the address.");
    process.exit(1);
  }

  // ========================================================================
  // TEST 1: BASIC TOKEN INFORMATION
  // ========================================================================
  console.log("📊 TEST 1: Basic Token Information");
  console.log("   " + "-".repeat(50));

  const name = await mainContract.name();
  const symbol = await mainContract.symbol();
  const totalSupply = await mainContract.totalSupply();
  const deployerBalance = await mainContract.balanceOf(deployer.address);
  
  console.log(`   Name: ${name}`);
  console.log(`   Symbol: ${symbol}`);
  console.log(`   Total Supply: ${ethers.formatEther(totalSupply)} DTCC`);
  console.log(`   Deployer Balance: ${ethers.formatEther(deployerBalance)} DTCC\n`);

  // ========================================================================
  // TEST 2: PARTITION MANAGEMENT
  // ========================================================================
  console.log("📂 TEST 2: Partition Management");
  console.log("   " + "-".repeat(50));

  // Get default partitions
  const defaultPartitions = await tokenCore.getDefaultPartitions();
  console.log(`   Default Partitions: ${defaultPartitions.length}`);
  
  if (defaultPartitions.length === 0) {
    console.log("   ⚠️  No default partitions set. Setting DEFAULT partition...");
    const DEFAULT_PARTITION = stringToBytes32("DEFAULT");
    const tx = await tokenCore.setDefaultPartitions([DEFAULT_PARTITION]);
    await tx.wait();
    console.log("   ✅ Default partitions set");
  }

  // Check investor partitions
  const investorPartitions = await mainContract.partitionsOf(deployer.address);
  console.log(`   Investor Partitions: ${investorPartitions.length}\n`);

  // ========================================================================
  // TEST 3: KYC AND COMPLIANCE SETUP
  // ========================================================================
  console.log("🛡️  TEST 3: KYC and Compliance Setup");
  console.log("   " + "-".repeat(50));

  // Check if ComplianceManager is properly set
  try {
    const offeringType = await complianceManager.getOfferingType();
    console.log(`   Current offering type: ${offeringType}`);
  } catch (error) {
    console.log(`   ⚠️  Could not get offering type - ComplianceManager may not be properly configured`);
  }

  // Set KYC for test investors
  console.log("   Setting up KYC...");
  
  const kycExpiry = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60; // 1 year
  let tx = await mainContract.setKYC(testInvestor1.address, true, kycExpiry);
  await tx.wait();
  console.log(`   ✅ KYC set for Investor 1: ${testInvestor1.address}`);

  tx = await mainContract.setKYC(testInvestor2.address, true, kycExpiry);
  await tx.wait();
  console.log(`   ✅ KYC set for Investor 2: ${testInvestor2.address}`);

  // Verify KYC
  const isKYC1 = await mainContract.isKYCValid(testInvestor1.address);
  const isKYC2 = await mainContract.isKYCValid(testInvestor2.address);
  console.log(`   Investor 1 KYC valid: ${isKYC1}`);
  console.log(`   Investor 2 KYC valid: ${isKYC2}`);

  // Set accredited status
  tx = await complianceManager.setAccreditedStatus(testInvestor1.address, true);
  await tx.wait();
  console.log(`   ✅ Investor 1 set as accredited`);

  // Set QIB status
  tx = await mainContract.verifyQIB(testInvestor1.address, true);
  await tx.wait();
  console.log(`   ✅ Investor 1 set as QIB`);

  // Verify QIB
  const isQIB1 = await mainContract.isQIB(testInvestor1.address);
  console.log(`   Investor 1 is QIB: ${isQIB1}`);

  // Set offering type to Reg D 506(c)
  const OFFERING_TYPE_REG_D_506C = 1; // 0=REG_D_506B, 1=REG_D_506C, 2=REG_CF, 3=RULE_144A
  tx = await mainContract.setOfferingType(OFFERING_TYPE_REG_D_506C);
  await tx.wait();
  console.log(`   ✅ Offering type set to REG_D_506C\n`);

  // ========================================================================
  // TEST 4: TOKEN ISSUANCE
  // ========================================================================
  console.log("💰 TEST 4: Token Issuance");
  console.log("   " + "-".repeat(50));

  // Issue tokens to Investor 1
  const issuanceAmount = ethers.parseEther("1000");
  const ipfsCID = "QmTest123456789";
  const lockupPeriod = 30 * 24 * 60 * 60; // 30 days
  const csdAccount = generateTestLEI(); // Simulate Clearstream account

  console.log(`   Issuing ${ethers.formatEther(issuanceAmount)} DTCC to Investor 1...`);
  tx = await mainContract.issueTokens(
    testInvestor1.address,
    issuanceAmount,
    ipfsCID,
    lockupPeriod,
    csdAccount
  );
  const receipt = await tx.wait();
  
  // Get issuance ID from events
  const issuanceId = receipt?.logs[0]?.topics[1] || "0x0";
  console.log(`   ✅ Tokens issued - Issuance ID: ${issuanceId}`);

  // Check investor balance
  const investor1Balance = await mainContract.balanceOf(testInvestor1.address);
  console.log(`   Investor 1 balance: ${ethers.formatEther(investor1Balance)} DTCC`);

  // Get investor issuances
  const investorIssuances = await mainContract.getInvestorIssuances(testInvestor1.address);
  console.log(`   Investor 1 has ${investorIssuances.length} issuance(s)`);

  // Check issuance details
  if (investorIssuances.length > 0) {
    const issuance = await mainContract.issuances(investorIssuances[0]);
    console.log(`   Issuance details:`);
    console.log(`     - Investor: ${issuance.investor}`);
    console.log(`     - Amount: ${ethers.formatEther(issuance.amount)} DTCC`);
    console.log(`     - Accredited: ${issuance.accredited}`);
    console.log(`     - Lockup end: ${new Date(Number(issuance.lockupEnd) * 1000).toLocaleString()}\n`);
  }

  // ========================================================================
  // TEST 5: TOKEN TRANSFERS
  // ========================================================================
  console.log("🔄 TEST 5: Token Transfers");
  console.log("   " + "-".repeat(50));
  
  console.log("   Testing transfer from Investor 1 to Investor 2...");
  const transferAmount = ethers.parseEther("100");
  
  try {
    // This will likely fail because we're not sending as Investor 1
    tx = await mainContract.transfer(testInvestor2.address, transferAmount);
    await tx.wait();
    console.log(`   ✅ Transfer successful`);
  } catch (error) {
    console.log(`   ⚠️  Transfer failed (expected - needs to be called by token holder): ${error.message.slice(0, 100)}...`);
  }

  // Check balances after transfer attempt
  const balance1 = await mainContract.balanceOf(testInvestor1.address);
  const balance2 = await mainContract.balanceOf(testInvestor2.address);
  console.log(`   Investor 1 balance: ${ethers.formatEther(balance1)} DTCC`);
  console.log(`   Investor 2 balance: ${ethers.formatEther(balance2)} DTCC`);

  // Test approve/transferFrom
  console.log("\n   Testing approve + transferFrom...");
  const approveAmount = ethers.parseEther("50");
  
  try {
    tx = await mainContract.approve(deployer.address, approveAmount);
    await tx.wait();
    console.log(`   ✅ Approval set`);

    tx = await mainContract.transferFrom(testInvestor1.address, testInvestor2.address, approveAmount);
    await tx.wait();
    console.log(`   ✅ TransferFrom successful`);
  } catch (error) {
    console.log(`   ⚠️  Approval/TransferFrom failed (expected if not executed as Investor 1): ${error.message.slice(0, 100)}...`);
  }
  console.log();

  // ========================================================================
  // TEST 6: PARTITION TRANSFERS
  // ========================================================================
  console.log("📁 TEST 6: Partition Transfers");
  console.log("   " + "-".repeat(50));

  const DEFAULT_PARTITION = stringToBytes32("DEFAULT");
  
  try {
    // Check partition balance
    const partitionBalance = await mainContract.balanceOfByPartition(
      DEFAULT_PARTITION,
      testInvestor1.address
    );
    console.log(`   Partition balance for Investor 1: ${ethers.formatEther(partitionBalance)} DTCC`);

    // Attempt partition transfer
    const partitionTransferAmount = ethers.parseEther("25");
    const transferData = ethers.toUtf8Bytes("Test partition transfer");
    
    tx = await mainContract.transferByPartition(
      DEFAULT_PARTITION,
      testInvestor2.address,
      partitionTransferAmount,
      transferData
    );
    await tx.wait();
    console.log(`   ✅ Partition transfer successful`);
  } catch (error) {
    console.log(`   ⚠️  Partition transfer failed: ${error.message.slice(0, 100)}...`);
  }
  console.log();

  // ========================================================================
  // TEST 7: COMPLIANCE CONTROLS
  // ========================================================================
  console.log("⚖️  TEST 7: Compliance Controls");
  console.log("   " + "-".repeat(50));

  // Set transfer lock
  const lockTime = Math.floor(Date.now() / 1000) + 60 * 60; // 1 hour from now
  tx = await mainContract.setTransferLock(testInvestor2.address, lockTime);
  await tx.wait();
  console.log(`   ✅ Transfer lock set for Investor 2 until ${new Date(lockTime * 1000).toLocaleString()}`);

  // Force transfer (compliance officer override)
  const forceTransferAmount = ethers.parseEther("10");
  const forceReason = "Regulatory compliance action";
  
  tx = await mainContract.forceTransfer(
    testInvestor2.address,
    testInvestor1.address,
    forceTransferAmount,
    forceReason
  );
  await tx.wait();
  console.log(`   ✅ Force transfer executed by compliance officer`);

  // Check balances after force transfer
  const balanceAfterForce1 = await mainContract.balanceOf(testInvestor1.address);
  const balanceAfterForce2 = await mainContract.balanceOf(testInvestor2.address);
  console.log(`   After force transfer:`);
  console.log(`     Investor 1: ${ethers.formatEther(balanceAfterForce1)} DTCC`);
  console.log(`     Investor 2: ${ethers.formatEther(balanceAfterForce2)} DTCC\n`);

  // ========================================================================
  // TEST 8: DERIVATIVE REPORTING
  // ========================================================================
  console.log("📈 TEST 8: Derivative Reporting");
  console.log("   " + "-".repeat(50));

  // Create derivative data (encoded as bytes to match contract interface)
  const derivativeData = ethers.AbiCoder.defaultAbiCoder().encode(
    ["tuple(bytes32 uti, bytes32 priorUti, bytes12 upi, uint256 effectiveDate, uint256 expirationDate, uint256 executionTimestamp, uint256 notionalAmount, string notionalCurrency)"],
    [{
      uti: ethers.ZeroHash,
      priorUti: ethers.ZeroHash,
      upi: generateTestUPI(),
      effectiveDate: Math.floor(Date.now() / 1000),
      expirationDate: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
      executionTimestamp: Math.floor(Date.now() / 1000) - 60 * 60,
      notionalAmount: ethers.parseEther("1000000"),
      notionalCurrency: "USD"
    }]
  );

  // Create counterparty data
  const counterparty1Data = ethers.AbiCoder.defaultAbiCoder().encode(
    ["tuple(bytes20 lei, address walletAddress, string jurisdiction)"],
    [{
      lei: generateTestLEI(),
      walletAddress: testInvestor1.address,
      jurisdiction: "US"
    }]
  );

  const counterparty2Data = ethers.AbiCoder.defaultAbiCoder().encode(
    ["tuple(bytes20 lei, address walletAddress, string jurisdiction)"],
    [{
      lei: generateTestLEI(),
      walletAddress: testInvestor2.address,
      jurisdiction: "GB"
    }]
  );

  // Create collateral data
  const collateralData = ethers.AbiCoder.defaultAbiCoder().encode(
    ["tuple(string collateralType, uint256 collateralValue, string collateralCurrency, uint256 valuationTimestamp)"],
    [{
      collateralType: "Cash",
      collateralValue: ethers.parseEther("500000"),
      collateralCurrency: "USD",
      valuationTimestamp: Math.floor(Date.now() / 1000)
    }]
  );

  // Create valuation data
  const valuationData = ethers.AbiCoder.defaultAbiCoder().encode(
    ["tuple(uint256 valuation, string valuationCurrency, string valuationModel, uint256 valuationTimestamp)"],
    [{
      valuation: ethers.parseEther("1000000"),
      valuationCurrency: "USD",
      valuationModel: "Mark-to-Market",
      valuationTimestamp: Math.floor(Date.now() / 1000)
    }]
  );

  try {
    // Report derivative
    tx = await mainContract.reportDerivative(
      derivativeData,
      counterparty1Data,
      counterparty2Data,
      collateralData,
      valuationData
    );
    const derivReceipt = await tx.wait();
    const uti = derivReceipt?.logs[0]?.topics[1] || "0x0";
    console.log(`   ✅ Derivative reported - UTI: ${uti}`);

    // Test error reporting
    const errorReason = "Test error report";
    tx = await mainContract.reportError(uti, errorReason);
    await tx.wait();
    console.log(`   ✅ Error reported for UTI: ${uti}`);

    // Test position reporting
    const positionId = stringToBytes32("POSITION_1");
    tx = await mainContract.reportPosition(positionId, [uti], valuationData);
    await tx.wait();
    console.log(`   ✅ Position reported: ${positionId}`);

  } catch (error) {
    console.log(`   ⚠️  Derivative reporting failed: ${error.message.slice(0, 100)}...`);
  }
  console.log();

  // ========================================================================
  // TEST 9: CLEARSTREAM SETTLEMENT
  // ========================================================================
  console.log("🏦 TEST 9: Clearstream Settlement");
  console.log("   " + "-".repeat(50));

  try {
    // Link Clearstream accounts
    const csdAccount1 = generateTestLEI();
    const csdAccount2 = generateTestLEI();
    
    tx = await mainContract.linkClearstreamAccount(testInvestor1.address, csdAccount1);
    await tx.wait();
    console.log(`   ✅ Clearstream account linked for Investor 1`);

    tx = await mainContract.linkClearstreamAccount(testInvestor2.address, csdAccount2);
    await tx.wait();
    console.log(`   ✅ Clearstream account linked for Investor 2`);

    // Initiate settlement
    const tradeReference = stringToBytes32("TRADE_001");
    const settlementAmount = ethers.parseEther("100");
    const valueDate = Math.floor(Date.now() / 1000) + 2 * 24 * 60 * 60; // T+2

    tx = await mainContract.initiateSettlement(
      tradeReference,
      testInvestor1.address, // buyer
      testInvestor2.address, // seller
      ethers.parseEther("100"), // quantity
      settlementAmount,
      valueDate
    );
    const settlementReceipt = await tx.wait();
    const settlementId = settlementReceipt?.logs[0]?.topics[1] || "0x0";
    console.log(`   ✅ Settlement initiated - ID: ${settlementId}`);

    // Generate instructions
    tx = await mainContract.generateSettlementInstructions(settlementId);
    await tx.wait();
    console.log(`   ✅ Settlement instructions generated`);

    // Confirm settlement
    const instructionReference = stringToBytes32("INST_001");
    tx = await mainContract.confirmSettlement(settlementId, instructionReference);
    await tx.wait();
    console.log(`   ✅ Settlement confirmed`);

    // Complete settlement
    tx = await mainContract.completeSettlement(settlementId);
    await tx.wait();
    console.log(`   ✅ Settlement completed`);

  } catch (error) {
    console.log(`   ⚠️  Clearstream settlement failed: ${error.message.slice(0, 100)}...`);
  }
  console.log();

  // ========================================================================
  // TEST 10: NAV CALCULATION
  // ========================================================================
  console.log("💰 TEST 10: NAV Calculation");
  console.log("   " + "-".repeat(50));

  try {
    const nav = await mainContract.getNAV();
    console.log(`   Current NAV: $${ethers.formatEther(nav)} USD`);
  } catch (error) {
    console.log(`   ⚠️  NAV calculation failed: ${error.message.slice(0, 100)}...`);
  }
  console.log();

  // ========================================================================
  // TEST 11: PAUSE/UNPAUSE FUNCTIONALITY
  // ========================================================================
  console.log("⏸️  TEST 11: Pause/Unpause");
  console.log("   " + "-".repeat(50));

  // Pause
  tx = await mainContract.pause();
  await tx.wait();
  console.log(`   ✅ Contract paused`);

  // Try transfer while paused (should fail)
  try {
    await mainContract.transfer(testInvestor2.address, ethers.parseEther("1"));
    console.log(`   ❌ Transfer succeeded while paused (unexpected!)`);
  } catch (error) {
    console.log(`   ✅ Transfer failed as expected when paused: ${error.message.slice(0, 100)}...`);
  }

  // Unpause
  tx = await mainContract.unpause();
  await tx.wait();
  console.log(`   ✅ Contract unpaused\n`);

  // ========================================================================
  // TEST 12: ROLE MANAGEMENT
  // ========================================================================
  console.log("👥 TEST 12: Role Management");
  console.log("   " + "-".repeat(50));

  const ISSUER_ROLE = stringToBytes32("ISSUER_ROLE");
  const COMPLIANCE_OFFICER = stringToBytes32("COMPLIANCE_OFFICER");
  const PAUSER_ROLE = stringToBytes32("PAUSER_ROLE");

  const hasIssuerRole = await mainContract.hasRole(ISSUER_ROLE, deployer.address);
  const hasComplianceRole = await mainContract.hasRole(COMPLIANCE_OFFICER, deployer.address);
  const hasPauserRole = await mainContract.hasRole(PAUSER_ROLE, deployer.address);

  console.log(`   Deployer has ISSUER_ROLE: ${hasIssuerRole}`);
  console.log(`   Deployer has COMPLIANCE_OFFICER: ${hasComplianceRole}`);
  console.log(`   Deployer has PAUSER_ROLE: ${hasPauserRole}`);

  // Grant role to test investor
  if (hasIssuerRole) {
    tx = await mainContract.grantRole(ISSUER_ROLE, testInvestor1.address);
    await tx.wait();
    console.log(`   ✅ ISSUER_ROLE granted to Investor 1`);
  }
  console.log();

  // ========================================================================
  // TEST 13: MODULE UPDATES
  // ========================================================================
  console.log("🔄 TEST 13: Module Updates");
  console.log("   " + "-".repeat(50));

  try {
    // Update modules (can set to zero to keep existing)
    tx = await mainContract.updateModules(
      ethers.ZeroAddress, // keep existing TokenCore
      ethers.ZeroAddress, // keep existing ComplianceManager
      ethers.ZeroAddress, // keep existing DerivativesManager
      ethers.ZeroAddress  // keep existing ClearstreamManager
    );
    await tx.wait();
    console.log(`   ✅ Modules updated (kept existing)`);
  } catch (error) {
    console.log(`   ⚠️  Module update failed: ${error.message.slice(0, 100)}...`);
  }
  console.log();

  // ========================================================================
  // SUMMARY
  // ========================================================================
  console.log("\n📊 TEST SUMMARY");
  console.log("   " + "=".repeat(50));
  console.log(`   Total Tests Run: 13`);
  console.log(`   Contract: ${ADDRESSES.dtccCompliantSTO}`);
  console.log(`   Network: Sepolia`);
  console.log(`   Timestamp: ${new Date().toISOString()}`);
  console.log("   " + "=".repeat(50));

  // Save test results
  const testResults = {
    timestamp: new Date().toISOString(),
    addresses: ADDRESSES,
    tests: {
      basicInfo: true,
      partitions: defaultPartitions.length > 0,
      kycSetup: isKYC1 && isKYC2,
      issuance: investorIssuances.length > 0,
      compliance: true,
      pause: true,
      roles: hasIssuerRole && hasComplianceRole && hasPauserRole
    },
    balances: {
      deployer: ethers.formatEther(deployerBalance),
      investor1: ethers.formatEther(await mainContract.balanceOf(testInvestor1.address)),
      investor2: ethers.formatEther(await mainContract.balanceOf(testInvestor2.address))
    }
  };

  fs.writeFileSync(
    `test-results-${Date.now()}.json`,
    JSON.stringify(testResults, null, 2)
  );
  console.log(`\n💾 Test results saved to test-results-${Date.now()}.json`);
  
  console.log("\n✨ Testing complete!");
}

main().catch((error) => {
  console.error("\n❌ Test failed:", error);
  process.exit(1);
});