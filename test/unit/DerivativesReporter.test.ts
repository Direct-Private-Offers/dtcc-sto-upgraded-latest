import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { 
  generateTestLEI, 
  generateTestUPI, 
  createTestDerivativeData, 
  createTestCounterparty,
  createTestCollateralData,
  createTestValuationData,
  TEST_CONSTANTS 
} from "../helpers/testUtils.js";

describe("DerivativesReporter - Unit Tests", function () {
  async function deployFixture() {
    const [owner, reporter, investor] = await ethers.getSigners();

    const MockLEIRegistry = await ethers.getContractFactory("MockLEIRegistry");
    const leiRegistry = await MockLEIRegistry.deploy();
    
    const MockUPIProvider = await ethers.getContractFactory("MockUPIProvider");
    const upiProvider = await MockUPIProvider.deploy();
    
    const MockTradeRepository = await ethers.getContractFactory("MockTradeRepository");
    const tradeRepository = await MockTradeRepository.deploy();

    const DerivativesReporter = await ethers.getContractFactory("DerivativesReporter");
    const derivativesReporter = await DerivativesReporter.deploy(
      await leiRegistry.getAddress(),
      await upiProvider.getAddress(),
      await tradeRepository.getAddress()
    );

    // Grant roles
    await derivativesReporter.grantRole(await derivativesReporter.DERIVATIVES_REPORTER(), reporter.address);

    return { derivativesReporter, leiRegistry, upiProvider, tradeRepository, owner, reporter, investor };
  }

  describe("Derivative Reporting", function () {
    it("Should report a new derivative successfully", async function () {
      const { derivativesReporter, leiRegistry, upiProvider, reporter, investor } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: reporter.address });
      const counterparty2 = createTestCounterparty({ 
        walletAddress: investor.address, 
        isReporting: false 
      });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register LEIs and UPI
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await expect(
        derivativesReporter.connect(reporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.emit(derivativesReporter, "DerivativeReported");
    });

    it("Should reject invalid LEI", async function () {
      const { derivativesReporter, upiProvider, reporter, investor } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: reporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register only UPI, not LEI
      await upiProvider.registerUPI(derivativeData.upi);

      await expect(
        derivativesReporter.connect(reporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWith(TEST_CONSTANTS.ERROR_INVALID_LEI);
    });

    it("Should reject invalid UPI", async function () {
      const { derivativesReporter, leiRegistry, reporter, investor } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: reporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register only LEIs, not UPI
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);

      await expect(
        derivativesReporter.connect(reporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWith(TEST_CONSTANTS.ERROR_INVALID_UPI);
    });

    it("Should reject duplicate UTI", async function () {
      const { derivativesReporter, leiRegistry, upiProvider, reporter, investor } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: reporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register identifiers
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      // First report should succeed
      await derivativesReporter.connect(reporter).reportDerivative(
        derivativeData,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      // Second report with same UTI should fail
      await expect(
        derivativesReporter.connect(reporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWith(TEST_CONSTANTS.ERROR_TRADE_EXISTS);
    });
  });

  describe("Error Handling", function () {
    it("Should report errors for existing derivatives", async function () {
      const { derivativesReporter, leiRegistry, upiProvider, reporter, investor } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: reporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register identifiers and report derivative
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);
      await derivativesReporter.connect(reporter).reportDerivative(
        derivativeData,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      // Report error
      const errorReason = "Incorrect notional amount reported";
      await expect(
        derivativesReporter.connect(reporter).reportError(derivativeData.uti, errorReason)
      ).to.emit(derivativesReporter, "ErrorReported");
    });

    it("Should reject error reporting for non-existent derivatives", async function () {
      const { derivativesReporter, reporter } = await loadFixture(deployFixture);
      
      const nonExistentUTI = generateTestUTI();
      const errorReason = "Test error";

      await expect(
        derivativesReporter.connect(reporter).reportError(nonExistentUTI, errorReason)
      ).to.be.revertedWith("Derivative not found");
    });
  });

  describe("Access Control", function () {
    it("Should reject unauthorized derivative reporting", async function () {
      const { derivativesReporter, leiRegistry, upiProvider, investor } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: investor.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register identifiers
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      // Attempt to report without proper role
      await expect(
        derivativesReporter.connect(investor).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWith(TEST_CONSTANTS.ERROR_NOT_REPORTER);
    });
  });
});