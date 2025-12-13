import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

/**
 * Event Listener for FullIssuanceContract
 * Monitors and logs all events emitted by the issuance contract
 */

interface IssuanceEventListener {
  contractAddress: string;
  startBlock?: number;
  onEvent?: (event: any) => void;
  onError?: (error: Error) => void;
}

class IssuanceContractMonitor {
  private contract: ethers.Contract;
  private provider: ethers.Provider;
  private listeners: Map<string, ethers.ContractEventName> = new Map();

  constructor(
    contractAddress: string,
    providerUrl?: string
  ) {
    this.provider = providerUrl
      ? new ethers.JsonRpcProvider(providerUrl)
      : ethers.provider;

    // ABI for FullIssuanceContract events
    const abi = [
      "event RolesConfigured(address indexed issuer, address indexed complianceOfficer, address indexed settlementOperator)",
      "event OfferingConfigured(tuple(string offeringType, uint256 maxRaiseAmount, uint256 lockupPeriod, uint256 startTimestamp, uint256 endTimestamp, string baseCurrency) config, tuple(string isin, string lei, string upi, string cusip, string clearstreamId, string euroclearId, string internalAssetId) identifiers)",
      "event DocumentsUpdated(tuple(string termSheetCid, string offeringMemorandumCid, string subscriptionAgreementCid, string kycPolicyCid) docs)",
      "event InvestorWhitelisted(address indexed investor, bytes32 jurisdiction, bool kycPassed, bool amlPassed)",
      "event CommitmentRecorded(address indexed investor, uint256 amount, string currency, string paymentRef)",
      "event UnitsIssued(address indexed investor, uint256 units, uint256 lockupRelease, string isin, string lei, string upi)",
      "event SettlementRecorded(address indexed investor, uint256 units, string settlementSystem, string externalRef)",
      "event Finalized(uint256 totalCommitted, uint256 totalUnitsIssued, uint256 timestamp)",
    ];

    this.contract = new ethers.Contract(contractAddress, abi, this.provider);
  }

  /**
   * Start listening to all issuance contract events
   */
  async startListening(options: { onEvent?: (event: any) => void; onError?: (error: Error) => void } = {}) {
    console.log("🎧 Starting event listener for FullIssuanceContract...");
    console.log("📍 Contract:", await this.contract.getAddress());
    console.log("");

    try {
      // RolesConfigured
      this.contract.on("RolesConfigured", (issuer, complianceOfficer, settlementOperator, event) => {
        const eventData = {
          event: "RolesConfigured",
          timestamp: new Date().toISOString(),
          blockNumber: event.log.blockNumber,
          transactionHash: event.log.transactionHash,
          data: {
            issuer,
            complianceOfficer,
            settlementOperator,
          },
        };
        this.logEvent(eventData);
        options.onEvent?.(eventData);
      });

      // OfferingConfigured
      this.contract.on("OfferingConfigured", (config, identifiers, event) => {
        const eventData = {
          event: "OfferingConfigured",
          timestamp: new Date().toISOString(),
          blockNumber: event.log.blockNumber,
          transactionHash: event.log.transactionHash,
          data: {
            config: {
              offeringType: config.offeringType,
              maxRaiseAmount: config.maxRaiseAmount.toString(),
              lockupPeriod: config.lockupPeriod.toString(),
              startTimestamp: config.startTimestamp.toString(),
              endTimestamp: config.endTimestamp.toString(),
              baseCurrency: config.baseCurrency,
            },
            identifiers: {
              isin: identifiers.isin,
              lei: identifiers.lei,
              upi: identifiers.upi,
              cusip: identifiers.cusip,
              clearstreamId: identifiers.clearstreamId,
              euroclearId: identifiers.euroclearId,
              internalAssetId: identifiers.internalAssetId,
            },
          },
        };
        this.logEvent(eventData);
        options.onEvent?.(eventData);
      });

      // InvestorWhitelisted
      this.contract.on("InvestorWhitelisted", (investor, jurisdiction, kycPassed, amlPassed, event) => {
        const eventData = {
          event: "InvestorWhitelisted",
          timestamp: new Date().toISOString(),
          blockNumber: event.log.blockNumber,
          transactionHash: event.log.transactionHash,
          data: {
            investor,
            jurisdiction: ethers.decodeBytes32String(jurisdiction),
            kycPassed,
            amlPassed,
          },
        };
        this.logEvent(eventData);
        options.onEvent?.(eventData);
      });

      // CommitmentRecorded
      this.contract.on("CommitmentRecorded", (investor, amount, currency, paymentRef, event) => {
        const eventData = {
          event: "CommitmentRecorded",
          timestamp: new Date().toISOString(),
          blockNumber: event.log.blockNumber,
          transactionHash: event.log.transactionHash,
          data: {
            investor,
            amount: amount.toString(),
            currency,
            paymentRef,
          },
        };
        this.logEvent(eventData);
        options.onEvent?.(eventData);
      });

      // UnitsIssued
      this.contract.on("UnitsIssued", (investor, units, lockupRelease, isin, lei, upi, event) => {
        const eventData = {
          event: "UnitsIssued",
          timestamp: new Date().toISOString(),
          blockNumber: event.log.blockNumber,
          transactionHash: event.log.transactionHash,
          data: {
            investor,
            units: units.toString(),
            lockupRelease: lockupRelease.toString(),
            lockupReleaseDate: new Date(Number(lockupRelease) * 1000).toISOString(),
            isin,
            lei,
            upi,
          },
        };
        this.logEvent(eventData);
        options.onEvent?.(eventData);
      });

      // SettlementRecorded
      this.contract.on("SettlementRecorded", (investor, units, settlementSystem, externalRef, event) => {
        const eventData = {
          event: "SettlementRecorded",
          timestamp: new Date().toISOString(),
          blockNumber: event.log.blockNumber,
          transactionHash: event.log.transactionHash,
          data: {
            investor,
            units: units.toString(),
            settlementSystem,
            externalRef,
          },
        };
        this.logEvent(eventData);
        options.onEvent?.(eventData);
      });

      // Finalized
      this.contract.on("Finalized", (totalCommitted, totalUnitsIssued, timestamp, event) => {
        const eventData = {
          event: "Finalized",
          timestamp: new Date().toISOString(),
          blockNumber: event.log.blockNumber,
          transactionHash: event.log.transactionHash,
          data: {
            totalCommitted: totalCommitted.toString(),
            totalUnitsIssued: totalUnitsIssued.toString(),
            finalizedAt: new Date(Number(timestamp) * 1000).toISOString(),
          },
        };
        this.logEvent(eventData);
        options.onEvent?.(eventData);
      });

      console.log("✅ Event listeners registered successfully");
      console.log("📡 Monitoring for events...");
    } catch (error) {
      console.error("❌ Error starting event listeners:", error);
      options.onError?.(error as Error);
      throw error;
    }
  }

  /**
   * Stop listening to events
   */
  async stopListening() {
    console.log("🛑 Stopping event listeners...");
    await this.contract.removeAllListeners();
    console.log("✅ Event listeners stopped");
  }

  /**
   * Query historical events
   */
  async queryHistoricalEvents(fromBlock: number = 0, toBlock: number | string = "latest") {
    console.log(`📜 Querying historical events from block ${fromBlock} to ${toBlock}...`);

    const events = await this.contract.queryFilter("*", fromBlock, toBlock);
    
    console.log(`Found ${events.length} events`);
    
    return events.map((event) => ({
      event: event.fragment.name,
      blockNumber: event.blockNumber,
      transactionHash: event.transactionHash,
      args: event.args,
    }));
  }

  /**
   * Log event to console (can be extended to write to database/file)
   */
  private logEvent(eventData: any) {
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log(`📢 Event: ${eventData.event}`);
    console.log(`⏰ Timestamp: ${eventData.timestamp}`);
    console.log(`🔢 Block: ${eventData.blockNumber}`);
    console.log(`🔗 TX: ${eventData.transactionHash}`);
    console.log("📦 Data:", JSON.stringify(eventData.data, null, 2));
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  }
}

// CLI execution
async function main() {
  const contractAddress = process.env.ISSUANCE_CONTRACT_ADDRESS || process.argv[2];
  const providerUrl = process.env.RPC_URL;

  if (!contractAddress) {
    console.error("❌ Error: Contract address not provided");
    console.log("Usage: npx hardhat run monitoring/listeners/issuance_event_listener.ts --network <network>");
    console.log("Or set ISSUANCE_CONTRACT_ADDRESS in .env");
    process.exit(1);
  }

  const monitor = new IssuanceContractMonitor(contractAddress, providerUrl);

  // Handle graceful shutdown
  process.on("SIGINT", async () => {
    console.log("\n🛑 Shutting down gracefully...");
    await monitor.stopListening();
    process.exit(0);
  });

  await monitor.startListening({
    onEvent: (event) => {
      // Custom event handler (e.g., send to webhook, database, etc.)
      // console.log("Custom handler:", event);
    },
    onError: (error) => {
      console.error("Event listener error:", error);
    },
  });

  // Keep the script running
  await new Promise(() => {});
}

// Only run main if executed directly
if (require.main === module) {
  main().catch((error) => {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  });
}

export { IssuanceContractMonitor };
