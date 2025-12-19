# How to Bridge ETH to Arbitrum Nova

## Quick Overview

Arbitrum Nova is a separate Layer 2 network. You need to bridge ETH from Ethereum mainnet (or another chain) to Nova to pay for gas fees.

---

## Option 1: Official Arbitrum Bridge (Recommended)

### Step 1: Visit the Bridge
Go to: **https://bridge.arbitrum.io/**

### Step 2: Connect Your Wallet
- Click "Connect Wallet"
- Select MetaMask (or your preferred wallet)
- Approve the connection

### Step 3: Select Networks
- **From:** Ethereum Mainnet (or Arbitrum One if you have ETH there)
- **To:** Arbitrum Nova

### Step 4: Enter Amount
- Enter the amount of ETH to bridge (Adsco77 will send you ~$10 worth)
- The bridge will show:
  - Estimated gas fees
  - Time to complete (~10-15 minutes)

### Step 5: Confirm Transaction
- Click "Move funds to Arbitrum Nova"
- Approve the transaction in your wallet
- Wait for confirmation

### Step 6: Verify
- Switch your MetaMask network to Arbitrum Nova
- Check your balance

---

## Option 2: Third-Party Bridges (Faster, Slightly Higher Fees)

### Stargate Finance
- URL: https://stargate.finance/
- Supports multiple chains → Arbitrum Nova
- Usually faster (5-10 minutes)
- Slightly higher fees

### Synapse Protocol
- URL: https://synapseprotocol.com/
- Multi-chain support
- Good for smaller amounts

---

## Adding Arbitrum Nova to MetaMask

If Nova doesn't appear in your network list:

### Manual Setup:
1. Open MetaMask
2. Click network dropdown → "Add Network"
3. Click "Add a network manually"
4. Enter these details:

```
Network Name: Arbitrum Nova
RPC URL: https://nova.arbitrum.io/rpc
Chain ID: 42170
Currency Symbol: ETH
Block Explorer: https://nova.arbiscan.io/
```

5. Click "Save"

### Or Use Chainlist:
1. Go to: https://chainlist.org/
2. Search "Arbitrum Nova"
3. Click "Connect Wallet"
4. Click "Add to MetaMask"

---

## Cost Estimates

**Bridging Cost:**
- From Ethereum mainnet: ~$5-15 in gas fees (depends on Ethereum congestion)
- From Arbitrum One: ~$0.50-2

**Deployment & Testing on Nova:**
- Contract deployment: ~$2-5
- Integration testing: ~$5-8
- **Total budget: ~$10 should cover it**

---

## After Bridging Checklist

- [ ] ETH received in Nova wallet
- [ ] MetaMask switched to Arbitrum Nova network
- [ ] Balance shows correctly
- [ ] Ready to deploy contracts

---

## Troubleshooting

**Q: Bridge transaction is taking too long?**
A: Ethereum → Nova can take 10-15 minutes. Check transaction on Etherscan.

**Q: Don't see bridged ETH in wallet?**
A: Make sure MetaMask is switched to Arbitrum Nova network (Chain ID 42170).

**Q: Transaction failed?**
A: Check you had enough ETH for gas fees on the source chain.

**Q: Need help?**
A: Contact Adsco77 or check Arbitrum Discord: https://discord.gg/arbitrum

---

## Ready to Deploy?

Once ETH is in your Nova wallet, follow: **URIEL_DEPLOYMENT_GUIDE.md**
