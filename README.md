# DTCC-Compliant STO with Euroclear Integration

A comprehensive integration between Euroclear's securities settlement system and blockchain-based tokenization with full DTCC compliance and CSA derivatives reporting.

## Overview

This project provides a complete solution for tokenizing securities from Euroclear's settlement system onto blockchain networks (Arbitrum Nova) while maintaining full compliance with DTCC regulations and CSA derivatives reporting requirements.

## Features

- **Security Tokenization**: Convert Euroclear securities to blockchain tokens (ERC-1400)
- **CSA Derivatives Reporting**: Complete derivatives reporting with DTCC compliance
- **Corporate Actions**: Process dividends, splits, mergers on-chain
- **Settlement Synchronization**: Real-time settlement between Euroclear and blockchain
- **Compliance Enforcement**: Full regulatory compliance for different offering types (Reg D, Reg CF, Rule 144A, etc.)
- **Chainlink Integration**: Secure oracle calls for off-chain data verification
- **Access Control**: Role-based access control for compliance officers, issuers, and reporters

## Architecture

```
Euroclear API 
    ↕
Vercel API Layer 
    ↕
EuroclearBridge Contract 
    ↕
DTCCCompliantSTO Contract
    ↑
Chainlink Oracles
```

## Smart Contracts

### Core Contracts

- **`DTCCCompliantSTO.sol`**: Main security token contract with CSA derivatives compliance
  - Implements ERC-1400 security token standard
  - Handles multiple offering types (Reg D, Reg CF, Rule 144A, etc.)
  - CSA derivatives reporting functionality
  - Compliance verification and investor management

- **`EuroclearBridge.sol`**: Bridge contract for Euroclear integration
  - Tokenizes securities from Euroclear
  - Processes corporate actions
  - Handles settlement synchronization
  - Reports derivatives to Euroclear

- **`DerivativesReporter.sol`**: Standalone contract for CSA derivatives reporting
  - Validates LEI and UPI identifiers
  - Reports derivatives to trade repository
  - Handles corrections and error reporting
  - Batch reporting support

### Interfaces

- `IEuroclearIntegration.sol`: Euroclear integration interface
- `ICSADerivatives.sol`: CSA derivatives reporting interface
- `IDTCCCompliantSTO.sol`: DTCC compliance interface
- `ILEIRegistry.sol`: Legal Entity Identifier registry interface
- `IUPIProvider.sol`: Universal Product Identifier provider interface
- `ITradeRepository.sol`: Trade repository interface

### Libraries

- `ComplianceLib.sol`: Regulatory compliance utilities
- `CSADerivativesLib.sol`: CSA derivatives data validation and handling
- `DateTimeLib.sol`: Date and time utilities

### Utilities

- `Errors.sol`: Custom error definitions for gas-efficient error handling

## API Endpoints

The project includes a Vercel API layer for interacting with the smart contracts:

### Tokenization
- `POST /api/issuance` - Tokenize securities from Euroclear
- `GET /api/issuance?isin=...` - Lookup security details

### Settlement
- `POST /api/settlement` - Sync settlements between Euroclear and blockchain

### Derivatives
- `POST /api/derivatives` - Report derivatives to DTCC
- `GET /api/derivatives?uti=...` - Lookup derivative by UTI

### Corporate Actions
- `POST /api/corporate-actions` - Process corporate actions (dividends, splits, etc.)

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Hardhat 2.17+
- Euroclear API credentials
- Arbitrum Nova RPC URL (or testnet)
- Private key for deployment (keep secure!)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd dtcc-sto-upgraded
```

2. Install dependencies:
```bash
npm install
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your credentials
```

4. Compile contracts:
```bash
npm run compile
```

5. Run tests:
```bash
npm run test
```

### Deployment

#### Local Development
```bash
# Start local Hardhat node
npx hardhat node

# Deploy to local network
npx hardhat run scripts/deploy.ts --network localhost
```

#### Testnet Deployment
```bash
# Deploy to Arbitrum Goerli
npm run deploy:test
```

#### Mainnet Deployment
```bash
# Deploy to Arbitrum Nova
npm run deploy
```

### Configuration

#### Environment Variables

Required variables (see `.env.example` for full list):

- `ARBITRUM_NOVA_RPC_URL`: Arbitrum Nova RPC endpoint
- `PRIVATE_KEY`: Deployment private key (keep secure!)
- `EUROCLEAR_API_KEY`: Your Euroclear API key
- `API_AUTH_TOKEN`: API authentication token
- `ARBISCAN_API_KEY`: For contract verification (optional)

#### Network Support

- **Arbitrum Nova** (Mainnet): Chain ID 42170
- **Arbitrum Goerli** (Testnet): Chain ID 421613
- **Hardhat Network** (Development): Chain ID 31337

## Testing

```bash
# Run all tests
npm run test

# Run integration tests only
npm run test:integration

# Run derivatives-specific tests
npm run test:derivatives

# Run with gas reporting
REPORT_GAS=true npm run test
```

## Scripts

- `npm run compile` - Compile Solidity contracts
- `npm run deploy` - Deploy to Arbitrum Nova mainnet
- `npm run deploy:test` - Deploy to Arbitrum Goerli testnet
- `npm run test` - Run all tests
- `npm run test:integration` - Run integration tests
- `npm run test:derivatives` - Run derivatives tests
- `npm run lint` - Run ESLint
- `npm run format` - Format code with Prettier
- `npm run verify` - Verify contracts on Etherscan

## Security

- All contracts use OpenZeppelin's battle-tested libraries
- Access control with role-based permissions
- Reentrancy guards on all external functions
- Pausable functionality for emergency stops
- Comprehensive input validation
- Custom errors for gas efficiency

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This software is provided "as is" without warranty of any kind. Use at your own risk. Ensure compliance with all applicable regulations before deploying to mainnet.