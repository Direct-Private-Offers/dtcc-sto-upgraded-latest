\# 🚀 Arbitrum One Deployment Checklist



\## Pre-Deployment Setup



\### 1. Environment Configuration

\- \[ ] `.env` file created with required variables:

&nbsp; - \[ ] `PRIVATE\_KEY` - Deployer wallet private key

&nbsp; - \[ ] `ARBITRUM\_RPC\_URL` - Arbitrum One RPC endpoint

&nbsp; - \[ ] `ARBISCAN\_API\_KEY` - For contract verification



\### 2. Account Preparation

\- \[ ] Deployer wallet has sufficient ETH on Arbitrum One

&nbsp; - Recommended: 0.05 ETH minimum

\- \[ ] Deployer address verified and secure

\- \[ ] Private key stored securely (never committed to git)



\### 3. Contract Review

\- \[ ] All contracts compiled successfully (`npx hardhat compile`)

\- \[ ] Unit tests passing (`npx hardhat test`)

\- \[ ] Contract parameters reviewed:

&nbsp; - \[ ] Token name: "DPO Security Token"

&nbsp; - \[ ] Token symbol: "DPOST"

&nbsp; - \[ ] Initial supply: 1,000,000 tokens



---



\## Deployment Steps



\### 4. Run Deployment

```bash

npx hardhat run scripts/deploy-sepolia-simple.ts --network arbitrumOne

```



\- \[ ] Deployment script executed successfully

\- \[ ] All three contracts deployed:

&nbsp; - \[ ] SecurityToken

&nbsp; - \[ ] ComplianceRegistry

&nbsp; - \[ ] IssuanceContract



\### 5. Record Contract Addresses

\- \[ ] SecurityToken address: `\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_`

\- \[ ] ComplianceRegistry address: `\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_`

\- \[ ] IssuanceContract address: `\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_`

\- \[ ] Addresses saved to `.env` file

\- \[ ] Addresses backed up securely



---



\## Post-Deployment Verification



\### 6. Contract Verification on Arbiscan

```bash

npx hardhat verify --network arbitrumOne <CONTRACT\_ADDRESS> <CONSTRUCTOR\_ARGS>

```



\- \[ ] SecurityToken verified

\- \[ ] ComplianceRegistry verified

\- \[ ] IssuanceContract verified



\### 7. Functional Testing

\- \[ ] Token metadata correct (name, symbol, decimals)

\- \[ ] ComplianceRegistry accessible

\- \[ ] IssuanceContract linked to SecurityToken

\- \[ ] Test transaction successful



\### 8. Security Checks

\- \[ ] Contract ownership verified

\- \[ ] Admin roles assigned correctly

\- \[ ] No unauthorized access possible

\- \[ ] Emergency pause function tested (if applicable)



---



\## Documentation \& Handoff



\### 9. Update Documentation

\- \[ ] Contract addresses added to `README.md`

\- \[ ] Deployment date and network recorded

\- \[ ] ABI files exported and saved

\- \[ ] Integration guide updated



\### 10. Team Notification

\- \[ ] DT notified of deployment

\- \[ ] Contract addresses shared with team

\- \[ ] Arbiscan links provided

\- \[ ] Next steps communicated



---



\## Emergency Contacts



\- \*\*Deployer\*\*: Adsco1727

\- \*\*Network\*\*: Arbitrum One (Chain ID: 42161)

\- \*\*Block Explorer\*\*: https://arbiscan.io/

\- \*\*RPC Issues\*\*: Check https://chainlist.org/chain/42161



---



\## Notes



\- Deployment Date: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

\- Deployer Address: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

\- Gas Used: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

\- Total Cost (ETH): \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_



\*\*Status\*\*: \[ ] In Progress  \[ ] Complete  \[ ] Failed



---



\*Last Updated: 2026-02-18\*

