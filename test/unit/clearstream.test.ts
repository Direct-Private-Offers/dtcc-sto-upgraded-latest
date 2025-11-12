import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { 
  generateTestLEI, 
  generateTestUPI, 
  generateTestUTI,
  createTestDerivativeData, 
  createTestCounterparty,
  createTestCollateralData,
  createTestValuationData,
  TEST_CONSTANTS 
} from "../helpers/testUtils.js";

describe("DTCCCompliantSTO - Clearstream Integration Tests", function () {
  async function deployClearstreamFixture() {
    const [owner, compliance, issuer, qibVerifier, derivativesReporter, clearstreamOperator, investor1, investor2] = await ethers.getSigners();

    const MockLEIRegistry = await ethers.getContractFactory("MockLEIRegistry");
    const leiRegistry = await MockLEIRegistry.deploy();
    
    const MockUPIProvider = await ethers.getContractFactory("MockUPIProvider");
    const upiProvider = await MockUPIProvider.deploy();
    
    const MockTradeRepository = await ethers.getContractFactory("MockTradeRepository");
    const tradeRepository = await MockTradeRepository.deploy();

    const DTCCCompliantSTO = await ethers.getContractFactory("DTCCCompliantSTO");
    const dtccSto = await DTCCCompliantSTO.deploy(
      "DPO Global Token",
      "DPOSVG",
      ethers.parseEther("1000000"),
      90 * 24 * 60 * 60, // 90 days lockup
      1, // REG_D_506C
      await leiRegistry.getAddress(),
      await upiProvider.getAddress(),
      await tradeRepository.getAddress(),
      "US0000000000",
      {
        defaultCsdAccount: "0x434c45415253545245414d5f4353445f414343",
        settlementCycle: 2, // T+2
        autoSettlementEnabled: true,
        minSettlementAmount: ethers.parseEther("1000"),
        marketIdentifier: "XOFF",
        operatingCsd: "0x434c45415253545245414d5f4353445f414343"
      }
    );

    // Grant roles
    await dtccSto.grantRole(await dtccSto.COMPLIANCE_OFFICER(), compliance.address);
    await dtccSto.grantRole(await dtccSto.ISSUER_ROLE(), issuer.address);
    await dtccSto.grantRole(await dtccSto.QIB_VERIFIER(), qibVerifier.address);
    await dtccSto.grantRole(await dtccSto.DERIVATIVES_REPORTER(), derivativesReporter.address);
    await dtccSto.grantRole(await dtccSto.CLEARSTREAM_OPERATOR(), clearstreamOperator.address);

    return { 
      dtccSto, 
      leiRegistry, 
      upiProvider, 
      tradeRepository, 
      owner, 
      compliance, 
      issuer, 
      qibVerifier, 
      derivativesReporter, 
      clearstreamOperator, 
      investor1, 
      investor2 
    };
  }

  describe("Clearstream Account Management", function () {
    it("Should link investor to Clearstream CSD account", async function () {
      const { dtccSto, clearstreamOperator, investor1 } = await loadFixture(deployClearstreamFixture);
      
      const csdAccount = "0x746573745f6373645f6163636f756e74313233"; // test_csd_account123

      await expect(
        dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, csdAccount)
      ).to.emit(dtccSto, "ClearstreamAccountLinked");
    });

    it("Should reject linking zero address", async function () {
      const { dtccSto, clearstreamOperator } = await loadFixture(deployClearstreamFixture);
      
      const csdAccount = "0x746573745f6373645f6163636f756e74313233";

      await expect(
        dtccSto.connect(clearstreamOperator).linkClearstreamAccount(ethers.ZeroAddress, csdAccount)
      ).to.be.revertedWith("ZeroAddress");
    });

    it("Should reject linking with zero CSD account", async function () {
      const { dtccSto, clearstreamOperator, investor1 } = await loadFixture(deployClearstreamFixture);
      
      await expect(
        dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, "0x0000000000000000000000000000000000000000")
      ).to.be.revertedWith("InvalidInput");
    });

    it("Should reject unauthorized account linking", async function () {
      const { dtccSto, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const csdAccount = "0x746573745f6373645f6163636f756e74313233";

      await expect(
        dtccSto.connect(investor1).linkClearstreamAccount(investor2.address, csdAccount)
      ).to.be.reverted;
    });
  });

  describe("Clearstream Settlement Lifecycle", function () {
    it("Should initiate settlement successfully", async function () {
      const { dtccSto, clearstreamOperator, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const tradeReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_TRADE_001"));
      const quantity = ethers.parseEther("1000");
      const settlementAmount = ethers.parseEther("50000");
      const valueDate = (await time.latest()) + (3 * 24 * 60 * 60); // T+3

      // Link CSD accounts
      const buyerAccount = "0x62757965725f6373645f6163636f756e743132";
      const sellerAccount = "0x73656c6c65725f6373645f6163636f756e743132";
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, buyerAccount);
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor2.address, sellerAccount);

      await expect(
        dtccSto.connect(clearstreamOperator).initiateSettlement(
          tradeReference,
          investor1.address,
          investor2.address,
          quantity,
          settlementAmount,
          valueDate
        )
      ).to.emit(dtccSto, "ClearstreamSettlementInitiated");
    });

    it("Should generate settlement instructions", async function () {
      const { dtccSto, clearstreamOperator, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const tradeReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_TRADE_002"));
      const quantity = ethers.parseEther("2000");
      const settlementAmount = ethers.parseEther("100000");
      const valueDate = (await time.latest()) + (2 * 24 * 60 * 60); // T+2

      // Link CSD accounts
      const buyerAccount = "0x62757965725f6373645f6163636f756e743132";
      const sellerAccount = "0x73656c6c65725f6373645f6163636f756e743132";
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, buyerAccount);
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor2.address, sellerAccount);

      // Initiate settlement
      const tx = await dtccSto.connect(clearstreamOperator).initiateSettlement(
        tradeReference,
        investor1.address,
        investor2.address,
        quantity,
        settlementAmount,
        valueDate
      );

      const receipt = await tx.wait();
      const settlementInitiatedEvent = receipt.logs.find(log => 
        log.fragment?.name === "ClearstreamSettlementInitiated"
      );
      const settlementId = settlementInitiatedEvent?.args[0];

      // Generate instructions
      await expect(
        dtccSto.connect(clearstreamOperator).generateSettlementInstructions(settlementId)
      ).to.emit(dtccSto, "ClearstreamInstructionsGenerated");
    });

    it("Should confirm settlement completion", async function () {
      const { dtccSto, clearstreamOperator, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const tradeReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_TRADE_003"));
      const quantity = ethers.parseEther("1500");
      const settlementAmount = ethers.parseEther("75000");
      const valueDate = (await time.latest()) + (2 * 24 * 60 * 60);

      // Link CSD accounts and issue tokens
      const buyerAccount = "0x62757965725f6373645f6163636f756e743132";
      const sellerAccount = "0x73656c6c65725f6373645f6163636f756e743132";
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, buyerAccount);
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor2.address, sellerAccount);

      // Issue tokens to seller
      await dtccSto.connect(clearstreamOperator).grantRole(await dtccSto.ISSUER_ROLE(), clearstreamOperator.address);
      await dtccSto.connect(clearstreamOperator).issueTokens(
        investor2.address,
        quantity,
        "QmTestCID123456789",
        0,
        sellerAccount
      );

      // Initiate settlement and generate instructions
      const tx = await dtccSto.connect(clearstreamOperator).initiateSettlement(
        tradeReference,
        investor1.address,
        investor2.address,
        quantity,
        settlementAmount,
        valueDate
      );

      const receipt = await tx.wait();
      const settlementInitiatedEvent = receipt.logs.find(log => 
        log.fragment?.name === "ClearstreamSettlementInitiated"
      );
      const settlementId = settlementInitiatedEvent?.args[0];

      await dtccSto.connect(clearstreamOperator).generateSettlementInstructions(settlementId);

      const instructionReference = ethers.keccak256(ethers.toUtf8Bytes("CSD_INSTRUCTION_REF_001"));

      // Confirm settlement
      await expect(
        dtccSto.connect(clearstreamOperator).confirmSettlement(settlementId, instructionReference)
      ).to.emit(dtccSto, "ClearstreamSettlementConfirmed");
    });

    it("Should complete settlement lifecycle", async function () {
      const { dtccSto, clearstreamOperator, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const tradeReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_TRADE_004"));
      const quantity = ethers.parseEther("3000");
      const settlementAmount = ethers.parseEther("150000");
      const valueDate = (await time.latest()) + (2 * 24 * 60 * 60);

      // Link CSD accounts and issue tokens
      const buyerAccount = "0x62757965725f6373645f6163636f756e743132";
      const sellerAccount = "0x73656c6c65725f6373645f6163636f756e743132";
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, buyerAccount);
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor2.address, sellerAccount);

      // Issue tokens to seller
      await dtccSto.connect(clearstreamOperator).grantRole(await dtccSto.ISSUER_ROLE(), clearstreamOperator.address);
      await dtccSto.connect(clearstreamOperator).issueTokens(
        investor2.address,
        quantity,
        "QmTestCID123456789",
        0,
        sellerAccount
      );

      // Complete settlement lifecycle
      const tx = await dtccSto.connect(clearstreamOperator).initiateSettlement(
        tradeReference,
        investor1.address,
        investor2.address,
        quantity,
        settlementAmount,
        valueDate
      );

      const receipt = await tx.wait();
      const settlementInitiatedEvent = receipt.logs.find(log => 
        log.fragment?.name === "ClearstreamSettlementInitiated"
      );
      const settlementId = settlementInitiatedEvent?.args[0];

      await dtccSto.connect(clearstreamOperator).generateSettlementInstructions(settlementId);

      const instructionReference = ethers.keccak256(ethers.toUtf8Bytes("CSD_INSTRUCTION_REF_002"));
      await dtccSto.connect(clearstreamOperator).confirmSettlement(settlementId, instructionReference);

      // Complete settlement
      await expect(
        dtccSto.connect(clearstreamOperator).completeSettlement(settlementId)
      ).to.emit(dtccSto, "ClearstreamSettlementCompleted");
    });
  });

  describe("Clearstream Position Management", function () {
    it("Should update positions after token issuance", async function () {
      const { dtccSto, issuer, clearstreamOperator, investor1 } = await loadFixture(deployClearstreamFixture);
      
      const csdAccount = "0x696e766573746f72315f6373645f616363";
      const issuanceAmount = ethers.parseEther("5000");

      // Link CSD account
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, csdAccount);

      // Issue tokens
      await expect(
        dtccSto.connect(issuer).issueTokens(
          investor1.address,
          issuanceAmount,
          "QmTestIssuanceCID123",
          0,
          csdAccount
        )
      ).to.emit(dtccSto, "ClearstreamPositionUpdated");
    });

    it("Should get Clearstream position for CSD account", async function () {
      const { dtccSto, issuer, clearstreamOperator, investor1 } = await loadFixture(deployClearstreamFixture);
      
      const csdAccount = "0x696e766573746f72315f6373645f616363";
      const issuanceAmount = ethers.parseEther("10000");

      // Link CSD account and issue tokens
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, csdAccount);
      await dtccSto.connect(issuer).issueTokens(
        investor1.address,
        issuanceAmount,
        "QmTestIssuanceCID456",
        0,
        csdAccount
      );

      // Get position
      const position = await dtccSto.connect(clearstreamOperator).getClearstreamPosition(csdAccount);
      
      expect(position.position).to.equal(issuanceAmount);
      expect(position.availableBalance).to.equal(issuanceAmount);
      expect(position.participantAccount).to.equal(csdAccount);
    });

    it("Should update positions after settlement", async function () {
      const { dtccSto, clearstreamOperator, issuer, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const buyerAccount = "0x62757965725f6373645f6163636f756e743132";
      const sellerAccount = "0x73656c6c65725f6373645f6163636f756e743132";
      const transferAmount = ethers.parseEther("2000");

      // Link CSD accounts and issue tokens to seller
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, buyerAccount);
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor2.address, sellerAccount);
      
      await dtccSto.connect(clearstreamOperator).grantRole(await dtccSto.ISSUER_ROLE(), clearstreamOperator.address);
      await dtccSto.connect(clearstreamOperator).issueTokens(
        investor2.address,
        transferAmount,
        "QmTestIssuanceCID789",
        0,
        sellerAccount
      );

      // Complete settlement
      const tradeReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_TRADE_POSITION"));
      const settlementAmount = ethers.parseEther("100000");
      const valueDate = (await time.latest()) + (2 * 24 * 60 * 60);

      const tx = await dtccSto.connect(clearstreamOperator).initiateSettlement(
        tradeReference,
        investor1.address,
        investor2.address,
        transferAmount,
        settlementAmount,
        valueDate
      );

      const receipt = await tx.wait();
      const settlementInitiatedEvent = receipt.logs.find(log => 
        log.fragment?.name === "ClearstreamSettlementInitiated"
      );
      const settlementId = settlementInitiatedEvent?.args[0];

      await dtccSto.connect(clearstreamOperator).generateSettlementInstructions(settlementId);

      const instructionReference = ethers.keccak256(ethers.toUtf8Bytes("CSD_INSTRUCTION_POSITION"));
      await dtccSto.connect(clearstreamOperator).confirmSettlement(settlementId, instructionReference);

      // Check positions after settlement
      const buyerPosition = await dtccSto.connect(clearstreamOperator).getClearstreamPosition(buyerAccount);
      const sellerPosition = await dtccSto.connect(clearstreamOperator).getClearstreamPosition(sellerAccount);

      expect(buyerPosition.position).to.equal(transferAmount);
      expect(sellerPosition.position).to.equal(0);
    });
  });

  describe("Clearstream Configuration", function () {
    it("Should update Clearstream configuration", async function () {
      const { dtccSto, clearstreamOperator } = await loadFixture(deployClearstreamFixture);
      
      const newConfig = {
        defaultCsdAccount: "0x6e65775f6373645f6163636f756e745f303132",
        settlementCycle: 1, // T+1
        autoSettlementEnabled: false,
        minSettlementAmount: ethers.parseEther("500"),
        marketIdentifier: "XNAS",
        operatingCsd: "0x6e65775f6373645f6163636f756e745f303132"
      };

      await expect(
        dtccSto.connect(clearstreamOperator).updateClearstreamConfig(newConfig)
      ).to.emit(dtccSto, "ClearstreamConfigUpdated");
    });

    it("Should add ISIN to whitelist", async function () {
      const { dtccSto, clearstreamOperator } = await loadFixture(deployClearstreamFixture);
      
      const newISIN = "US0378331005"; // Apple Inc.

      await expect(
        dtccSto.connect(clearstreamOperator).addISINToWhitelist(newISIN)
      ).to.emit(dtccSto, "ISINWhitelisted");
    });

    it("Should reject invalid ISIN whitelisting", async function () {
      const { dtccSto, clearstreamOperator } = await loadFixture(deployClearstreamFixture);
      
      const invalidISIN = "";

      await expect(
        dtccSto.connect(clearstreamOperator).addISINToWhitelist(invalidISIN)
      ).to.be.revertedWith("InvalidInput");
    });
  });

  describe("Error Conditions", function () {
    it("Should reject settlement without CSD accounts", async function () {
      const { dtccSto, clearstreamOperator, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const tradeReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_TRADE_ERROR"));
      const quantity = ethers.parseEther("1000");
      const settlementAmount = ethers.parseEther("50000");
      const valueDate = (await time.latest()) + (2 * 24 * 60 * 60);

      await expect(
        dtccSto.connect(clearstreamOperator).initiateSettlement(
          tradeReference,
          investor1.address,
          investor2.address,
          quantity,
          settlementAmount,
          valueDate
        )
      ).to.be.revertedWith("NoClearstreamAccount");
    });

    it("Should reject settlement with invalid value date", async function () {
      const { dtccSto, clearstreamOperator, investor1, investor2 } = await loadFixture(deployClearstreamFixture);
      
      const tradeReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_TRADE_INVALID_DATE"));
      const quantity = ethers.parseEther("1000");
      const settlementAmount = ethers.parseEther("50000");
      const invalidValueDate = (await time.latest()) - (1 * 24 * 60 * 60); // Past date

      // Link CSD accounts
      const buyerAccount = "0x62757965725f6373645f6163636f756e743132";
      const sellerAccount = "0x73656c6c65725f6373645f6163636f756e743132";
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor1.address, buyerAccount);
      await dtccSto.connect(clearstreamOperator).linkClearstreamAccount(investor2.address, sellerAccount);

      await expect(
        dtccSto.connect(clearstreamOperator).initiateSettlement(
          tradeReference,
          investor1.address,
          investor2.address,
          quantity,
          settlementAmount,
          invalidValueDate
        )
      ).to.be.revertedWith("InvalidDate");
    });

    it("Should reject confirmation for non-existent settlement", async function () {
      const { dtccSto, clearstreamOperator } = await loadFixture(deployClearstreamFixture);
      
      const nonExistentSettlementId = ethers.keccak256(ethers.toUtf8Bytes("NON_EXISTENT_SETTLEMENT"));
      const instructionReference = ethers.keccak256(ethers.toUtf8Bytes("TEST_INSTRUCTION"));

      await expect(
        dtccSto.connect(clearstreamOperator).confirmSettlement(nonExistentSettlementId, instructionReference)
      ).to.be.revertedWith("SettlementNotFound");
    });
  });
});