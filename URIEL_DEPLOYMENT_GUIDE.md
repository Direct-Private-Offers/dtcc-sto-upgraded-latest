# Uriel's Deployment Instructions - Nova Mainnet

## Understanding the Two Separate Efforts

**1. DPOToken (Adsco77's team is handling this):**
- Simple ERC-20 test token
- Deploying to 0G mainnet
- NOT your concern right now

**2. Your Smart Contract Ecosystem (YOU are deploying this):**
- DTCCCompliantSTO.sol
- ForexPSPIntegration.sol
- PSPNEOBankOrchestrator.sol
- Euroclear/Clearstream bridges
- All your work from THIS repo (dtcc-sto-upgraded-latest)

---

## Your Workflow: 3 Steps

### Step 1: Run Hardhat Tests **LOCALLY** (No blockchain needed)

```bash
# In THIS directory (dtcc-sto-upgraded-latest)
npm install

# Run tests on LOCAL Hardhat network (built-in blockchain simulator)
npx hardhat test
```

**Answer to "What blockchain should I execute hardhat tests on?"**
→ **None.** Hardhat tests run on a LOCAL simulated blockchain that spins up automatically. No deployment, no gas costs, no real network.

---

### Step 2: Deploy YOUR Contracts to Nova Mainnet

After local tests pass, deploy to Nova:

```bash
# Deploy to Arbitrum Nova mainnet
npx hardhat run scripts/deploy.js --network arbitrum_nova
```

**This is where you need the $10 USD of ETH:**
- For deploying contracts (gas fees)
- For testing contract interactions
- All on **Arbitrum Nova mainnet** (cheap gas, real-world conditions)

---

### Step 3: Test on Nova Mainnet

After deployment, test your deployed contracts:

```bash
# Run integration tests against deployed contracts
npx hardhat run scripts/test-deployed.js --network arbitrum_nova
```

**Budget:**
- $10 covers deployment + substantial testing
- Do as much testing as budget allows
- Document any incomplete test coverage

---

## Hardhat Config Setup

Check your hardhat.config.ts and ensure Arbitrum Nova network is configured:

```typescript
networks: {
  arbitrum_nova: {
    url: 'https://nova.arbitrum.io/rpc',
    chainId: 42170,
    accounts: [process.env.PRIVATE_KEY]  // Your wallet private key
  }
}
```

---

## Summary

| Phase | What | Where | Cost |
|-------|------|-------|------|
| **1. Local Tests** | Hardhat unit tests | Local computer | $0 |
| **2. Deployment** | Deploy your contracts | Nova mainnet | ~$2-5 |
| **3. Testing** | Integration tests | Nova mainnet | ~$5-8 |

**You are NOT waiting for anyone to deploy anything. You deploy YOUR contracts yourself.**

---

## Questions Answered

**Q: 'Where do I deploy to test, before I send to you?'**
A: Deploy to **Arbitrum Nova mainnet**. Test there. That's the end - nothing to 'send' to anyone.

**Q: 'How do I test on nova mainnet when it is not deployed?'**
A: YOU deploy it. You have the code. You have the ETH (incoming). You deploy YOUR contracts.

**Q: 'What blockchain should I execute the hard hat tests on?'**
A: Local Hardhat network (automatic, free, no setup needed). Then deploy to Nova.

---

## What You Need From Adsco77

1. Your Arbitrum Nova wallet address
2. $10 USD worth of ETH bridged to Nova (he's sending this)
3. Your GitHub access confirmed (you already have this repo)

## What Adsco77 Needs From You

1. Deployed contract addresses on Nova (after you deploy)
2. Testing results
3. Any issues encountered

**You own this. You deploy. You test. You report back.**
