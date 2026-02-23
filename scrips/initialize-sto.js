import Web3 from 'web3';
import dotenv from 'dotenv';

dotenv.config();

// ============================================
// MINIMAL ABIs (keep as is)
// ============================================

const TOKEN_CORE_ABI = [
  {
    "constant": true,
    "inputs": [],
    "name": "DEFAULT_ADMIN_ROLE",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "TOKEN_OPERATOR",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "grantRole",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "hasRole",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [{"name": "partitions", "type": "bytes32[]"}],
    "name": "setDefaultPartitions",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "to", "type": "address"},
      {"name": "amount", "type": "uint256"},
      {"name": "partition", "type": "bytes32"}
    ],
    "name": "mint",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "getDefaultPartitions",
    "outputs": [{"name": "", "type": "bytes32[]"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "totalSupply",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  }
];

const COMPLIANCE_MANAGER_ABI = [
  {
    "constant": true,
    "inputs": [],
    "name": "COMPLIANCE_OFFICER",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "DEFAULT_ADMIN_ROLE",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "grantRole",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "hasRole",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [{"name": "offeringType", "type": "uint8"}],
    "name": "setOfferingType",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "user", "type": "address"},
      {"name": "approved", "type": "bool"},
      {"name": "expiry", "type": "uint64"}
    ],
    "name": "setKYC",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "investor", "type": "address"},
      {"name": "accredited", "type": "bool"}
    ],
    "name": "setAccreditedStatus",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "investor", "type": "address"},
      {"name": "isQIB", "type": "bool"}
    ],
    "name": "setQIBStatus",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{"name": "user", "type": "address"}],
    "name": "isKYCValid",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{"name": "investor", "type": "address"}],
    "name": "isAccredited",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{"name": "investor", "type": "address"}],
    "name": "isQIB",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  }
];

const DERIVATIVES_MANAGER_ABI = [
  {
    "constant": true,
    "inputs": [],
    "name": "DERIVATIVES_REPORTER",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "DEFAULT_ADMIN_ROLE",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "grantRole",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "hasRole",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  }
];

const CLEARSTREAM_MANAGER_ABI = [
  {
    "constant": true,
    "inputs": [],
    "name": "CLEARSTREAM_OPERATOR",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "DEFAULT_ADMIN_ROLE",
    "outputs": [{"name": "", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "grantRole",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {"name": "role", "type": "bytes32"},
      {"name": "account", "type": "address"}
    ],
    "name": "hasRole",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [{"name": "isin", "type": "string"}],
    "name": "addISINToWhitelist",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "investor", "type": "address"},
      {"name": "csdAccount", "type": "bytes20"}
    ],
    "name": "linkClearstreamAccount",
    "outputs": [],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [{"name": "newIsinCode", "type": "bytes12"}],
    "name": "setIsinCode",
    "outputs": [],
    "type": "function"
  }
];

const MAIN_CONTRACT_ABI = [
  {
    "constant": true,
    "inputs": [],
    "name": "name",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "symbol",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "totalSupply",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{"name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "to", "type": "address"},
      {"name": "amount", "type": "uint256"}
    ],
    "name": "transfer",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "investor", "type": "address"},
      {"name": "amount", "type": "uint256"},
      {"name": "ipfsCID", "type": "string"},
      {"name": "lockupPeriod", "type": "uint256"},
      {"name": "csdAccount", "type": "bytes20"}
    ],
    "name": "issueTokens",
    "outputs": [{"name": "id", "type": "bytes32"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "getNAV",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "tokenCore",
    "outputs": [{"name": "", "type": "address"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "complianceManager",
    "outputs": [{"name": "", "type": "address"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "derivativesManager",
    "outputs": [{"name": "", "type": "address"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "clearstreamManager",
    "outputs": [{"name": "", "type": "address"}],
    "type": "function"
  }
];

// ============================================
// DEPLOYED ADDRESSES
// ============================================
const ADDRESSES = {
  tokenCore: "0x8017B6ba0055A13619A558Ca49005a259368bd10",
  complianceManager: "0x60F6fF8FC16a86B667B251C84b1A701963a2380e",
  derivativesManager: "0x337357DaBC6F84c4E8CA0083CC5010d15567aeA4",
  clearstreamManager: "0x17Efd60A9791d886a9f2A38E41f8ff569c49548C",
  dtccCompliantSTO: "0xB52251feE8D24cD2c254Ad88F80F126989de679A"
};

// ============================================
// HELPER FUNCTIONS
// ============================================
function stringToBytes32(text) {
  const encoder = new TextEncoder();
  const bytes = encoder.encode(text);
  if (bytes.length > 32) throw new Error("String too long for bytes32");
  const hex = Buffer.from(bytes).toString("hex").padEnd(64, "0");
  return "0x" + hex;
}

function stringToBytes12(text) {
  const encoder = new TextEncoder();
  const bytes = encoder.encode(text);
  if (bytes.length > 12) throw new Error("String too long for bytes12");
  const hex = Buffer.from(bytes).toString("hex").padEnd(24, "0");
  return "0x" + hex;
}

function stringToBytes20(text) {
  const encoder = new TextEncoder();
  const bytes = encoder.encode(text);
  if (bytes.length > 20) throw new Error("String too long for bytes20");
  const hex = Buffer.from(bytes).toString("hex").padEnd(40, "0");
  return "0x" + hex;
}

// Helper to wait between transactions
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Helper function to send transactions with dynamic gas and nonce management
async function sendTransaction(web3, contractMethod, fromAddress, description, nonce) {
  try {
    console.log(`  ⏳ ${description}...`);
    
    // Estimate gas - ensure we handle BigInt properly
    const gasEstimate = await contractMethod.estimateGas({ from: fromAddress });
    // Convert to number safely
    const gasEstimateNum = typeof gasEstimate === 'bigint' ? Number(gasEstimate) : Number(gasEstimate);
    console.log(`  ⛽ Estimated gas: ${gasEstimateNum}`);
    
    // Get current gas price
    const gasPrice = await web3.eth.getGasPrice();
    const gasPriceNum = typeof gasPrice === 'bigint' ? Number(gasPrice) : Number(gasPrice);
    const gasPriceInGwei = web3.utils.fromWei(gasPrice, 'gwei');
    console.log(`  ⛽ Gas price: ${gasPriceInGwei} Gwei`);
    
    // Add 20% buffer to gas estimate
    const gasLimit = Math.floor(gasEstimateNum * 1.2);
    
    // Get current nonce if not provided
    if (nonce === undefined) {
      nonce = await web3.eth.getTransactionCount(fromAddress, 'pending');
      nonce = typeof nonce === 'bigint' ? Number(nonce) : nonce;
    }
    
    console.log(`  🔢 Nonce: ${nonce}`);
    
    // Send transaction with explicit nonce
    const tx = await contractMethod.send({
      from: fromAddress,
      gas: gasLimit,
      gasPrice: gasPrice,
      nonce: nonce
    });
    
    console.log(`  ✅ ${description} successful - TX: ${tx.transactionHash}`);
    return { success: true, tx, nonce: nonce + 1 };
  } catch (error) {
    console.log(`  ❌ ${description} failed:`, error.message);
    return { success: false, error: error.message, nonce };
  }
}

// ============================================
// MAIN INITIALIZATION
// ============================================
async function main() {
  console.log("\n" + "=".repeat(60));
  console.log("🚀 DTCC STO INITIALIZATION SCRIPT");
  console.log("=".repeat(60));
  
  // Connect to network
  if (!process.env.SEPOLIA_RPC_URL) throw new Error("SEPOLIA_RPC_URL not set");
  if (!process.env.DEPLOYER_PRIVATE_KEY) throw new Error("DEPLOYER_PRIVATE_KEY not set");
  
  console.log("\n📡 Connecting to Sepolia...");
  const web3 = new Web3(process.env.SEPOLIA_RPC_URL);
  
  // Test connection
  try {
    const networkId = await web3.eth.net.getId();
    console.log(`  ✅ Connected to network ID: ${networkId}`);
  } catch (error) {
    console.log("  ❌ Failed to connect:", error.message);
    process.exit(1);
  }
  
  // Add account from private key
  const account = web3.eth.accounts.privateKeyToAccount(process.env.DEPLOYER_PRIVATE_KEY);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;
  
  console.log("\n👤 Deployer:", account.address);
  
  // Check balance
  const balance = await web3.eth.getBalance(account.address);
  console.log("💰 Balance:", web3.utils.fromWei(balance, 'ether'), "ETH");

  // Create contract instances
  const tokenCore = new web3.eth.Contract(TOKEN_CORE_ABI, ADDRESSES.tokenCore);
  const complianceManager = new web3.eth.Contract(COMPLIANCE_MANAGER_ABI, ADDRESSES.complianceManager);
  const derivativesManager = new web3.eth.Contract(DERIVATIVES_MANAGER_ABI, ADDRESSES.derivativesManager);
  const clearstreamManager = new web3.eth.Contract(CLEARSTREAM_MANAGER_ABI, ADDRESSES.clearstreamManager);
  const mainContract = new web3.eth.Contract(MAIN_CONTRACT_ABI, ADDRESSES.dtccCompliantSTO);

  // Set from address for all contracts
  tokenCore.options.from = account.address;
  complianceManager.options.from = account.address;
  derivativesManager.options.from = account.address;
  clearstreamManager.options.from = account.address;
  mainContract.options.from = account.address;

  // Verify main contract connection
  console.log("\n🔍 Verifying main contract connection...");
  try {
    const tokenName = await mainContract.methods.name().call();
    console.log("  ✅ Main contract connected - Token:", tokenName);
    
    const tokenCoreAddr = await mainContract.methods.tokenCore().call();
    console.log("  ✅ TokenCore address from main contract:", tokenCoreAddr);
  } catch (error) {
    console.log("  ❌ Cannot connect to main contract:", error.message);
    process.exit(1);
  }

  // Get initial nonce
  let initialNonce = await web3.eth.getTransactionCount(account.address, 'pending');
  let currentNonce = typeof initialNonce === 'bigint' ? Number(initialNonce) : initialNonce;
  console.log(`\n📝 Starting nonce: ${currentNonce}`);

  // ========================================
  // STEP 1: Configure TokenCore
  // ========================================
  console.log("\n⚙️  STEP 1: Configuring TokenCore");
  console.log("-".repeat(40));

  try {
    const defaultPartition = stringToBytes32("DEFAULT");
    console.log("  Setting default partition:", defaultPartition);
    
    const result = await sendTransaction(
      web3,
      tokenCore.methods.setDefaultPartitions([defaultPartition]),
      account.address,
      "Set default partitions",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ TokenCore configuration failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000); // Wait 2 seconds between transactions
    
    const partitions = await tokenCore.methods.getDefaultPartitions().call();
    console.log("  📊 Current partitions:", partitions);
    console.log(`  ✅ TokenCore configuration completed successfully`);
  } catch (error) {
    console.log("  ❌ TokenCore config error - stopping script:", error.message);
    process.exit(1);
  }

  // ========================================
  // STEP 2: Configure ComplianceManager
  // ========================================
  console.log("\n⚖️  STEP 2: Configuring ComplianceManager");
  console.log("-".repeat(40));

  try {
    // Set offering type (1 = REG_D_506C)
    const OFFERING_TYPE = 1;
    console.log("  Setting offering type to REG_D_506C (1)");
    
    let result = await sendTransaction(
      web3,
      complianceManager.methods.setOfferingType(OFFERING_TYPE),
      account.address,
      "Set offering type",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ Offering type configuration failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);

    // Set deployer KYC (1 year expiry)
    const expiry = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;
    console.log("  Setting deployer KYC");
    
    result = await sendTransaction(
      web3,
      complianceManager.methods.setKYC(account.address, true, expiry),
      account.address,
      "Set KYC",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ KYC configuration failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);

    // Set accredited status
    console.log("  Setting accredited status");
    result = await sendTransaction(
      web3,
      complianceManager.methods.setAccreditedStatus(account.address, true),
      account.address,
      "Set accredited status",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ Accredited status configuration failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);

    // Set QIB status
    console.log("  Setting QIB status");
    result = await sendTransaction(
      web3,
      complianceManager.methods.setQIBStatus(account.address, true),
      account.address,
      "Set QIB status",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ QIB status configuration failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);

    // Verify settings
    const isKycValid = await complianceManager.methods.isKYCValid(account.address).call();
    const isAccredited = await complianceManager.methods.isAccredited(account.address).call();
    const isQib = await complianceManager.methods.isQIB(account.address).call();
    
    console.log("  📊 Verification:");
    console.log("    - KYC Valid:", isKycValid);
    console.log("    - Accredited:", isAccredited);
    console.log("    - QIB:", isQib);
    console.log(`  ✅ ComplianceManager configuration completed successfully`);

  } catch (error) {
    console.log("  ❌ ComplianceManager config error - stopping script:", error.message);
    process.exit(1);
  }

  // ========================================
  // STEP 3: Configure ClearstreamManager
  // ========================================
  console.log("\n🏦 STEP 3: Configuring ClearstreamManager");
  console.log("-".repeat(40));

  try {
    // Set ISIN code
    const isinCode = stringToBytes12("US1234567890");
    console.log("  Setting ISIN code");
    
    let result = await sendTransaction(
      web3,
      clearstreamManager.methods.setIsinCode(isinCode),
      account.address,
      "Set ISIN code",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ ISIN code configuration failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);

    // Add ISIN to whitelist
    console.log("  Adding ISIN to whitelist");
    result = await sendTransaction(
      web3,
      clearstreamManager.methods.addISINToWhitelist("US1234567890"),
      account.address,
      "Add ISIN to whitelist",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ ISIN whitelist configuration failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);

    // Link Clearstream account
    const csdAccount = stringToBytes20("CLEARSTREAM001");
    console.log("  Linking Clearstream account");
    
    result = await sendTransaction(
      web3,
      clearstreamManager.methods.linkClearstreamAccount(account.address, csdAccount),
      account.address,
      "Link Clearstream account",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ Clearstream account linking failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);
    
    console.log(`  ✅ ClearstreamManager configuration completed successfully`);
    
  } catch (error) {
    console.log("  ❌ ClearstreamManager config error - stopping script:", error.message);
    process.exit(1);
  }

  // ========================================
  // STEP 4: Mint Initial Token Supply
  // ========================================
  console.log("\n💰 STEP 4: Minting Initial Token Supply");
  console.log("-".repeat(40));

  try {
    const defaultPartition = stringToBytes32("DEFAULT");
    const INITIAL_SUPPLY = web3.utils.toWei('1000000', 'ether'); // 1 million tokens
    
    console.log("  Minting", web3.utils.fromWei(INITIAL_SUPPLY, 'ether'), "DTCC tokens");
    
    const result = await sendTransaction(
      web3,
      tokenCore.methods.mint(account.address, INITIAL_SUPPLY, defaultPartition),
      account.address,
      "Mint tokens",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ Token minting failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);

    const totalSupply = await tokenCore.methods.totalSupply().call();
    console.log("  📊 Total supply:", web3.utils.fromWei(totalSupply, 'ether'), "DTCC");
    console.log(`  ✅ Token minting completed successfully`);
  } catch (error) {
    console.log("  ❌ Minting error - stopping script:", error.message);
    process.exit(1);
  }

  // ========================================
  // STEP 5: Test Issuance (Optional but recommended)
  // ========================================
  console.log("\n🧪 STEP 5: Testing Issuance");
  console.log("-".repeat(40));

  try {
    const testInvestor = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    
    // Set up test investor first
    console.log("  Setting up test investor...");
    
    // Set KYC for test investor
    let result = await sendTransaction(
      web3,
      complianceManager.methods.setKYC(testInvestor, true, Math.floor(Date.now()/1000) + 365*24*60*60),
      account.address,
      "Set test investor KYC",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ Test investor KYC failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);
    
    // Set accredited status for test investor
    result = await sendTransaction(
      web3,
      complianceManager.methods.setAccreditedStatus(testInvestor, true),
      account.address,
      "Set test investor accredited",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ Test investor accredited status failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    await sleep(2000);
    
    const issuanceAmount = web3.utils.toWei('1000', 'ether');
    const lockupPeriod = 30 * 24 * 60 * 60; // 30 days
    const testAccount = stringToBytes20("TESTACCOUNT01");
    
    console.log(`  Issuing ${web3.utils.fromWei(issuanceAmount, 'ether')} tokens to test investor`);
    
    result = await sendTransaction(
      web3,
      mainContract.methods.issueTokens(
        testInvestor,
        issuanceAmount,
        "QmTest123",
        lockupPeriod,
        testAccount
      ),
      account.address,
      "Test issuance",
      currentNonce
    );
    
    if (!result.success) {
      console.log("  ❌ Test issuance failed - stopping script");
      process.exit(1);
    }
    
    currentNonce = result.nonce;
    console.log("  ✅ Test issuance completed successfully");
    
  } catch (error) {
    console.log("  ❌ Test issuance failed - stopping script:", error.message);
    process.exit(1);
  }

  // ========================================
  // STEP 6: Check NAV
  // ========================================
  console.log("\n📊 STEP 6: Checking NAV");
  console.log("-".repeat(40));

  try {
    const nav = await mainContract.methods.getNAV().call();
    console.log("  📈 Current NAV:", web3.utils.fromWei(nav, 'ether'), "USD");
  } catch (error) {
    console.log("  ⚠️  NAV calculation failed (non-critical):", error.message);
  }

  console.log("\n" + "=".repeat(60));
  console.log("✅ INITIALIZATION COMPLETE - ALL STEPS SUCCESSFUL");
  console.log("=".repeat(60));
  console.log("\n📋 Contract Addresses:");
  console.log("  TokenCore:         ", ADDRESSES.tokenCore);
  console.log("  ComplianceManager: ", ADDRESSES.complianceManager);
  console.log("  DerivativesManager:", ADDRESSES.derivativesManager);
  console.log("  ClearstreamManager:", ADDRESSES.clearstreamManager);
  console.log("  DTCCCompliantSTO:  ", ADDRESSES.dtccCompliantSTO);
}

// Run the script
main().catch((error) => {
  console.error("\n❌ Initialization failed:", error);
  process.exit(1);
});
