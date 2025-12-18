/**
 * Event Listener Runner
 * Starts the issuance event listener and forwards events to Django backend
 */

import { startIssuanceEventListener } from "./issuance_event_listener";
import * as dotenv from "dotenv";

dotenv.config();

const QUICKNODE_RPC = process.env.RPC_URL || "https://nova.arbitrum.io/rpc";
const CONTRACT_ADDRESS = process.env.ISSUANCE_CONTRACT_ADDRESS || "";
const INGESTION_URL = process.env.INGESTION_URL || "http://localhost:8000/ingest/";

// Minimal ABI for events
const ABI = [
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "issuer", type: "address" },
      { indexed: true, name: "complianceOfficer", type: "address" },
      { indexed: true, name: "settlementOperator", type: "address" }
    ],
    name: "RolesConfigured",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        components: [
          { name: "offeringType", type: "string" },
          { name: "maxRaiseAmount", type: "uint256" },
          { name: "lockupPeriod", type: "uint256" },
          { name: "startTimestamp", type: "uint256" },
          { name: "endTimestamp", type: "uint256" },
          { name: "baseCurrency", type: "string" }
        ],
        indexed: false,
        name: "config",
        type: "tuple"
      },
      {
        components: [
          { name: "isin", type: "string" },
          { name: "lei", type: "string" },
          { name: "upi", type: "string" },
          { name: "cusip", type: "string" },
          { name: "clearstreamId", type: "string" },
          { name: "euroclearId", type: "string" },
          { name: "internalAssetId", type: "string" }
        ],
        indexed: false,
        name: "identifiers",
        type: "tuple"
      }
    ],
    name: "OfferingConfigured",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "investor", type: "address" },
      { indexed: false, name: "jurisdiction", type: "bytes32" },
      { indexed: false, name: "kycPassed", type: "bool" },
      { indexed: false, name: "amlPassed", type: "bool" }
    ],
    name: "InvestorWhitelisted",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "investor", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "currency", type: "string" },
      { indexed: false, name: "paymentRef", type: "string" }
    ],
    name: "CommitmentRecorded",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "investor", type: "address" },
      { indexed: false, name: "units", type: "uint256" },
      { indexed: false, name: "lockupRelease", type: "uint256" },
      { indexed: false, name: "isin", type: "string" },
      { indexed: false, name: "lei", type: "string" },
      { indexed: false, name: "upi", type: "string" }
    ],
    name: "UnitsIssued",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "investor", type: "address" },
      { indexed: false, name: "units", type: "uint256" },
      { indexed: false, name: "settlementSystem", type: "string" },
      { indexed: false, name: "externalRef", type: "string" }
    ],
    name: "SettlementRecorded",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      { indexed: false, name: "totalCommitted", type: "uint256" },
      { indexed: false, name: "totalUnitsIssued", type: "uint256" },
      { indexed: false, name: "timestamp", type: "uint256" }
    ],
    name: "Finalized",
    type: "event"
  }
];

async function main() {
  if (!CONTRACT_ADDRESS) {
    console.error("Error: ISSUANCE_CONTRACT_ADDRESS not set in environment");
    process.exit(1);
  }

  console.log("Starting event listener...");
  console.log(`RPC: ${QUICKNODE_RPC}`);
  console.log(`Contract: ${CONTRACT_ADDRESS}`);
  console.log(`Ingestion URL: ${INGESTION_URL}`);

  await startIssuanceEventListener(
    QUICKNODE_RPC,
    CONTRACT_ADDRESS,
    ABI,
    INGESTION_URL
  );

  // Keep process running
  console.log("Listener running. Press Ctrl+C to exit.");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
