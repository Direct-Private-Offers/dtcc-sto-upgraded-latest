import { ethers } from 'ethers';
import { EuroclearClient } from '../api/euroclear/client';
import { TokenizationRequest } from '../api/euroclear/types';

export class TokenizationService {
  private euroclearClient: EuroclearClient;
  private provider: ethers.JsonRpcProvider;
  private contract: ethers.Contract;

  constructor() {
    this.euroclearClient = new EuroclearClient();
    this.provider = new ethers.JsonRpcProvider(process.env.ARBITRUM_NOVA_RPC_URL);
    
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, this.provider);
    this.contract = new ethers.Contract(
      process.env.EUROCLEAR_BRIDGE_CONTRACT!,
      [
        'function tokenizeSecurity(bytes32 isin, address investor, uint256 amount, bytes32 euroclearRef, string calldata ipfsCID) external returns (bytes32)',
        'function getSecurityDetails(bytes32 isin) external view returns (tuple)'
      ],
      wallet
    );
  }

  async processTokenization(request: TokenizationRequest): Promise<{
    success: boolean;
    transactionHash?: string;
    issuanceId?: string;
    error?: string;
  }> {
    try {
      console.log(`Processing tokenization for ISIN: ${request.isin}, Investor: ${request.investorAddress}`);

      // 1. Validate with Euroclear
      const security = await this.euroclearClient.getSecurityDetails(request.isin);
      if (!security) {
        throw new Error(`Security ${request.isin} not found in Euroclear`);
      }

      const investorValidation = await this.euroclearClient.validateInvestor(
        request.isin,
        request.investorAddress
      );

      if (!investorValidation.isValid) {
        throw new Error(`Investor validation failed: ${investorValidation.reason}`);
      }

      // 2. Execute on-chain tokenization
      const isinBytes32 = ethers.encodeBytes32String(request.isin);
      const euroclearRefBytes32 = ethers.encodeBytes32String(request.euroclearRef);

      const tx = await this.contract.tokenizeSecurity(
        isinBytes32,
        request.investorAddress,
        request.amount,
        euroclearRefBytes32,
        request.ipfsCID
      );

      const receipt = await tx.wait();
      
      if (!receipt.status) {
        throw new Error('Transaction failed');
      }

      // 3. Extract issuance ID from events
      const event = receipt.logs.find((log: any) => 
        log.topics[0] === ethers.id('SecurityTokenized(bytes32,address,address,uint256,bytes32,bytes32)')
      );

      if (!event) {
        throw new Error('Tokenization event not found');
      }

      const decoded = this.contract.interface.decodeEventLog(
        'SecurityTokenized',
        event.data,
        event.topics
      );

      return {
        success: true,
        transactionHash: receipt.hash,
        issuanceId: decoded.issuanceId
      };

    } catch (error: any) {
      console.error('Tokenization service error:', error);
      return {
        success: false,
        error: error.message || 'Tokenization failed'
      };
    }
  }

  async getTokenizationStatus(transactionHash: string): Promise<{
    status: 'PENDING' | 'CONFIRMED' | 'FAILED';
    blockNumber?: number;
    confirmations?: number;
    issuanceId?: string;
  }> {
    try {
      const receipt = await this.provider.getTransactionReceipt(transactionHash);
      
      if (!receipt) {
        return { status: 'PENDING' };
      }

      if (receipt.status === 0) {
        return { status: 'FAILED' };
      }

      // Extract issuance ID from successful transaction
      const event = receipt.logs.find((log: any) => 
        log.topics[0] === ethers.id('SecurityTokenized(bytes32,address,address,uint256,bytes32,bytes32)')
      );

      let issuanceId: string | undefined;
      if (event) {
        const decoded = this.contract.interface.decodeEventLog(
          'SecurityTokenized',
          event.data,
          event.topics
        );
        issuanceId = decoded.issuanceId;
      }

      return {
        status: 'CONFIRMED',
        blockNumber: Number(receipt.blockNumber),
        confirmations: (await this.provider.getBlockNumber()) - Number(receipt.blockNumber),
        issuanceId
      };

    } catch (error) {
      console.error('Status check error:', error);
      return { status: 'FAILED' };
    }
  }

  async batchTokenize(requests: TokenizationRequest[]): Promise<{
    successes: number;
    failures: number;
    results: Array<{ request: TokenizationRequest; success: boolean; transactionHash?: string; error?: string }>;
  }> {
    const results = [];
    let successes = 0;
    let failures = 0;

    for (const request of requests) {
      try {
        const result = await this.processTokenization(request);
        if (result.success) {
          successes++;
        } else {
          failures++;
        }
        results.push({ request, ...result });
      } catch (error) {
        failures++;
        results.push({ 
          request, 
          success: false, 
          error: error instanceof Error ? error.message : 'Unknown error' 
        });
      }
    }

    return { successes, failures, results };
  }
}