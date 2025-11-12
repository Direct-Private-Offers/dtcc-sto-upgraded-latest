import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { TEST_CONSTANTS } from "../helpers/constants";

describe("SecurityToken - Unit Tests", function () {
  async function deployTokenFixture() {
    const [owner, issuer, complianceOfficer, investor1, investor2] = await ethers.getSigners();

    // Deploy mocks
    const MockLEIRegistry = await ethers.getContractFactory("MockLEIRegistry");
    const leiRegistry = await MockLEIRegistry.deploy();
    
    const MockUPIProvider = await ethers.getContractFactory("MockUPIProvider");
    const upiProvider = await MockUPIProvider.deploy();
    
    const MockTradeRepository = await ethers.getContractFactory("MockTradeRepository");
    const tradeRepository = await MockTradeRepository.deploy();

    // Deploy main contract
    const DTCCCompliantSTO = await ethers.getContractFactory("DTCCCompliantSTO");
    const token = await DTCCCompliantSTO.deploy(
      TEST_CONSTANTS.TOKEN_NAME,
      TEST_CONSTANTS.TOKEN_SYMBOL,
      ethers.parseEther(TEST_CONSTANTS.INITIAL_SUPPLY),
      TEST_CONSTANTS.DEFAULT_LOCKUP,
      0, // REG_D_506B
      await leiRegistry.getAddress(),
      await upiProvider.getAddress(),
      await tradeRepository.getAddress()
    );

    // Setup roles
    await token.grantRole(await token.ISSUER_ROLE(), issuer.address);
    await token.grantRole(await token.COMPLIANCE_OFFICER(), complianceOfficer.address);

    return { token, owner, issuer, complianceOfficer, investor1, investor2 };
  }

  describe("Token Issuance", function () {
    it("Should issue tokens successfully", async function () {
      const { token, issuer, investor1 } = await loadFixture(deployTokenFixture);

      const amount = ethers.parseEther("1000");
      const ipfsCID = "QmExampleIPFSCID";
      const lockupPeriod = 30 * 24 * 60 * 60;

      await expect(
        token.connect(issuer).issueTokens(
          investor1.address,
          amount,
          ipfsCID,
          lockupPeriod
        )
      ).to.emit(token, "IssuanceRecorded");

      expect(await token.balanceOf(investor1.address)).to.equal(amount);
    });

    it("Should enforce transfer locks", async function () {
      const { token, issuer, complianceOfficer, investor1, investor2 } = await loadFixture(deployTokenFixture);

      const amount = ethers.parseEther("1000");
      const ipfsCID = "QmExampleIPFSCID";
      const lockupPeriod = 7 * 24 * 60 * 60; // 7 days

      // Issue tokens with lockup
      await token.connect(issuer).issueTokens(
        investor1.address,
        amount,
        ipfsCID,
        lockupPeriod
      );

      // Verify investors for transfer
      await token.connect(complianceOfficer).verifyInvestor(
        investor1.address,
        "https://kyc-provider.com/verify",
        false
      );
      await token.connect(complianceOfficer).verifyInvestor(
        investor2.address,
        "https://kyc-provider.com/verify",
        false
      );

      // Try to transfer during lockup period
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(token, "TokensLocked");

      // Fast forward past lockup period
      await time.increase(lockupPeriod + 1);

      // Transfer should now succeed
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.not.be.reverted;
    });

    it("Should allow compliance officer to override locks", async function () {
      const { token, issuer, complianceOfficer, investor1, investor2 } = await loadFixture(deployTokenFixture);

      const amount = ethers.parseEther("1000");
      const ipfsCID = "QmExampleIPFSCID";
      const lockupPeriod = 7 * 24 * 60 * 60;

      // Issue tokens with lockup
      await token.connect(issuer).issueTokens(
        investor1.address,
        amount,
        ipfsCID,
        lockupPeriod
      );

      // Compliance officer should be able to override lock
      await expect(
        token.connect(complianceOfficer).setTransferLock(investor1.address, 0)
      ).to.emit(token, "TransferLockUpdated");

      // Transfer should now succeed despite original lockup
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.not.be.reverted;
    });
  });

  describe("Investor Verification", function () {
    it("Should enforce KYC verification for transfers", async function () {
      const { token, issuer, complianceOfficer, investor1, investor2 } = await loadFixture(deployTokenFixture);

      const amount = ethers.parseEther("1000");
      const ipfsCID = "QmExampleIPFSCID";
      const lockupPeriod = 0; // No lockup

      // Issue tokens to non-verified investor
      await token.connect(issuer).issueTokens(
        investor1.address,
        amount,
        ipfsCID,
        lockupPeriod
      );

      // Verify investor2 for receiving
      await token.connect(complianceOfficer).verifyInvestor(
        investor2.address,
        "https://kyc-provider.com/verify",
        false
      );

      // Transfer should fail due to lack of verification of sender
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(token, "NotVerified");

      // Verify investor
      await token.connect(complianceOfficer).verifyInvestor(
        investor1.address,
        "https://kyc-provider.com/verify",
        false
      );

      // Transfer should now succeed
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.not.be.reverted;
    });
  });
});