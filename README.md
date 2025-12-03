# DTCC-Compliant STO with Euroclear, Clearstream, Apache Fineract, and DPO Token Integration

A comprehensive integration between Euroclear/Clearstream securities settlement systems, Apache Fineract banking infrastructure, blockchain-based tokenization with full DTCC compliance, CSA derivatives reporting, and DPO Token funding mechanics.

## 🚨 CRITICAL UPDATE: FINTRAC → Apache Fineract Migration

**The system has been updated to integrate with Apache Fineract instead of FINTRAC.** This aligns with the architectural vision of creating a parallel microservice that integrates with banking infrastructure while maintaining independence from exchange/PSP systems.

## Overview

This project provides a complete solution for tokenizing securities from Euroclear and Clearstream settlement systems onto blockchain networks (Arbitrum Nova) while maintaining full compliance with DTCC regulations, CSA derivatives reporting, Apache Fineract banking integration, and DPO Token economic model.

## 🚀 New Features & Updates

### Apache Fineract Banking Integration
- **Client Synchronization** - Sync blockchain addresses with Fineract client IDs
- **Savings Account Management** - Automated creation of Fineract savings accounts
- **Loan Processing** - Full loan lifecycle management through Fineract
- **Ledger Sync** - Dual-ledger accounting (blockchain + Fineract)
- **Transaction Recording** - Automated recording of all significant transactions
- **Multi-currency Support** - Integration with Fineract's currency management

### Architectural Realignment
- **Parallel Microservice Architecture** - Operates independently while integrating with broader banking rails
- **Isolated Compliance Logic** - Handles compliance without relying on exchange/PSP infrastructure
- **Umbrella Architecture** - Aligns with broader Fineract ecosystem while maintaining independence

### DPO Token Funding System
- **Multi-round Funding** - Seed, Private A/B, Public rounds with different pricing
- **Whitelist System** - KYC/AML compliant investor onboarding
- **Token Economics** - $40 USD price with 13% discount, 13% annual interest, 40% profit share
- **Backing Asset Management** - Gold, silver, real estate collateral tracking
- **Profit Distribution** - Automated 40% distribution to token holders
- **Cross-chain Swaps** - DPO Global LLC integration for multi-chain operations

### Enhanced Security Features
- **Multi-signature Requirements** - 2-of-N signing for large transfers
- **Emergency Response** - Immediate halt and sanction removal capabilities
- **Advanced Compliance** - Integrated sanctions screening and risk scoring

### Corporate Actions & Dividends
- **Dividend Distribution** - Automated claim system with Fineract integration
- **Corporate Action Processing** - Stock splits, mergers, acquisitions
- **Profit Distribution Cycles** - Structured earnings distribution with dual-ledger recording

## Architecture
Euroclear API • Clearstream PMI API • Apache Fineract API • DPO Global LLC  
↕   ↕   ↕   ↕  
Vercel API Layer (Multi-System Integration & DPO Token Management)  
↕   ↕   ↕   ↕  
EuroclearBridge • ClearstreamBridge • FineractBridge • DPOGLOBALBridge  
↕   ↕   ↕   ↕  
DTCCCompliantSTO Contract (Unified with Fineract & DPO)  
↑  
Chainlink Oracles & Price Feeds  

## Smart Contracts

### Core Contracts

**DTCCCompliantSTO.sol (Enhanced)**
- ERC-1400 implementation with DPO Token economics
- CSA derivatives reporting
- Clearstream PMI integration
- Apache Fineract banking integration
- DPO Token funding mechanics
- FATF Travel Rule enforcement
- Dividend distribution
- Multi-sig enforcement
- Compliance verification
- ISIN whitelisting
- Backing asset management
- Profit distribution cycles

### New Interfaces & Libraries

- **IFineractIntegration.sol** – Apache Fineract banking interface  
- **FineractLib.sol** – Banking operations and ledger synchronization utilities  
- **FineractOracle.sol** – Chainlink-based Oracle for Fineract API integration  
- **IFineractCallback.sol** – Callback interface for Oracle responses  
- **ClearstreamLib.sol** – Post-trade management and settlement utilities  
- **IDPOToken.sol** – DPO Token funding interface  
- **DPOTokenLib.sol** – Token economics and distribution calculations  
- **ISanctionsScreening.sol** – Enhanced sanctions monitoring  
- **IStateChannels.sol** – High-frequency trading support  

---

### Enhanced Features

## Apache Fineract Integration

```solidity
// Client Synchronization
function syncClientWithFineract(
    address _client,
    string calldata _clientId,
    string calldata _officeId,
    string calldata _externalId
) external returns (bool);

// Savings Account Creation
function createFineractSavingsAccount(
    address _client,
    string calldata _savingsProductId,
    uint256 _interestRate,
    string calldata _depositType
) external returns (bytes32 savingsId);

// Loan Management
function createFineractLoan(
    address _client,
    string calldata _loanProductId,
    uint256 _principalAmount,
    uint256 _interestRate,
    uint256 _termFrequency
) external returns (bytes32 loanId);

// Ledger Synchronization
function recordFineractTransaction(
    address _client,
    uint256 _amount,
    FineractTransactionType _transactionType,
    string calldata _description,
    string calldata _paymentTypeId
) external returns (bytes32 transactionId);
```
### Clearstream PMI Integration


```solidity
// Settlement Processing
function initiateSettlement(
    string calldata _isin,
    uint256 _settlementDate,
    bytes20 _counterpartyAccount,
    uint256 _amount,
    string calldata _currency
) external returns (bytes32 settlementId);

// Position Management
function updatePosition(
    bytes20 _participantAccount,
    string calldata _isin,
    uint256 _quantityChange,
    bool _isAddition
) external returns (bytes32 positionId);

```
### DPO Token Funding

```solidity

// Investment Management
function investInDPO(uint256 _investmentAmount) external returns (bytes32 investmentId);

// Funding Rounds
function startFundingRound(
    string memory _roundName,
    uint256 _raiseTarget,
    uint256 _tokenPrice
) external;

// Backing Assets
function addBackingAsset(
    address _assetAddress,
    string memory _assetType,
    uint256 _value
) external;

// Profit Distribution
function distributeProfits(
    uint256 _totalEarnings,
    uint256 _distributionDate
) external;

```

# API Endpoints (Vercel API Layer)

---

## Euroclear Integration Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/euroclear/register-holder | Register new security holder | API Key |
| POST | /api/euroclear/deposit-securities | Deposit securities into Euroclear | API Key |
| POST | /api/euroclear/withdraw-securities | Withdraw securities from Euroclear | API Key |
| GET | /api/euroclear/holder/:holderId | Get holder details | API Key |
| GET | /api/euroclear/positions/:holderId | Get security positions | API Key |
| POST | /api/euroclear/corporate-action | Process corporate action | API Key |
| POST | /api/euroclear/transfer | Transfer securities between accounts | API Key |
| GET | /api/euroclear/transaction/:txId | Get transaction status | API Key |
| POST | /api/euroclear/settlement | Initiate settlement | API Key |
| GET | /api/euroclear/balance/:account | Get account balance | API Key |

---

## Clearstream PMI Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/clearstream/settlement/initiate | Initiate settlement | API Key + Multi-sig |
| POST | /api/clearstream/settlement/instruction | Send settlement instruction | API Key |
| POST | /api/clearstream/settlement/confirm | Confirm settlement | API Key |
| POST | /api/clearstream/settlement/complete | Complete settlement | API Key |
| POST | /api/clearstream/settlement/cancel | Cancel settlement | API Key + Multi-sig |
| POST | /api/clearstream/position/update | Update position | API Key |
| POST | /api/clearstream/corporate-action/announce | Announce corporate action | API Key + Multi-sig |
| POST | /api/clearstream/corporate-action/process | Process corporate action | API Key |
| GET | /api/clearstream/settlement/:id | Get settlement details | API Key |
| GET | /api/clearstream/position/:account/:isin | Get position details | API Key |
| GET | /api/clearstream/participant/:address | Get participant info | API Key |
| POST | /api/clearstream/participant/register | Register participant | API Key + Multi-sig |
| POST | /api/clearstream/isn/whitelist | Whitelist ISIN | API Key + Multi-sig |

---

## Apache Fineract Integration Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/fineract/sync-client | Sync blockchain address with Fineract client | API Key |
| POST | /api/fineract/create-savings-account | Create Fineract savings account | API Key |
| POST | /api/fineract/create-loan | Create Fineract loan account | API Key + Compliance |
| POST | /api/fineract/record-transaction | Record transaction in Fineract ledger | API Key |
| POST | /api/fineract/sync-transaction | Sync transaction with Fineract API | API Key |
| POST | /api/fineract/batch-sync | Batch sync multiple transactions | API Key |
| GET | /api/fineract/client/:address | Get client Fineract information | API Key |
| GET | /api/fineract/transaction/:id | Get transaction status | API Key |
| POST | /api/fineract/journal-entry | Create journal entry | API Key |
| GET | /api/fineract/accounts/:clientId | Get client accounts | API Key |
| POST | /api/fineract/disburse-loan | Disburse loan funds | API Key + Multi-sig |
| POST | /api/fineract/repay-loan | Record loan repayment | API Key |
| GET | /api/fineract/loan-status/:loanId | Get loan status | API Key |
| POST | /api/fineract/config/update | Update Fineract configuration | API Key + Admin |
| GET | /api/fineract/health | Check Fineract API health | API Key |
| POST | /api/fineract/webhook | Fineract webhook endpoint | Webhook Secret |

---

## DPO Token Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/dpo/invest | Invest in DPO tokens | API Key + KYC |
| POST | /api/dpo/whitelist | Add investor to whitelist | API Key + Compliance |
| GET | /api/dpo/stats | Get DPO token statistics | API Key |
| POST | /api/dpo/funding-round | Start new funding round | API Key + Admin |
| POST | /api/dpo/backing-assets | Add backing assets | API Key + Multi-sig |
| POST | /api/dpo/distribute-profits | Distribute profits to holders | API Key + Multi-sig |
| GET | /api/dpo/investment/:address | Get investment details | API Key |
| POST | /api/dpo/claim-dividends | Claim dividend payments | API Key |
| GET | /api/dpo/dividend-cycle/:cycleId | Get dividend cycle details | API Key |
| POST | /api/dpo/cross-chain-swap | Initiate cross-chain swap | API Key + KYC |
| GET | /api/dpo/swap-status/:swapId | Get cross-chain swap status | API Key |
| POST | /api/dpo/interlist | Interlist token on exchange | API Key + Admin |
| GET | /api/dpo/exchange-listings | Get exchange listings | API Key |
| POST | /api/dpo/emergency-halt | Emergency halt token operations | API Key + Multi-sig |
| GET | /api/dpo/backing-assets/value | Get total backing asset value | API Key |
| POST | /api/dpo/interest-payment | Make interest payment | API Key + Multi-sig |

---

## Enhanced Multi-signature Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/multisig/emergency-halt | Emergency system halt | Multi-sig Required |
| POST | /api/multisig/remove-sanction | Emergency sanction removal | Multi-sig Required |
| POST | /api/multisig/withdraw-funds | Emergency fund withdrawal | Multi-sig Required |
| POST | /api/multisig/approval/initiate | Initiate multi-sig approval | Compliance Officer |
| POST | /api/multisig/approval/sign | Sign multi-sig transaction | Approved Signer |
| GET | /api/multisig/approval/:txHash | Get approval status | API Key |
| POST | /api/multisig/add-signer | Add new signer | Multi-sig Required |
| POST | /api/multisig/remove-signer | Remove signer | Multi-sig Required |
| GET | /api/multisig/signers | Get list of signers | API Key |
| POST | /api/multisig/update-threshold | Update signature threshold | Multi-sig Required |

---

## Compliance & Sanctions Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/compliance/screen-address | Screen address for sanctions | API Key |
| POST | /api/compliance/kyc-verify | Verify KYC information | API Key + Compliance |
| GET | /api/compliance/risk/:address | Get client risk rating | API Key |
| POST | /api/compliance/record-client | Record client compliance info | API Key + Compliance |
| POST | /api/compliance/travel-rule | Implement FATF Travel Rule | API Key + Compliance |
| GET | /api/compliance/sanctions-list | Get sanctions list | API Key |
| POST | /api/compliance/add-sanction | Add address to sanctions | API Key + Compliance |
| POST | /api/compliance/remove-sanction | Remove from sanctions | API Key + Multi-sig |
| GET | /api/compliance/audit-trail/:address | Get compliance audit trail | API Key + Compliance |
| POST | /api/compliance/pep-check | Check for PEP status | API Key |

---

## Chainlink Oracle Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/oracle/request-fineract | Request Fineract data via Chainlink | API Key |
| GET | /api/oracle/status/:requestId | Get Oracle request status | API Key |
| POST | /api/oracle/price-feed | Update price feed data | Chainlink Node |
| GET | /api/oracle/price/:asset | Get current asset price | API Key |
| POST | /api/oracle/verify-signature | Verify Oracle signature | API Key |
| GET | /api/oracle/jobs | Get available Chainlink jobs | API Key |
| POST | /api/oracle/cancel-request | Cancel Oracle request | API Key |

---

## CSA Derivatives Reporting Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/csa/derivative/report | Report derivative transaction | API Key + Compliance |
| POST | /api/csa/derivative/correction | Submit correction to derivative report | API Key + Compliance |
| GET | /api/csa/derivative/:uti | Get derivative details by UTI | API Key |
| POST | /api/csa/position/update | Update derivative position | API Key |
| GET | /api/csa/position/:positionId | Get derivative position | API Key |
| POST | /api/csa/collateral/update | Update collateral requirements | API Key |
| GET | /api/csa/reports/daily | Get daily derivative reports | API Key + Compliance |
| POST | /api/csa/valuation | Request position valuation | API Key |

---

## Token Management Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/token/transfer | Transfer tokens | API Key + KYC |
| POST | /api/token/mint | Mint new tokens | API Key + Admin + Multi-sig |
| POST | /api/token/burn | Burn tokens | API Key + Admin |
| GET | /api/token/balance/:address | Get token balance | API Key |
| GET | /api/token/supply | Get token supply information | API Key |
| POST | /api/token/lock | Lock tokens for vesting | API Key + Compliance |
| POST | /api/token/unlock | Unlock vested tokens | API Key + Compliance |
| GET | /api/token/holders | Get token holder list | API Key + Compliance |
| POST | /api/token/partition | Create token partition | API Key + Compliance |
| GET | /api/token/transactions/:address | Get transaction history | API Key |

---

## System Health & Monitoring Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/health | System health check | Public |
| GET | /api/health/detailed | Detailed system health | API Key |
| GET | /api/status | System status overview | API Key |
| GET | /api/metrics | System performance metrics | API Key + Admin |
| GET | /api/logs/:service | Get service logs | API Key + Admin |
| GET | /api/version | Get API version | Public |
| GET | /api/services/status | Get all services status | API Key |

---

## Admin & Management Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/admin/config/update | Update system configuration | API Key + Admin |
| GET | /api/admin/config | Get system configuration | API Key + Admin |
| POST | /api/admin/role/assign | Assign role to address | API Key + Admin |
| POST | /api/admin/role/revoke | Revoke role from address | API Key + Admin |
| GET | /api/admin/roles/:address | Get roles for address | API Key + Admin |
| POST | /api/admin/pause | Pause system operations | API Key + Admin + Multi-sig |
| POST | /api/admin/resume | Resume system operations | API Key + Admin |
| GET | /api/admin/audit | Get admin audit log | API Key + Admin |
| POST | /api/admin/maintenance | Toggle maintenance mode | API Key + Admin + Multi-sig |
| GET | /api/admin/backup | Trigger system backup | API Key + Admin |

---

## Webhook & Notification Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/webhook/euroclear | Euroclear webhook handler | Webhook Secret |
| POST | /api/webhook/clearstream | Clearstream webhook handler | Webhook Secret |
| POST | /api/webhook/fineract | Fineract webhook handler | Webhook Secret |
| POST | /api/webhook/chainlink | Chainlink webhook handler | Webhook Secret |
| POST | /api/webhook/dpo | DPO Global webhook handler | Webhook Secret |
| POST | /api/notifications/send | Send notification | API Key |
| GET | /api/notifications/:address | Get notifications for address | API Key |
| POST | /api/notifications/subscribe | Subscribe to notifications | API Key |
| POST | /api/notifications/unsubscribe | Unsubscribe from notifications | API Key |

---

## Analytics & Reporting Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/analytics/volume/daily | Get daily transaction volume | API Key + Compliance |
| GET | /api/analytics/volume/monthly | Get monthly transaction volume | API Key + Compliance |
| GET | /api/analytics/users/active | Get active user statistics | API Key + Compliance |
| GET | /api/analytics/compliance/reports | Get compliance report statistics | API Key + Compliance |
| GET | /api/analytics/funding/rounds | Get funding round analytics | API Key + Compliance |
| GET | /api/analytics/dividends/distributed | Get dividend distribution analytics | API Key + Compliance |
| POST | /api/analytics/custom-report | Generate custom analytics report | API Key + Compliance |
| GET | /api/analytics/export/:reportType | Export analytics data | API Key + Compliance |


# Complete API Flow Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Frontend UI   │────▶│   Vercel API    │────▶│  Smart Contract │
│   (React/Next)  │◀────│    Layer        │◀────│     Layer       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   User Auth &   │     │   Service       │     │   Chainlink     │
│   Session Mgmt  │     │   Integration   │     │   Oracles       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               │
                     ┌─────────────────────────┐
                     │   External Services     │
                     │   (Fan-out Pattern)     │
                     └─────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌───────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Euroclear    │    │  Clearstream    │    │  Apache         │
│  API          │    │  PMI API        │    │  Fineract       │
└───────────────┘    └─────────────────┘    └─────────────────┘
        │                      │                      │
        ▼                      ▼                      ▼
┌───────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  DPO Global   │    │  Chainlink      │    │  Compliance     │
│  LLC API      │    │  Oracle Nodes   │    │  Databases      │
└───────────────┘    └─────────────────┘    └─────────────────┘
```

## DPO Token Economics

**Token Specifications**

* Total Supply: 125,000 DPO Tokens
* Token Price: $40 USD (with 13% discount = $34.82)
* Annual Interest: 13% paid in arrears
* Profit Share: 40% of net earnings distributed to token holders
* Company Equity: 60% retained by DPO Global LLC

**Investment Structure**

```solidity
// Example investment calculation
uint256 investment = 10000 * 10**18; // $10,000 USDC
uint256 tokens = DPOTokenLib.calculateTokenAllocation(
    investment,
    40 * 10**18, // $40 price
    13 * 10**16  // 13% discount
);
// Result: ~359 tokens allocated
```

**Backing Assets**

* Gold and silver bullion/coins held in trust
* Real estate investments
* Institutional-grade asset custody
* Real-time valuation updates

**Apache Fineract Configuration**

```javascript
// Example Fineract configuration
const fineractConfig = {
  apiBaseUrl: "https://your-fineract-instance.com/fineract-provider/api/v1",
  tenantIdentifier: "default",
  username: "admin",
  apiKeyHash: "0x...", // SHA-256 hash of API key
  syncInterval: 3600, // 1 hour in seconds
  autoSyncEnabled: true,
  defaultOfficeId: "1",
  defaultCurrencyCode: "USD",
  endpoints: {
    clients: "/clients",
    savingsAccounts: "/savingsaccounts",
    loans: "/loans",
    journalEntries: "/journalentries",
    transactions: "/transactions"
  }
};
```


## Getting Started

### Prerequisites

* Node.js 18+
* Hardhat 2.17+
* Euroclear API credentials
* Clearstream PMI credentials
* Apache Fineract instance credentials
* DPO Global LLC integration credentials
* Arbitrum Nova RPC endpoint

### Installation

```bash
git clone <repository-url>
cd dtcc-sto-upgraded
npm install
```

Create .env:

```bash
cp .env.example .env
```

Updated Environment Variables:

```bash
# Apache Fineract Integration
FINERACT_API_BASE_URL=https://your-fineract-instance.com
FINERACT_TENANT_ID=default
FINERACT_USERNAME=admin
FINERACT_API_KEY=your_fineract_api_key
FINERACT_AUTO_SYNC=true
FINERACT_SYNC_THRESHOLD=10000000000000000000 # $10

# DPO Token Configuration
DPO_TOKEN_PRICE=40000000000000000000 # $40
DPO_TOKEN_DISCOUNT=130000000000000000 # 13%
DPO_TREASURY_WALLET=0x...
DPO_MAX_RAISE=5000000000000000000000000 # $5M

# Clearstream Configuration
CLEARSTREAM_CSD_CODE=CSXXXX
CLEARSTREAM_PARTICIPANT_ID=XXXXXX
```

Compile and test:

```bash
npm run compile
npm run test
npm run test:fineract
npm run test:dpo-token
npm run test:clearstream
```

### Deployment

#### Local Development

```bash
npx hardhat node
npx hardhat run scripts/deploy.ts --network localhost
npm run test:smoke:local
```

#### Testnet (Enhanced Testing)

```bash
npm run deploy:test
npm run test:fineract:testnet
npm run test:dpo:testnet
npm run test:clearstream:testnet
```

#### Mainnet (Arbitrum Nova)

```bash
npm run deploy
npm run test:smoke:mainnet
```

### Testing Suite

```bash
# New Test Categories
npm run test:fineract          # Apache Fineract integration tests
npm run test:clearstream       # Clearstream PMI integration tests
npm run test:dpo-token         # DPO Token funding tests
npm run test:ledger-sync       # Dual-ledger synchronization tests
npm run test:backing-assets    # Asset backing tests
npm run test:profit-dist       # Profit distribution tests
npm run test:multisig          # Enhanced multi-signature tests

# Integration Testing
npm run test:integration:full  # Full system integration
REPORT_GAS=true npm run test:dpo-token # Gas optimization

# API Testing
npm run test:api:fineract      # Fineract API integration tests
npm run test:api:clearstream   # Clearstream API integration tests
```
# Security & Compliance

## Apache Fineract Integration Features

* Dual-ledger accounting system
* Real-time transaction synchronization
* Automated savings/loan account creation
* Multi-currency support
* Comprehensive audit trails
* Client risk profiling

## Clearstream PMI Features

* ISIN validation and management
* Settlement instruction processing
* Position tracking and reconciliation
* Corporate action processing
* Collateral management

## DPO Token Security

* Multi-signature fund management
* Emergency withdrawal procedures
* Backing asset verification
* Investor whitelist enforcement
* Profit distribution safeguards

## Enhanced Access Control

```solidity
// Updated roles for comprehensive management
bytes32 public constant FINERACT_OPERATOR = keccak256("FINERACT_OPERATOR");
bytes32 public constant CLEARSTREAM_OPERATOR = keccak256("CLEARSTREAM_OPERATOR");
bytes32 public constant DIVIDEND_MANAGER = keccak256("DIVIDEND_MANAGER");
bytes32 public constant FUND_MANAGER = keccak256("FUND_MANAGER");
```

## DPOI Use Case Integration (Enhanced)

* Direct Private Offers Platform
* DTCC Eligible Tokens with hybrid asset support and DPO funding
* Transfer agent compatibility with Fineract integration
* Cross-chain and DEX listing support via DPO Global LLC
* Automated smart contract execution (Airbrush MVP Phase II)
* SME capital raising with regulatory-compliant tokenization

## Business Plan Alignment

* Five revenue streams fully integrated (technology leasing, commissions, listing fees, market-making, fund collection)
* Global broker-dealer integration through DPO Global LLC
* Layer II blockchain solution on Arbitrum with cost efficiency
* Modular DEX ecosystem for SME capital formation
* Apache Fineract banking infrastructure integration

## Network Support (Updated)

| Network          | Chain ID | Use Case                             |
| ---------------- | -------- | ------------------------------------ |
| Arbitrum Nova    | 42170    | Production with Fineract Integration |
| Arbitrum Sepolia | 421614   | Staging & Testing                    |
| Hardhat Local    | 31337    | Development                          |

## Contributing

```bash
# For Fineract integration features
git checkout -b feature/fineract-integration
git commit -m 'Add Apache Fineract banking integration'
git push origin feature/fineract-integration

# For Clearstream integration features
git checkout -b feature/clearstream-enhancement
git commit -m 'Enhance Clearstream PMI integration'
git push origin feature/clearstream-enhancement

# For DPO Token features
git checkout -b feature/dpo-funding
git commit -m 'Implement DPO Token funding mechanics'  
git push origin feature/dpo-funding

# Open a PR with comprehensive testing
```

## License

MIT License — see LICENSE.

## Disclaimer

This software is provided "as is" without warranty. Ensure regulatory compliance with Apache Fineract banking regulations and other financial authorities before deploying to mainnet. DPO Token economics should be reviewed by legal and financial advisors.

## Support

For technical support regarding Apache Fineract integration, Clearstream PMI integration, or DPO Token functionality, contact the development team or refer to the enhanced documentation in:

* `/docs/fineract-integration.md`
* `/docs/clearstream-integration.md`
* `/docs/dpo-token-guide.md`

> Note: This implementation includes comprehensive Apache Fineract banking integration for seamless traditional finance interoperability and full DPO Token funding mechanics as specified in the DPO Global LLC business plan. The system is designed as an independent microservice that integrates with broader banking rails while maintaining operational autonomy.
