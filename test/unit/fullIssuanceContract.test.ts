import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { FullIssuanceContract } from "../typechain-types";

describe("FullIssuanceContract", function () {
  let contract: FullIssuanceContract;
  let issuer: SignerWithAddress;
  let complianceOfficer: SignerWithAddress;
  let settlementOperator: SignerWithAddress;
  let investor1: SignerWithAddress;
  let investor2: SignerWithAddress;

  const identifiers = {
    isin: "US0378331005",
    lei: "549300EXAMPLELEI001",
    upi: "UPISWAP00001",
    cusip: "037833100",
    clearstreamId: "CLSTM12345",
    euroclearId: "EURCL98765",
    internalAssetId: "DPO-2024-001",
  };

  const offeringConfig = {
    offeringType: "REG_D_506C",
    maxRaiseAmount: ethers.parseUnits("5000000", 18), // 5M
    lockupPeriod: 7776000, // 90 days in seconds
    startTimestamp: Math.floor(Date.now() / 1000),
    endTimestamp: Math.floor(Date.now() / 1000) + 2592000, // 30 days
    baseCurrency: "USD",
  };

  const documents = {
    termSheetCid: "QmTermSheet123",
    offeringMemorandumCid: "QmMemorandum456",
    subscriptionAgreementCid: "QmSubscriptionAgreement789",
    kycPolicyCid: "QmKYCPolicy012",
  };

  beforeEach(async function () {
    [issuer, complianceOfficer, settlementOperator, investor1, investor2] =
      await ethers.getSigners();

    const FullIssuanceContractFactory =
      await ethers.getContractFactory("FullIssuanceContract");

    // Deploy with a mock compliance module (address(0) for no compliance checks)
    contract = (await FullIssuanceContractFactory.deploy(
      issuer.address,
      complianceOfficer.address,
      settlementOperator.address,
      identifiers,
      offeringConfig,
      documents,
      ethers.ZeroAddress // No compliance module for now
    )) as FullIssuanceContract;

    await contract.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should initialize with correct roles", async function () {
      expect(await contract.issuer()).to.equal(issuer.address);
      expect(await contract.complianceOfficer()).to.equal(
        complianceOfficer.address
      );
      expect(await contract.settlementOperator()).to.equal(
        settlementOperator.address
      );
    });

    it("Should initialize with correct identifiers", async function () {
      const storedIdentifiers = await contract.identifiers();
      expect(storedIdentifiers.isin).to.equal(identifiers.isin);
      expect(storedIdentifiers.lei).to.equal(identifiers.lei);
      expect(storedIdentifiers.upi).to.equal(identifiers.upi);
    });

    it("Should initialize with correct offering config", async function () {
      const storedConfig = await contract.offeringConfig();
      expect(storedConfig.offeringType).to.equal(offeringConfig.offeringType);
      expect(storedConfig.maxRaiseAmount).to.equal(
        offeringConfig.maxRaiseAmount
      );
      expect(storedConfig.lockupPeriod).to.equal(offeringConfig.lockupPeriod);
      expect(storedConfig.baseCurrency).to.equal(offeringConfig.baseCurrency);
    });

    it("Should not be finalized initially", async function () {
      expect(await contract.finalized()).to.be.false;
    });
  });

  describe("Investor Whitelisting", function () {
    it("Should allow compliance officer to whitelist investor", async function () {
      const jurisdiction = ethers.encodeBytes32String("US");

      await expect(
        contract
          .connect(complianceOfficer)
          .whitelistInvestor(investor1.address, jurisdiction, true, true)
      ).to.emit(contract, "InvestorWhitelisted");

      const position = await contract.getInvestorPosition(investor1.address);
      expect(position.kycPassed).to.be.true;
      expect(position.amlPassed).to.be.true;
      expect(position.jurisdiction).to.equal(jurisdiction);
    });

    it("Should revert if non-compliance officer tries to whitelist", async function () {
      const jurisdiction = ethers.encodeBytes32String("US");

      await expect(
        contract
          .connect(investor1)
          .whitelistInvestor(investor1.address, jurisdiction, true, true)
      ).to.be.revertedWith("NOT_COMPLIANCE");
    });

    it("Should allow partial KYC/AML passes", async function () {
      const jurisdiction = ethers.encodeBytes32String("US");

      await contract
        .connect(complianceOfficer)
        .whitelistInvestor(investor1.address, jurisdiction, true, false);

      const position = await contract.getInvestorPosition(investor1.address);
      expect(position.kycPassed).to.be.true;
      expect(position.amlPassed).to.be.false;
    });
  });

  describe("Commitment Recording", function () {
    beforeEach(async function () {
      const jurisdiction = ethers.encodeBytes32String("US");
      await contract
        .connect(complianceOfficer)
        .whitelistInvestor(investor1.address, jurisdiction, true, true);
    });

    it("Should record commitment for whitelisted investor", async function () {
      const amount = ethers.parseUnits("100000", 18); // 100K

      await expect(
        contract
          .connect(settlementOperator)
          .recordCommitment(investor1.address, amount, "USD", "REF-001")
      ).to.emit(contract, "CommitmentRecorded");

      const position = await contract.getInvestorPosition(investor1.address);
      expect(position.committedAmount).to.equal(amount);
    });

    it("Should reject commitment if offering window is closed", async function () {
      // Create a config with past endTimestamp
      const pastEndTime = Math.floor(Date.now() / 1000) - 1000;
      const newConfig = {
        ...offeringConfig,
        endTimestamp: pastEndTime,
      };

      await contract.connect(issuer).updateOfferingConfig(newConfig);

      const amount = ethers.parseUnits("100000", 18);
      await expect(
        contract
          .connect(settlementOperator)
          .recordCommitment(investor1.address, amount, "USD", "REF-002")
      ).to.be.revertedWithCustomError(contract, "NotInOfferingWindow");
    });

    it("Should reject commitment with wrong currency", async function () {
      const amount = ethers.parseUnits("100000", 18);

      await expect(
        contract
          .connect(settlementOperator)
          .recordCommitment(investor1.address, amount, "EUR", "REF-003")
      ).to.be.revertedWith("CURRENCY_MISMATCH");
    });

    it("Should reject commitment if max raise exceeded", async function () {
      const maxRaise = ethers.parseUnits("5000000", 18); // 5M
      const overageAmount = ethers.parseUnits("5000001", 18);

      await expect(
        contract
          .connect(settlementOperator)
          .recordCommitment(investor1.address, overageAmount, "USD", "REF-004")
      ).to.be.revertedWithCustomError(contract, "MaxRaiseExceeded");
    });
  });

  describe("Units Issuance", function () {
    beforeEach(async function () {
      const jurisdiction = ethers.encodeBytes32String("US");
      await contract
        .connect(complianceOfficer)
        .whitelistInvestor(investor1.address, jurisdiction, true, true);

      const amount = ethers.parseUnits("100000", 18);
      await contract
        .connect(settlementOperator)
        .recordCommitment(investor1.address, amount, "USD", "REF-005");
    });

    it("Should issue units to investor", async function () {
      const units = ethers.parseUnits("1000", 18);

      await expect(
        contract.connect(settlementOperator).issueUnits(investor1.address, units)
      ).to.emit(contract, "UnitsIssued");

      const position = await contract.getInvestorPosition(investor1.address);
      expect(position.unitsIssued).to.equal(units);
    });

    it("Should set correct lockup release time", async function () {
      const units = ethers.parseUnits("1000", 18);
      const txBlock = await ethers.provider.getBlockNumber();
      const txTimestamp = (await ethers.provider.getBlock(txBlock))?.timestamp || 0;

      await contract.connect(settlementOperator).issueUnits(investor1.address, units);

      const position = await contract.getInvestorPosition(investor1.address);
      const expectedRelease = txTimestamp + offeringConfig.lockupPeriod;
      expect(position.lockupRelease).to.be.approximately(expectedRelease, 2);
    });

    it("Should revert if investor has not passed KYC/AML", async function () {
      const jurisdiction = ethers.encodeBytes32String("GB");
      await contract
        .connect(complianceOfficer)
        .whitelistInvestor(investor2.address, jurisdiction, false, true);

      const amount = ethers.parseUnits("50000", 18);
      await contract
        .connect(settlementOperator)
        .recordCommitment(investor2.address, amount, "USD", "REF-006");

      const units = ethers.parseUnits("500", 18);
      await expect(
        contract
          .connect(settlementOperator)
          .issueUnits(investor2.address, units)
      ).to.be.revertedWith("KYC/AML_NOT_PASSED");
    });

    it("Should track total units issued", async function () {
      const units1 = ethers.parseUnits("1000", 18);
      const units2 = ethers.parseUnits("500", 18);

      await contract.connect(settlementOperator).issueUnits(investor1.address, units1);

      const jurisdiction = ethers.encodeBytes32String("GB");
      await contract
        .connect(complianceOfficer)
        .whitelistInvestor(investor2.address, jurisdiction, true, true);

      const amount = ethers.parseUnits("50000", 18);
      await contract
        .connect(settlementOperator)
        .recordCommitment(investor2.address, amount, "USD", "REF-007");

      await contract
        .connect(settlementOperator)
        .issueUnits(investor2.address, units2);

      const totalIssued = await contract.totalUnitsIssued();
      expect(totalIssued).to.equal(units1 + units2);
    });
  });

  describe("Settlement Recording", function () {
    it("Should record settlement event", async function () {
      const units = ethers.parseUnits("1000", 18);

      await expect(
        contract
          .connect(settlementOperator)
          .recordSettlement(
            investor1.address,
            units,
            "CLEARSTREAM",
            "CLSTM-REF-12345"
          )
      ).to.emit(contract, "SettlementRecorded");
    });

    it("Should allow multiple settlement system records", async function () {
      const units = ethers.parseUnits("1000", 18);

      await contract
        .connect(settlementOperator)
        .recordSettlement(
          investor1.address,
          units,
          "CLEARSTREAM",
          "CLSTM-REF-001"
        );

      await contract
        .connect(settlementOperator)
        .recordSettlement(investor1.address, units, "EUROCLEAR", "EURCL-REF-001");

      // Both should emit without reverting
      expect(true).to.be.true;
    });
  });

  describe("Offering Finalization", function () {
    it("Should allow issuer to finalize offering", async function () {
      await expect(contract.connect(issuer).finalizeOffering()).to.emit(
        contract,
        "Finalized"
      );

      expect(await contract.finalized()).to.be.true;
    });

    it("Should revert if non-issuer tries to finalize", async function () {
      await expect(
        contract.connect(investor1).finalizeOffering()
      ).to.be.revertedWith("NOT_ISSUER");
    });

    it("Should prevent updates after finalization", async function () {
      await contract.connect(issuer).finalizeOffering();

      const newConfig = { ...offeringConfig };
      await expect(
        contract.connect(issuer).updateOfferingConfig(newConfig)
      ).to.be.revertedWithCustomError(contract, "AlreadyFinalized");
    });
  });

  describe("Lockup Helpers", function () {
    beforeEach(async function () {
      const jurisdiction = ethers.encodeBytes32String("US");
      await contract
        .connect(complianceOfficer)
        .whitelistInvestor(investor1.address, jurisdiction, true, true);

      const amount = ethers.parseUnits("100000", 18);
      await contract
        .connect(settlementOperator)
        .recordCommitment(investor1.address, amount, "USD", "REF-008");

      const units = ethers.parseUnits("1000", 18);
      await contract
        .connect(settlementOperator)
        .issueUnits(investor1.address, units);
    });

    it("Should indicate investor is in lockup", async function () {
      const inLockup = await contract.isInLockup(investor1.address);
      expect(inLockup).to.be.true;
    });

    it("Should eventually exit lockup after period", async function () {
      // Skip time beyond lockup period
      const lockupPeriod = offeringConfig.lockupPeriod;
      await ethers.provider.send("evm_increaseTime", [lockupPeriod + 1]);
      await ethers.provider.send("evm_mine", []);

      const inLockup = await contract.isInLockup(investor1.address);
      expect(inLockup).to.be.false;
    });
  });

  describe("Document Management", function () {
    it("Should allow issuer to update documents", async function () {
      const newDocs = {
        termSheetCid: "QmNewTermSheet",
        offeringMemorandumCid: "QmNewMemorandum",
        subscriptionAgreementCid: "QmNewSubscriptionAgreement",
        kycPolicyCid: "QmNewKYCPolicy",
      };

      await expect(
        contract.connect(issuer).updateDocuments(newDocs)
      ).to.emit(contract, "DocumentsUpdated");

      const storedDocs = await contract.documents();
      expect(storedDocs.termSheetCid).to.equal(newDocs.termSheetCid);
    });

    it("Should prevent document updates after finalization", async function () {
      await contract.connect(issuer).finalizeOffering();

      const newDocs = { ...documents };
      await expect(
        contract.connect(issuer).updateDocuments(newDocs)
      ).to.be.revertedWithCustomError(contract, "AlreadyFinalized");
    });
  });
});
