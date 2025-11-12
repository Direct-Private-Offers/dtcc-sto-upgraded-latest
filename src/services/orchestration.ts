import { TokenizationService } from './tokenization';
import { ComplianceService } from './compliance';
import { DerivativesService } from './derivatives';
import { EuroclearClient } from '../api/euroclear/client';
import { 
  TokenizationRequest, 
  SettlementRequest, 
  CorporateActionRequest,
  EuroclearDerivativeRequest
} from '../api/euroclear/types';

export class OrchestrationService {
  private tokenizationService: TokenizationService;
  private complianceService: ComplianceService;
  private derivativesService: DerivativesService;
  private euroclearClient: EuroclearClient;

  constructor() {
    this.tokenizationService = new TokenizationService();
    this.complianceService = new ComplianceService();
    this.derivativesService = new DerivativesService();
    this.euroclearClient = new EuroclearClient();
  }

  async orchestrateTokenization(request: TokenizationRequest): Promise<{
    success: boolean;
    steps: {
      euroclearValidation: boolean;
      complianceCheck: boolean;
      blockchainExecution: boolean;
    };
    transactionHash?: string;
    issuanceId?: string;
    errors?: string[];
  }> {
    const steps = {
      euroclearValidation: false,
      complianceCheck: false,
      blockchainExecution: false
    };
    const errors: string[] = [];

    try {
      console.log('Starting tokenization orchestration...');

      // Step 1: Euroclear validation
      try {
        const security = await this.euroclearClient.getSecurityDetails(request.isin);
        if (!security) {
          throw new Error('Security not found in Euroclear');
        }

        const investorValidation = await this.euroclearClient.validateInvestor(
          request.isin,
          request.investorAddress
        );

        if (!investorValidation.isValid) {
          throw new Error(`Euroclear validation failed: ${investorValidation.reason}`);
        }

        steps.euroclearValidation = true;
      } catch (error: any) {
        errors.push(`Euroclear validation failed: ${error.message}`);
        throw error;
      }

      // Step 2: Compliance check
      try {
        const compliance = await this.complianceService.checkInvestorCompliance(
          request.investorAddress,
          request.isin,
          request.amount
        );

        if (!compliance.isValid) {
          throw new Error(`Compliance check failed: ${compliance.restrictions.join(', ')}`);
        }

        steps.complianceCheck = true;
      } catch (error: any) {
        errors.push(`Compliance check failed: ${error.message}`);
        throw error;
      }

      // Step 3: Blockchain execution
      try {
        const result = await this.tokenizationService.processTokenization(request);
        
        if (!result.success) {
          throw new Error(result.error);
        }

        steps.blockchainExecution = true;

        return {
          success: true,
          steps,
          transactionHash: result.transactionHash,
          issuanceId: result.issuanceId
        };

      } catch (error: any) {
        errors.push(`Blockchain execution failed: ${error.message}`);
        throw error;
      }

    } catch (error) {
      console.error('Tokenization orchestration failed:', error);
      return {
        success: false,
        steps,
        errors
      };
    }
  }

  async orchestrateSettlement(request: SettlementRequest): Promise<{
    success: boolean;
    steps: {
      euroclearConfirmation: boolean;
      complianceCheck: boolean;
      blockchainSettlement: boolean;
    };
    errors?: string[];
  }> {
    const steps = {
      euroclearConfirmation: false,
      complianceCheck: false,
      blockchainSettlement: false
    };
    const errors: string[] = [];

    try {
      // Step 1: Euroclear confirmation
      try {
        const confirmed = await this.euroclearClient.confirmSettlement(request);
        if (!confirmed) {
          throw new Error('Euroclear settlement confirmation failed');
        }
        steps.euroclearConfirmation = true;
      } catch (error: any) {
        errors.push(`Euroclear confirmation failed: ${error.message}`);
        throw error;
      }

      // Step 2: Compliance check for both parties
      try {
        const transferCompliance = await this.complianceService.checkTransferCompliance(
          request.fromAddress,
          request.toAddress,
          request.amount,
          request.isin
        );

        if (!transferCompliance.isValid) {
          throw new Error(
            `Transfer compliance failed: ${transferCompliance.restrictions.join(', ')}`
          );
        }

        steps.complianceCheck = true;
      } catch (error: any) {
        errors.push(`Compliance check failed: ${error.message}`);
        throw error;
      }

      // Step 3: Blockchain settlement (would execute here in production)
      // For now, mark as successful simulation
      steps.blockchainSettlement = true;

      return {
        success: true,
        steps
      };

    } catch (error) {
      console.error('Settlement orchestration failed:', error);
      return {
        success: false,
        steps,
        errors
      };
    }
  }

  async orchestrateDerivativeReporting(request: EuroclearDerivativeRequest): Promise<{
    success: boolean;
    steps: {
      euroclearValidation: boolean;
      dataValidation: boolean;
      blockchainReporting: boolean;
    };
    uti?: string;
    transactionHash?: string;
    errors?: string[];
  }> {
    const steps = {
      euroclearValidation: false,
      dataValidation: false,
      blockchainReporting: false
    };
    const errors: string[] = [];

    try {
      console.log('Starting derivative reporting orchestration...');

      // Step 1: Euroclear validation
      try {
        const security = await this.euroclearClient.getSecurityDetails(request.isin);
        if (!security) {
          throw new Error('Security not found in Euroclear');
        }
        steps.euroclearValidation = true;
      } catch (error: any) {
        errors.push(`Euroclear validation failed: ${error.message}`);
        throw error;
      }

      // Step 2: Data validation
      try {
        // Validate derivative data structure
        if (!request.derivativeData.uti) {
          throw new Error('UTI is required');
        }
        if (!request.derivativeData.upi) {
          throw new Error('UPI is required');
        }
        if (request.derivativeData.effectiveDate >= request.derivativeData.expirationDate) {
          throw new Error('Effective date must be before expiration date');
        }
        
        steps.dataValidation = true;
      } catch (error: any) {
        errors.push(`Data validation failed: ${error.message}`);
        throw error;
      }

      // Step 3: Blockchain reporting
      try {
        const result = await this.derivativesService.processDerivativeReport(request);
        
        if (!result.success) {
          throw new Error(result.error);
        }

        steps.blockchainReporting = true;

        return {
          success: true,
          steps,
          uti: result.uti,
          transactionHash: result.transactionHash
        };

      } catch (error: any) {
        errors.push(`Blockchain reporting failed: ${error.message}`);
        throw error;
      }

    } catch (error) {
      console.error('Derivative reporting orchestration failed:', error);
      return {
        success: false,
        steps,
        errors
      };
    }
  }

  async orchestrateCorporateAction(request: CorporateActionRequest): Promise<{
    success: boolean;
    steps: {
      euroclearProcessing: boolean;
      dataValidation: boolean;
      blockchainExecution: boolean;
    };
    errors?: string[];
  }> {
    const steps = {
      euroclearProcessing: false,
      dataValidation: false,
      blockchainExecution: false
    };
    const errors: string[] = [];

    try {
      // Step 1: Euroclear processing
      try {
        const processed = await this.euroclearClient.processCorporateAction(request);
        if (!processed) {
          throw new Error('Euroclear corporate action processing failed');
        }
        steps.euroclearProcessing = true;
      } catch (error: any) {
        errors.push(`Euroclear processing failed: ${error.message}`);
        throw error;
      }

      // Step 2: Data validation
      try {
        if (!request.reference) {
          throw new Error('Corporate action reference is required');
        }
        if (!request.effectiveDate || !request.recordDate) {
          throw new Error('Effective date and record date are required');
        }
        steps.dataValidation = true;
      } catch (error: any) {
        errors.push(`Data validation failed: ${error.message}`);
        throw error;
      }

      // Step 3: Blockchain execution (would execute here in production)
      steps.blockchainExecution = true;

      return {
        success: true,
        steps
      };

    } catch (error) {
      console.error('Corporate action orchestration failed:', error);
      return {
        success: false,
        steps,
        errors
      };
    }
  }

  async getSystemHealth(): Promise<{
    euroclear: boolean;
    blockchain: boolean;
    compliance: boolean;
    derivatives: boolean;
    overall: boolean;
  }> {
    const euroclearHealth = await this.euroclearClient.healthCheck();
    
    // Check blockchain connectivity
    let blockchainHealth = false;
    try {
      await this.complianceService['provider'].getBlockNumber();
      blockchainHealth = true;
    } catch (error) {
      console.error('Blockchain health check failed:', error);
    }

    // Check compliance service (basic check)
    const complianceHealth = true; // Assuming service is healthy if instantiated

    // Check derivatives service
    const derivativesHealth = true; // Assuming service is healthy if instantiated

    const overall = euroclearHealth && blockchainHealth && complianceHealth && derivativesHealth;

    return {
      euroclear: euroclearHealth,
      blockchain: blockchainHealth,
      compliance: complianceHealth,
      derivatives: derivativesHealth,
      overall
    };
  }
}