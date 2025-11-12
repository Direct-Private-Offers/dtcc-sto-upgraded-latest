# DTCC-Compliant STO with Euroclear and Clearstream Integration

A comprehensive integration between Euroclear/Clearstream securities settlement systems and blockchain-based tokenization with full DTCC compliance and CSA derivatives reporting.

---

## Overview
This project provides a complete solution for tokenizing securities from Euroclear and Clearstream settlement systems onto blockchain networks (Arbitrum Nova) while maintaining full compliance with DTCC regulations and CSA derivatives reporting requirements.

---

## Features

- **Security Tokenization:** Convert Euroclear/Clearstream securities to blockchain tokens (ERC-1400)
- **CSA Derivatives Reporting:** Complete derivatives reporting with DTCC compliance
- **Corporate Actions:** Process dividends, splits, mergers on-chain
- **Settlement Synchronization:** Real-time settlement between Euroclear/Clearstream and blockchain
- **Clearstream PMI Integration:** Full Post-Trade Management and Integration API support
- **Compliance Enforcement:** Regulatory compliance (Reg D, Reg CF, Rule 144A, etc.)
- **Chainlink Integration:** Secure oracle calls for off-chain data verification
- **Access Control:** Role-based access control for compliance officers, issuers, and reporters
- **ISIN Management:** Identifier validation and tracking

---

## Architecture

```
Euroclear API       Clearstream PMI API
       ↕                     ↕
  Vercel API Layer (Dual Integration)
       ↕                     ↕
 EuroclearBridge       ClearstreamBridge
       ↕                     ↕
      DTCCCompliantSTO Contract (Unified)
                 ↑
         Chainlink Oracles
```

---

## Smart Contracts

### Core Contracts

#### `DTCCCompliantSTO.sol`
- Main security token contract with CSA derivatives compliance and Clearstream integration
- Implements ERC-1400 standard
- Supports:
  - Multiple offering types (Reg D, Reg CF, Rule 144A, etc.)
  - CSA derivatives reporting
  - Clearstream PMI API integration
  - Compliance verification and investor management
  - ISIN whitelisting and validation

#### `EuroclearBridge.sol`
- Bridge contract for Euroclear integration
- Tokenizes securities from Euroclear
- Processes corporate actions
- Synchronizes settlement
- Reports derivatives to Euroclear

#### `ClearstreamBridge.sol`
- Bridge for Clearstream PMI integration
- Manages settlement lifecycle and instructions
- Tracks CSD participant accounts and updates positions in real time

#### `DerivativesReporter.sol`
- Standalone contract for CSA derivatives reporting
- Validates LEI and UPI identifiers
- Reports derivatives to trade repository
- Supports corrections, error handling, and batch reporting

---

## Interfaces

- `IEuroclearIntegration.sol`
- `ICLEARSTREAMIntegration.sol`
- `ICSADerivatives.sol`
- `IDTCCCompliantSTO.sol`
- `ILEIRegistry.sol`
- `IUPIProvider.sol`
- `ITradeRepository.sol`

---

## Libraries

- `ComplianceLib.sol` – Regulatory compliance utilities
- `CSADerivativesLib.sol` – CSA derivatives validation
- `ClearstreamLib.sol` – PMI integration utilities and validation
- `DateTimeLib.sol` – Date/time utilities
- `Errors.sol` – Custom error definitions

---

## API Endpoints (Vercel API Layer)

### Tokenization
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/issuance` | Tokenize securities |
| GET | `/api/issuance?isin=...` | Lookup security details |

### Settlement
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/settlement` | Sync settlement |
| POST | `/api/clearstream/settlement` | Initiate Clearstream settlement |
| GET  | `/api/clearstream/settlement/:id` | Get settlement status |

### Derivatives (DTCC Reporting)
| Method | Endpoint |
|--------|----------|
| POST | `/api/derivatives` |
| GET  | `/api/derivatives?uti=...` |

### Corporate Actions
| Method | Endpoint |
|--------|----------|
| POST | `/api/corporate-actions` |

### Clearstream Management
| Method | Endpoint |
|--------|----------|
| POST | `/api/clearstream/accounts` |
| GET  | `/api/clearstream/positions/:account` |
| POST | `/api/clearstream/instructions` |

---

## Clearstream PMI Integration Features

### Settlement Management
- Settlement initiation
- Automated instruction generation
- Real-time status tracking
- Position synchronization

### Account Management
- CSD account linking
- ISIN whitelisting
- Real-time balance/position updates

### Event Logging
- Full lifecycle audit trail
- Status notifications
- Error handling and recovery

---

## Getting Started

### Prerequisites
- Node.js 18+
- Hardhat 2.17+
- Euroclear API credentials
- Clearstream PMI API credentials
- Arbitrum Nova RPC endpoint

### Installation

```bash
git clone <repository-url>
cd dtcc-sto-upgraded
npm install
```

Create `.env` file:

```bash
cp .env.example .env
```

Compile:

```bash
npm run compile
```

Run tests:

```bash
npm run test
```

---

## Deployment

### Local

```bash
npx hardhat node
npx hardhat run scripts/deploy.ts --network localhost
```

### Testnet

```bash
npm run deploy:test
```

### Mainnet (Arbitrum Nova)

```bash
npm run deploy
```

---

## Configuration (.env)

| Variable | Description |
|----------|-------------|
| ARBITRUM_NOVA_RPC_URL | Arbitrum Nova RPC URL |
| PRIVATE_KEY | Deployment key |
| EUROCLEAR_API_KEY | Euroclear API key |
| CLEARSTREAM_API_KEY | Clearstream PMI API key |
| API_AUTH_TOKEN | API auth token |
| ARBISCAN_API_KEY | Contract verification key (optional) |

---

## Network Support

| Network | Chain ID |
|---------|----------|
| Arbitrum Nova | **42170** |
| Arbitrum Goerli | **421613** |
| Hardhat Local | **31337** |

---

## Testing

```bash
npm run test
npm run test:integration
npm run test:derivatives
npm run test:clearstream
REPORT_GAS=true npm run test
```

---

## Scripts

| Command | Description |
|---------|-------------|
| `npm run compile` | Compile contracts |
| `npm run deploy` | Deploy to Arbitrum Nova |
| `npm run deploy:test` | Deploy to testnet |
| `npm run test` | Run all tests |
| `npm run verify` | Verify contracts |

---

## Security

- OpenZeppelin libraries
- Role-based access control
- Reentrancy guards
- Emergency pausable functions
- Compliance + ISIN/position validation

---

## DPOI Use Case Integration (Direct Private Offers)

- DTCC Eligible Tokens (hybrid asset support)
- Transfer agent compatibility
- Cross-chain and DEX listing support
- Automated smart contract execution (Airbrush MVP)

---

## Contributing

```bash
git checkout -b feature/amazing-feature
git commit -m 'Add some amazing feature'
git push origin feature/amazing-feature
```

Open a PR.

---

## License
MIT License — see `LICENSE`.

---

## Disclaimer
This software is provided *"as is"* without warranty. Ensure regulatory compliance before deploying to mainnet.