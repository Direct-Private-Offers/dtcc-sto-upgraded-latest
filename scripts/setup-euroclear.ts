import { ethers } from "hardhat";
import { EuroclearClient } from "../src/api/euroclear/client";
import { Logger } from "../src/utils/logging";

const logger = new Logger("setup");

async function main() {
  console.log("🔧 Setting up Euroclear integration...");

  const [deployer] = await ethers.getSigners();
  const euroclearClient = new EuroclearClient();

  // Get contract instances
  const euroclearBridge = await ethers.getContractAt(
    "EuroclearBridge",
    process.env.EUROCLEAR_BRIDGE_CONTRACT!
  );

  const dtccSTO = await ethers.getContractAt(
    "DTCCCompliantSTO",
    process.env.DTCC_STO_CONTRACT!
  );

  // Test tokenization with a sample security
  console.log("🧪 Testing tokenization flow...");
  
  const testTokenization = {
    isin: "US0378331005",
    investorAddress: deployer.address,
    amount: ethers.parseEther("1000"),
    euroclearRef: "TEST_REF_001",
    ipfsCID: "QmTestIPFSCID123456789"
  };

  try {
    const isinBytes32 = ethers.encodeBytes32String(testTokenization.isin);
    const euroclearRefBytes32 = ethers.encodeBytes32String(testTokenization.euroclearRef);

    const tx = await euroclearBridge.tokenizeSecurity(
      isinBytes32,
      testTokenization.investorAddress,
      testTokenization.amount,
      euroclearRefBytes32,
      testTokenization.ipfsCID
    );

    const receipt = await tx.wait();
    console.log("✅ Test tokenization successful:", receipt.hash);

    // Test derivative reporting
    console.log("🧪 Testing derivative reporting...");
    
    const testDerivative = {
      isin: "US0378331005",
      derivativeData: {
        uti: "TEST_UTI_123456789",
        priorUti: "",
        upi: "UPI_SWAP_001",
        effectiveDate: Math.floor(Date.now() / 1000),
        expirationDate: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
        executionTimestamp: Math.floor(Date.now() / 1000),
        notionalAmount: ethers.parseEther("1000000"),
        notionalCurrency: "USD",
        productType: "SWAP",
        underlyingAsset: "AAPL"
      },
      counterparty1: {
        lei: "0x3534393330304558414d504c454c4549", // 549300EXAMPLELEI
        walletAddress: deployer.address,
        jurisdiction: "US",
        isReportable: true
      },
      counterparty2: {
        lei: "0x3534393330304d5346544c4549303031", // 549300MSFTLEI001
        walletAddress: "0x842d35Cc6634C0532925a3b8Doe1234567890123",
        jurisdiction: "GB",
        isReportable: true
      },
      collateralData: {
        collateralAmount: ethers.parseEther("100000"),
        collateralCurrency: "USD",
        collateralType: "CASH",
        valuationTimestamp: Math.floor(Date.now() / 1000)
      },
      valuationData: {
        marketValue: ethers.parseEther("950000"),
        valuationCurrency: "USD",
        valuationTimestamp: Math.floor(Date.now() / 1000),
        valuationModel: "BLACK_SCHOLES"
      }
    };

    const derivativeTx = await euroclearBridge.reportEuroclearDerivative({
      isin: ethers.encodeBytes32String(testDerivative.isin),
      derivativeData: {
        uti: ethers.encodeBytes32String(testDerivative.derivativeData.uti),
        priorUti: ethers.ZeroHash,
        upi: testDerivative.derivativeData.upi,
        effectiveDate: testDerivative.derivativeData.effectiveDate,
        expirationDate: testDerivative.derivativeData.expirationDate,
        executionTimestamp: testDerivative.derivativeData.executionTimestamp,
        notionalAmount: testDerivative.derivativeData.notionalAmount,
        notionalCurrency: testDerivative.derivativeData.notionalCurrency,
        productType: testDerivative.derivativeData.productType,
        underlyingAsset: testDerivative.derivativeData.underlyingAsset
      },
      counterparty1: {
        lei: testDerivative.counterparty1.lei,
        walletAddress: testDerivative.counterparty1.walletAddress,
        jurisdiction: testDerivative.counterparty1.jurisdiction,
        isReportable: testDerivative.counterparty1.isReportable
      },
      counterparty2: {
        lei: testDerivative.counterparty2.lei,
        walletAddress: testDerivative.counterparty2.walletAddress,
        jurisdiction: testDerivative.counterparty2.jurisdiction,
        isReportable: testDerivative.counterparty2.isReportable
      },
      collateralData: {
        collateralAmount: testDerivative.collateralData.collateralAmount,
        collateralCurrency: testDerivative.collateralData.collateralCurrency,
        collateralType: testDerivative.collateralData.collateralType,
        valuationTimestamp: testDerivative.collateralData.valuationTimestamp
      },
      valuationData: {
        marketValue: testDerivative.valuationData.marketValue,
        valuationCurrency: testDerivative.valuationData.valuationCurrency,
        valuationTimestamp: testDerivative.valuationData.valuationTimestamp,
        valuationModel: testDerivative.valuationData.valuationModel
      }
    });

    const derivativeReceipt = await derivativeTx.wait();
    console.log("✅ Test derivative reporting successful:", derivativeReceipt.hash);

    // Verify setup
    console.log("🔍 Verifying setup...");
    
    const securityDetails = await euroclearBridge.getSecurityDetails(isinBytes32);
    console.log("✅ Security details:", securityDetails);

    const nav = await euroclearBridge.getEuroclearNAV(isinBytes32);
    console.log("✅ NAV calculation:", nav.toString());

    logger.info("Euroclear setup completed successfully", {
      testTokenization: receipt.hash,
      testDerivative: derivativeReceipt.hash
    });

    console.log("🎉 Euroclear integration setup completed!");

  } catch (error) {
    console.error("❌ Setup failed:", error);
    logger.error("Setup failed", { error: error.message });
    process.exit(1);
  }
}

main().catch((error) => {
  console.error("Setup failed:", error);
  process.exit(1);
});