import { ethers } from 'ethers';
import { EuroclearClient } from '../api/euroclear/client';
import { EuroclearDerivativeRequest, DerivativeData, CounterpartyData, CollateralData, ValuationData } from '../api/euroclear/types';

export class DerivativesService {
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
        'function reportEuroclearDerivative(tuple(bytes32 isin, tuple(bytes32 uti, bytes32 priorUti, bytes12 upi, uint256 effectiveDate, uint256 expirationDate, uint256 executionTimestamp, uint256 notionalAmount, string notionalCurrency, string productType, string underlyingAsset) derivativeData, tuple(bytes20 lei, address walletAddress, string jurisdiction, bool isReportable) counterparty1, tuple(bytes20 lei, address walletAddress, string jurisdiction, bool isReportable) counterparty2, tuple(uint256 collateralAmount, string collateralCurrency, string collateralType, uint256 valuationTimestamp) collateralData, tuple(uint256 marketValue, string valuationCurrency, uint256 valuationTimestamp, string valuationModel) valuationData) euroclearDerivative) external returns (bytes32)'
      ],
      wallet
    );
  }

  async processDerivativeReport(request: EuroclearDerivativeRequest): Promise<{
    success: boolean;
    uti?: string;
    transactionHash?: string;
    error?: string;
  }> {
    try {
      console.log(`Processing derivative report for ISIN: ${request.isin}`);

      // 1. Validate with Euroclear
      const security = await this.euroclearClient.getSecurityDetails(request.isin);
      if (!security) {
        throw new Error(`Security ${request.isin} not found in Euroclear`);
      }

      // 2. Report to Euroclear
      const euroclearUti = await this.euroclearClient.reportDerivative(request);

      // 3. Execute on-chain derivative reporting
      const tx = await this.contract.reportEuroclearDerivative({
        isin: ethers.encodeBytes32String(request.isin),
        derivativeData: this.formatDerivativeData(request.derivativeData),
        counterparty1: this.formatCounterpartyData(request.counterparty1),
        counterparty2: this.formatCounterpartyData(request.counterparty2),
        collateralData: this.formatCollateralData(request.collateralData),
        valuationData: this.formatValuationData(request.valuationData)
      });

      const receipt = await tx.wait();
      
      if (!receipt.status) {
        throw new Error('Transaction failed');
      }

      return {
        success: true,
        uti: euroclearUti,
        transactionHash: receipt.hash
      };

    } catch (error: any) {
      console.error('Derivative reporting service error:', error);
      return {
        success: false,
        error: error.message || 'Derivative reporting failed'
      };
    }
  }

  private formatDerivativeData(data: DerivativeData): any {
    return {
      uti: ethers.encodeBytes32String(data.uti),
      priorUti: data.priorUti ? ethers.encodeBytes32String(data.priorUti) : ethers.ZeroHash,
      upi: ethers.hexlify(ethers.toBeArray(data.upi)),
      effectiveDate: data.effectiveDate,
      expirationDate: data.expirationDate,
      executionTimestamp: data.executionTimestamp,
      notionalAmount: data.notionalAmount,
      notionalCurrency: data.notionalCurrency,
      productType: data.productType,
      underlyingAsset: data.underlyingAsset
    };
  }

  private formatCounterpartyData(data: CounterpartyData): any {
    return {
      lei: ethers.hexlify(ethers.toBeArray(data.lei)),
      walletAddress: data.walletAddress,
      jurisdiction: data.jurisdiction,
      isReportable: data.isReportable
    };
  }

  private formatCollateralData(data: CollateralData): any {
    return {
      collateralAmount: data.collateralAmount,
      collateralCurrency: data.collateralCurrency,
      collateralType: data.collateralType,
      valuationTimestamp: data.valuationTimestamp
    };
  }

  private formatValuationData(data: ValuationData): any {
    return {
      marketValue: data.marketValue,
      valuationCurrency: data.valuationCurrency,
      valuationTimestamp: data.valuationTimestamp,
      valuationModel: data.valuationModel
    };
  }

  async batchProcessDerivatives(requests: EuroclearDerivativeRequest[]): Promise<{
    successes: number;
    failures: number;
    results: Array<{ request: EuroclearDerivativeRequest; success: boolean; uti?: string; error?: string }>;
  }> {
    const results = [];
    let successes = 0;
    let failures = 0;

    for (const request of requests) {
      try {
        const result = await this.processDerivativeReport(request);
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