import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("🚀 Starting Arbitrum One Deployment...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📍 Deploying from account:", deployer.address);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "ETH\n");

  // Deploy SecurityToken
  console.log("📝 Deploying SecurityToken...");
  const SecurityToken = await ethers.getContractFactory("SecurityToken");
  const securityToken = await SecurityToken.deploy(
    "DPO Security Token",
    "DPOST",
    ethers.parseEther("1000000") // 1M tokens
  );
  await securityToken.waitForDeployment();
  const tokenAddress = await securityToken.getAddress();
  console.log("✅ SecurityToken deployed to:", tokenAddress);

  // Deploy ComplianceRegistry
  console.log("\n📝 Deploying ComplianceRegistry*
