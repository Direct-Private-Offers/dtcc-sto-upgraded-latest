\# DPOSVG Deployment Checklist



\## ✅ Pre-Deployment Setup



\### 1. QuickNode Endpoints

\- \[ ] Created Arbitrum Sepolia endpoint

\- \[ ] Created Arbitrum One endpoint (for mainnet later)

\- \[ ] Copied HTTP URLs to `.env`



\### 2. Wallets \& Keys

\- \[ ] Deployer wallet created

\- \[ ] Private key added to `.env`

\- \[ ] Testnet ETH obtained (Sepolia)

\- \[ ] Mainnet ETH ready (for production)



\### 3. Gnosis Safe

\- \[ ] Safe created on Arbitrum Sepolia

\- \[ ] Signers added (Corporation + Transfer Agent)

\- \[ ] Threshold set (2-of-2 recommended)

\- \[ ] Safe address added to `.env`



\### 4. API Keys

\- \[ ] Arbiscan API key obtained

\- \[ ] API key added to `.env`



\### 5. Repository

\- \[ ] Code pulled from GitHub

\- \[ ] Dependencies installed (`npm install`)

\- \[ ] Contracts compiled (`npx hardhat compile`)

\- \[ ] Tests passing (`npx hardhat test`)



\## 🧪 Testnet Deployment (Sepolia)



\### Deploy

```bash

npm run deploy:test

```



\### Verify

```bash

npx hardhat verify --network arbitrumSepolia <CONTRACT\_ADDRESS> \[CONSTRUCTOR\_ARGS]

```



\### Test

\- \[ ] Contract verified on Arbiscan

\- \[ ] Token name/symbol correct

\- \[ ] Gnosis Safe has correct roles

\- \[ ] Add test investor to whitelist

\- \[ ] Issue test tokens

\- \[ ] Check balance

\- \[ ] Test transfer



\## 🚀 Mainnet Deployment (Arbitrum One)



\### Pre-Flight

\- \[ ] All tests passed on Sepolia

\- \[ ] No critical issues found

\- \[ ] Team approval obtained

\- \[ ] Deployer wallet has sufficient ETH



\### Deploy

```bash

npm run deploy

```



\### Post-Deployment

\- \[ ] Contract verified on Arbiscan

\- \[ ] All addresses saved

\- \[ ] Master Notebook updated

\- \[ ] Railway Django updated

\- \[ ] Documentation updated

\- \[ ] Team notified



\## 📋 Contract Addresses



\### Testnet (Sepolia)

\- DPOSVG Token: `0x...`

\- LEI Registry: `0x...`

\- UPI Provider: `0x...`

\- Trade Repository: `0x...`

\- Gnosis Safe: `0x...`



\### Mainnet (Arbitrum One)

\- DPOSVG Token: `0x...`

\- LEI Registry: `0x...`

\- UPI Provider: `0x...`

\- Trade Repository: `0x...`

\- Gnosis Safe: `0x...`



\## 🆘 Emergency Contacts



\- QuickNode Support: support@quicknode.com

\- Gnosis Safe Support: https://help.safe.global/

\- Arbiscan Support: https://arbiscan.io/contactus



\## 📚 Resources



\- \[Arbitrum Docs](https://docs.arbitrum.io/)

\- \[Hardhat Docs](https://hardhat.org/docs)

\- \[Gnosis Safe Docs](https://docs.safe.global/)

\- \[QuickNode Docs](https://www.quicknode.com/docs)

