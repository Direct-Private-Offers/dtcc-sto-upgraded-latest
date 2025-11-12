import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { 
  createTestDerivativeData, 
  createTestCounterparty,
  createTestCollateralData,
  createTestValuationData,
  generateTestLEI,
  generateTestUPI
} from "../helpers/testUtils";

describe("DTCCCompliantSTO - Full Workflow Integration", function () {
  async function deployFullFixture() {
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

    // Setup all roles
    await sto.grantRole(await sto.ISSUER_ROLE(), issuer.address);
    await sto.grantRole(await sto.COMPLIANCE_OFFICER(), complianceOfficer.address);
    await sto.grantRole(await sto.DERIVATIVES_REPORTER(), derivativesReporter.address);
    await sto.grantRole(await sto.QIB_VERIFIER(), complianceOfficer.address);

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

  describe("Complete STO and Derivatives Workflow", function () {
    it("Should handle full lifecycle: token issuance + derivatives reporting + compliance", async function () {
      const { 
        sto, 
        leiRegistry, 
        upiProvider, 
        tradeRepository, 
        issuer, 
        derivativesReporter, 
        investor1, 
        investor2 
      } = await loadFixture(deployFullFixture);

      // 1. Issue security tokens
      const issuanceAmount = ethers.parseEther("1000");
      const ipfsCID = "QmExampleIPFSCID";
      const lockupPeriod = 30 * 24 * 60 * 60; // 30 days

      await expect(
        sto.connect(issuer).issueTokens(
          investor1.address,
          issuanceAmount,
          ipfsCID,
          lockupPeriod
        )
      ).to.emit(sto, "IssuanceRecorded");

      // Verify token balance
      const balance = await sto.balanceOf(investor1.address);
      expect(balance).to.equal(issuanceAmount);

      // 2. Report derivative transaction
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

      // Report derivative
      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          derivativeData,
          counterparty1,
          counterparty2,
          collateralData,
          valuationData
        )
      ).to.emit(sto, "DerivativeReported");

      // 3. Verify trade repository received the report
      const isReported = await tradeRepository.isTradeReported(derivativeData.uti);
      expect(isReported).to.be.true;

      // 4. Test error reporting and correction
      const errorReason = "Incorrect notional amount";
      await expect(
        sto.connect(derivativesReporter).reportError(derivativeData.uti, errorReason)
      ).to.emit(sto, "ErrorReported");

      // 5. Test position reporting
      const positionId = ethers.hexlify(ethers.randomBytes(32));
      const underlyingUtis = [derivativeData.uti];
      const positionValuation = createTestValuationData();

      await expect(
        sto.connect(derivativesReporter).reportPosition(
          positionId,
          underlyingUtis,
          positionValuation
        )
      ).to.emit(sto, "PositionReported");

      // 6. Verify compliance restrictions still work
      await expect(
        sto.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("Tokens are locked");

      // 7. Test compliance officer functions
      const newUnlockTime = (await time.latest()) + 7 * 24 * 60 * 60; // 1 week from now
      await expect(
        sto.connect(issuer).setTransferLock(investor1.address, newUnlockTime)
      ).to.emit(sto, "TransferLockUpdated");
    });

    it("Should handle batch derivatives reporting", async function () {
      const { sto, leiRegistry, upiProvider, derivativesReporter, investor1, investor2 } = await loadFixture(deployFullFixture);

      // Prepare multiple derivatives
      const derivativesData = [];
      const counterparties1 = [];
      const counterparties2 = [];
      const collateralDataArray = [];
      const valuationDataArray = [];

      for (let i = 0; i < 3; i++) {
        const derivativeData = createTestDerivativeData({
          uti: ethers.hexlify(ethers.randomBytes(32))
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
      for (let i = 0; i < derivativesData.length; i++) {
        await expect(
          sto.connect(derivativesReporter).reportDerivative(
            derivativesData[i],
            counterparties1[i],
            counterparties2[i],
            collateralDataArray[i],
            valuationDataArray[i]
          )
        ).to.emit(sto, "DerivativeReported");
      }

      // Verify all derivatives were reported
      for (const derivativeData of derivativesData) {
        const storedDerivative = await sto.derivatives(derivativeData.uti);
        expect(storedDerivative.uti).to.equal(derivativeData.uti);
      }
    });
  });

  describe("Cross-Functional Compliance", function () {
    it("Should enforce compliance across token and derivatives operations", async function () {
      const { sto, leiRegistry, upiProvider, complianceOfficer, derivativesReporter, investor1 } = await loadFixture(deployFullFixture);

      // 1. Issue tokens with compliance restrictions
      await sto.connect(complianceOfficer).verifyInvestor(
        investor1.address,
        "https://kyc-provider.com/verify",
        false
      );

      // 2. Report derivative involving the same investor
      const derivativeData = createTestDerivativeData();
      const counterparty1 = createTestCounterparty({ 
        walletAddress: derivativesReporter.address,
        lei: generateTestLEI()
      });
      const counterparty2 = createTestCounterparty({ 
        walletAddress: investor1.address,
        lei: generateTestLEI(),
        isReporting: false
      });

      await leiRegistry.registerLEI(counterparty1.lei, true);
      await leiRegistry.registerLEI(counterparty2.lei, true);
      await upiProvider.registerUPI(derivativeData.upi);

      await sto.connect(derivativesReporter).reportDerivative(
        derivativeData,
        counterparty1,
        counterparty2,
        createTestCollateralData(),
        createTestValuationData()
      );

      // 3. Verify compliance integration
      const derivativeInfo = await sto.derivatives(derivativeData.uti);
      expect(derivativeInfo.uti).to.equal(derivativeData.uti);

      // 4. Test that compliance restrictions affect both token and derivatives operations
      await sto.connect(complianceOfficer).pause();

      await expect(
        sto.connect(derivativesReporter).reportDerivative(
          createTestDerivativeData({ uti: ethers.hexlify(ethers.randomBytes(32)) }),
          counterparty1,
          counterparty2,
          createTestCollateralData(),
          createTestValuationData()
        )
      ).to.be.revertedWith("Pausable: paused");

      await sto.connect(complianceOfficer).unpause();
    });
  });
});