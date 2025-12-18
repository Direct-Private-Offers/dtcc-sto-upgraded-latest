import { ethers } from "ethers";
import axios from "axios";

export async function startIssuanceEventListener(
  rpcUrl: string,
  contractAddress: string,
  abi: any,
  ingestionUrl: string
) {
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const contract = new ethers.Contract(contractAddress, abi, provider);

  async function forwardToBackend(eventName: string, args: any, event: any) {
    const payload = {
      event: eventName,
      ...args,
      blockNumber: event.log.blockNumber,
      transaction_hash: event.log.transactionHash,
      timestamp: Date.now()
    };

    try {
      await axios.post(ingestionUrl, payload);
      console.log(`[OK] ${eventName} forwarded`);
    } catch (err) {
      console.error(`[ERROR] Failed to forward ${eventName}`, err);
    }
  }

  const events = [
    "OfferingConfigured",
    "InvestorWhitelisted",
    "CommitmentRecorded",
    "UnitsIssued",
    "SettlementRecorded",
    "Finalized"
  ];

  events.forEach((eventName) => {
    contract.on(eventName, async (...rawArgs: any[]) => {
      const event = rawArgs[rawArgs.length - 1];
      const args = event.args;
      await forwardToBackend(eventName, args, event);
    });
  });

  console.log("Issuance event listener started");
}
