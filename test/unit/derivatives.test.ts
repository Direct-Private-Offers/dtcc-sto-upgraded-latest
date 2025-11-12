import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import {
  createTestDerivativeData,
  createTestCounterparty,
  createTestCollateralData,
  createTestValuationData,
  generateTestLEI,
  generateTestUPI,
  generateTestUTI
} from '../helpers/testUtils';

describe('Derivatives - Unit Tests', function () {
  async function deployFixture() {
    const [owner, issuer, complianceOfficer, derivativesReporter, investor1, investor2] = await ethers.getSigners();

    // Deploy mocks
    const MockLEIRegistry = await ethers.getContractFactory("MockLEIRegistry");
    const leiRegistry = await MockLEIRegistry.deploy();
    
    const MockUPIProvider = await ethers.getContractFactory("MockUPIProvider");
    const upiProvider = await MockUPIProvider.deploy();
    
    const MockTradeRepository = await ethers.getContractFactory("MockTradeRepository");
    const tradeRepository = await MockTradeRepository.deploy();

    // Deploy main contract
    const DTCCCompliantSTO = await ethers.getContractFactory("DTCCCompliantSTO");
    const sto = await DTCCCompliantSTO.deploy(
      "TestSecurityToken",
      "TST",
      ethers.parseEther("1000000"),
      90 * 24 * 60 * 60,
      0, // REG_D_506B
      await leiRegistry.getAddress(),
      await upiProvider.getAddress(),
      await tradeRepository.getAddress()
    );

    // Setup roles
    await sto.grantRole(await sto.ISSUER_ROLE(), issuer.address);
    await sto.grantRole(await sto.COMPLIANCE_OFFICER(), complianceOfficer.address);
    await sto.grantRole(await sto.DERIVATIVES_REPORTER(), derivativesReporter.address);

    return { 
      sto, 
      leiRegistry, 
      upiProvider, 
      tradeRepository, 
      owner, 
      issuer, 
      complianceOfficer,
      derivativesReporter, 
      investor1, 
      investor2 
    };
  }

  describe('Derivative Reporting', function () {
    it('should report a new derivative successfully', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ 
        walletAddress: derivativesReporter.address,
        jurisdiction: "CA-ON"
      });
      const counterparty2 = createTestCounterparty({ 
        walletAddress: investor1.address,
        isReporting: false,
        jurisdiction: "US-NY"
      });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register identifiers
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.emit(sto, "DerivativeReported");

      // Verify derivative was stored
      const storedDerivative = await sto.derivatives(derivativeData.uti);
      expect(storedDerivative.uti).to.equal(derivativeData.uti);
    });

    it('should reject invalid LEI', async function () {
      const { sto, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register only UPI, not LEI
      await upiProvider.registerUPI(derivativeData.upi);

      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWithCustomError(sto, "InvalidLEI");
    });

    it('should reject invalid UPI', async function () {
      const { sto, leiRegistry, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register only LEIs, not UPI
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);

      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWithCustomError(sto, "InvalidUPI");
    });

    it('should reject duplicate UTI', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      // Register identifiers
      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      // First report should succeed
      await sto.connect(derivativesReporter).reportDerivative(
        derivativeData,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      // Second report with same UTI should fail
      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWithCustomError(sto, "DerivativeAlreadyReported");
    });

    it('should reject invalid date ranges', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const now = await time.latest();
      const derivativeData = createTestDerivativeData({
        effectiveDate: now + 1000,
        expirationDate: now // Expiration before effective
      });
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWithCustomError(sto, "InvalidDate");
    });

    it('should reject invalid notional amount', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData({
        notionalAmount: 0 // Invalid zero amount
      });
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWithCustomError(sto, "InvalidNotionalAmount");
    });

    it('should handle batch derivative reporting', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1, investor2 } = await loadFixture(deployFixture);

      const derivativesData: ReturnType<typeof createTestDerivativeData>[] = [];
      const counterparties1: ReturnType<typeof createTestCounterparty>[] = [];
      const counterparties2: ReturnType<typeof createTestCounterparty>[] = [];
      const collateralDataArray: ReturnType<typeof createTestCollateralData>[] = [];
      const valuationDataArray: ReturnType<typeof createTestValuationData>[] = [];

      for (let i = 0; i < 3; i++) {
        const derivativeData = createTestDerivativeData({
          uti: generateTestUTI()
        });
        const counterparty1 = createTestCounterparty({ 
          walletAddress: derivativesReporter.address,
          lei: generateTestLEI()
        });
        const counterparty2 = createTestCounterparty({ 
          walletAddress: i % 2 === 0 ? investor1.address : investor2.address,
          lei: generateTestLEI(),
          isReporting: false
        });

        // Register identifiers
        await leiRegistry.registerLEI(counterparty1.lei, true);
        await leiRegistry.registerLEI(counterparty2.lei, true);
        await upiProvider.registerUPI(derivativeData.upi);

        derivativesData.push(derivativeData);
        counterparties1.push(counterparty1);
        counterparties2.push(counterparty2);
        collateralDataArray.push(createTestCollateralData());
        valuationDataArray.push(createTestValuationData());
      }

      // Report batch derivatives
      await expect(
        sto.connect(derivativesReporter).batchReportDerivatives(
          derivativesData,
          counterparties1,
          counterparties2,
          collateralDataArray,
          valuationDataArray
        )
      ).to.not.be.reverted;

      // Verify all derivatives were reported
      for (const derivativeData of derivativesData) {
        const storedDerivative = await sto.derivatives(derivativeData.uti);
        expect(storedDerivative.uti).to.equal(derivativeData.uti);
      }
    });

    it('should reject batch reporting with mismatched array lengths', async function () {
      const { sto, derivativesReporter } = await loadFixture(deployFixture);

      const derivativesData = [createTestDerivativeData()];
      const counterparties1 = [createTestCounterparty()];
      const counterparties2 = [createTestCounterparty(), createTestCounterparty()]; // Mismatch
      const collateralDataArray = [createTestCollateralData()];
      const valuationDataArray = [createTestValuationData()];

      await expect(
        sto.connect(derivativesReporter).batchReportDerivatives(
          derivativesData,
          counterparties1,
          counterparties2,
          collateralDataArray,
          valuationDataArray
        )
      ).to.be.revertedWithCustomError(sto, "InvalidInput");
    });

    it('should reject batch reporting exceeding limit', async function () {
      const { sto, derivativesReporter } = await loadFixture(deployFixture);

      const largeArray = [];
      const counterparties1 = [];
      const counterparties2 = [];
      const collateralDataArray = [];
      const valuationDataArray = [];

      for (let i = 0; i < 21; i++) {
        largeArray.push(createTestDerivativeData());
        counterparties1.push(createTestCounterparty());
        counterparties2.push(createTestCounterparty());
        collateralDataArray.push(createTestCollateralData());
        valuationDataArray.push(createTestValuationData());
      }

      await expect(
        sto.connect(derivativesReporter).batchReportDerivatives(
          largeArray as any,
          counterparties1 as any,
          counterparties2 as any,
          collateralDataArray as any,
          valuationDataArray as any
        )
      ).to.be.revertedWithCustomError(sto, "InvalidInput");
    });
  });

  describe('Derivative Corrections', function () {
    it('should correct an existing derivative', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      // Report initial derivative
      await sto.connect(derivativesReporter).reportDerivative(
        derivativeData,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      // Correct the derivative
      const priorUti = generateTestUTI();
      const correctedData = createTestDerivativeData({
        uti: derivativeData.uti,
        notionalAmount: ethers.parseEther("2000000") // Corrected amount
      });

      await expect(
        sto.connect(derivativesReporter).correctDerivative(
          derivativeData.uti,
          priorUti,
          correctedData
        )
      ).to.emit(sto, "DerivativeCorrected");

      // Verify correction was stored
      const corrections = await sto.getDerivativeCorrections(derivativeData.uti);
      expect(corrections.length).to.equal(1);
      expect(corrections[0].priorUti).to.equal(priorUti);
    });

    it('should reject correction for non-existent derivative', async function () {
      const { sto, derivativesReporter } = await loadFixture(deployFixture);
      
      const nonExistentUTI = generateTestUTI();
      const priorUti = generateTestUTI();
      const correctedData = createTestDerivativeData({ uti: nonExistentUTI });

      await expect(
        sto.connect(derivativesReporter).correctDerivative(
          nonExistentUTI,
          priorUti,
          correctedData
        )
      ).to.be.revertedWithCustomError(sto, "DerivativeNotFound");
    });
  });

  describe('Error Reporting', function () {
    it('should report errors for existing derivatives', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await sto.connect(derivativesReporter).reportDerivative(
        derivativeData,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      const errorReason = "Incorrect notional amount reported";
      await expect(
        sto.connect(derivativesReporter).reportError(derivativeData.uti, errorReason)
      ).to.emit(sto, "ErrorReported");

      // Verify error was stored
      const errors = await sto.getDerivativeErrors(derivativeData.uti);
      expect(errors.length).to.equal(1);
      expect(errors[0].reason).to.equal(errorReason);
    });

    it('should reject error reporting for non-existent derivatives', async function () {
      const { sto, derivativesReporter } = await loadFixture(deployFixture);
      
      const nonExistentUTI = generateTestUTI();
      const errorReason = "Test error";

      await expect(
        sto.connect(derivativesReporter).reportError(nonExistentUTI, errorReason)
      ).to.be.revertedWithCustomError(sto, "DerivativeNotFound");
    });

    it('should reject error reporting with empty reason', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await sto.connect(derivativesReporter).reportDerivative(
        derivativeData,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      await expect(
        sto.connect(derivativesReporter).reportError(derivativeData.uti, "")
      ).to.be.revertedWithCustomError(sto, "InvalidInput");
    });
  });

  describe('Position Reporting', function () {
    it('should report a position successfully', async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      // First create underlying derivatives
      const derivativeData1 = createTestDerivativeData({ uti: generateTestUTI() });
      const derivativeData2 = createTestDerivativeData({ uti: generateTestUTI() });
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData1.upi);
      await upiProvider.registerUPI(derivativeData2.upi);

      await sto.connect(derivativesReporter).reportDerivative(
        derivativeData1,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      await sto.connect(derivativesReporter).reportDerivative(
        derivativeData2,
        counterparty1,
        counterparty2,
        collateralData,
        valuationData
      );

      // Report position
      const positionId = generateTestUTI();
      const underlyingUtis = [derivativeData1.uti, derivativeData2.uti];
      const positionValuation = createTestValuationData();

      await expect(
        sto.connect(derivativesReporter).reportPosition(
          positionId,
          underlyingUtis,
          positionValuation
        )
      ).to.emit(sto, "PositionReported");

      // Verify position was stored
      const position = await sto.getPosition(positionId);
      expect(position.positionId).to.equal(positionId);
      expect(position.underlyingUtis.length).to.equal(2);
    });

    it('should reject position with non-existent underlying derivative', async function () {
      const { sto, derivativesReporter } = await loadFixture(deployFixture);
      
      const positionId = generateTestUTI();
      const nonExistentUTI = generateTestUTI();
      const underlyingUtis = [nonExistentUTI];
      const positionValuation = createTestValuationData();

      await expect(
        sto.connect(derivativesReporter).reportPosition(
          positionId,
          underlyingUtis,
          positionValuation
        )
      ).to.be.revertedWithCustomError(sto, "InvalidUnderlyingDerivative");
    });
  });

  describe('Access Control', function () {
    it('should reject unauthorized derivative reporting', async function () {
      const { sto, leiRegistry, upiProvider, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: investor1.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await expect(
        sto.connect(investor1).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.reverted;
    });

    it('should respect pause functionality', async function () {
      const { sto, leiRegistry, upiProvider, complianceOfficer, derivativesReporter, investor1 } = await loadFixture(deployFixture);
      
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ walletAddress: derivativesReporter.address });
      const counterparty2 = createTestCounterparty({ walletAddress: investor1.address });
      const collateralData = createTestCollateralData();
      const valuationData = createTestValuationData();

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      // Pause contract
      await sto.connect(complianceOfficer).pause();

      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.be.revertedWithCustomError(sto, "EnforcedPause");

      // Unpause
      await sto.connect(complianceOfficer).unpause();

      // Should work now
      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.emit(sto, "DerivativeReported");
    });
  });
});