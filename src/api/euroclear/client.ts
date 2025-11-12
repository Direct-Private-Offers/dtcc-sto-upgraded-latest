import axios, { AxiosInstance } from 'axios';
import {
  EuroclearSecurity,
  EuroclearInvestor,
  TokenizationRequest,
  SettlementRequest,
  CorporateActionRequest,
  EuroclearDerivativeRequest,
  ApiResponse,
  ChainlinkRequest
} from './types';

export class EuroclearClient {
  private client: AxiosInstance;
  private baseURL: string;

  constructor() {
    this.baseURL = process.env.EUROCLEAR_BASE_URL || 'https://api.euroclear.com';
    
    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.EUROCLEAR_API_KEY}`,
        'X-Client-ID': process.env.EUROCLEAR_CLIENT_ID,
        'X-LEI': process.env.ISSUER_LEI
      }
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    this.client.interceptors.request.use(
      (config) => {
        console.log(`Making Euroclear API call: ${config.method?.toUpperCase()} ${config.url}`);
        return config;
      },
      (error) => Promise.reject(error)
    );

    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        console.error('Euroclear API error:', error.response?.data || error.message);
        
        if (error.response?.status === 401) {
          console.error('Authentication failed - check API credentials');
        }
        
        return Promise.reject(error);
      }
    );
  }

  async getSecurityDetails(isin: string): Promise<EuroclearSecurity> {
    try {
      const response = await this.client.get<ApiResponse<EuroclearSecurity>>(
        `/securities/${isin}`
      );
      
      if (!response.data.success) {
        throw new Error(response.data.error || 'Failed to fetch security details');
      }
      
      return response.data.data!;
    } catch (error) {
      console.error(`Error fetching security ${isin}:`, error);
      throw new Error(`Failed to get security details for ISIN: ${isin}`);
    }
  }

  async validateInvestor(isin: string, investorId: string): Promise<{ isValid: boolean; reason?: string }> {
    try {
      const response = await this.client.post<ApiResponse<{ isValid: boolean; reason?: string }>>(
        `/securities/${isin}/validate-investor`,
        { investorId }
      );
      
      return response.data.data || { isValid: false, reason: 'Validation failed' };
    } catch (error) {
      console.error(`Error validating investor ${investorId} for ISIN ${isin}:`, error);
      return { isValid: false, reason: 'Validation service unavailable' };
    }
  }

  async initiateTokenization(request: TokenizationRequest): Promise<string> {
    try {
      const response = await this.client.post<ApiResponse<{ transactionId: string }>>(
        '/tokenization/initiate',
        request
      );
      
      if (!response.data.success) {
        throw new Error(response.data.error || 'Tokenization initiation failed');
      }
      
      return response.data.data!.transactionId;
    } catch (error) {
      console.error('Error initiating tokenization:', error);
      throw new Error('Failed to initiate tokenization with Euroclear');
    }
  }

  async confirmSettlement(request: SettlementRequest): Promise<boolean> {
    try {
      const response = await this.client.post<ApiResponse<{ confirmed: boolean }>>(
        '/settlement/confirm',
        request
      );
      
      return response.data.data?.confirmed || false;
    } catch (error) {
      console.error('Error confirming settlement:', error);
      return false;
    }
  }

  async processCorporateAction(request: CorporateActionRequest): Promise<boolean> {
    try {
      const response = await this.client.post<ApiResponse<{ processed: boolean }>>(
        '/corporate-actions/process',
        request
      );
      
      return response.data.data?.processed || false;
    } catch (error) {
      console.error('Error processing corporate action:', error);
      return false;
    }
  }

  async reportDerivative(request: EuroclearDerivativeRequest): Promise<string> {
    try {
      const response = await this.client.post<ApiResponse<{ uti: string }>>(
        '/derivatives/report',
        request
      );
      
      if (!response.data.success) {
        throw new Error(response.data.error || 'Derivative reporting failed');
      }
      
      return response.data.data!.uti;
    } catch (error) {
      console.error('Error reporting derivative:', error);
      throw new Error('Failed to report derivative to Euroclear');
    }
  }

  async getNAV(isin: string): Promise<number> {
    try {
      const response = await this.client.get<ApiResponse<{ nav: number }>>(
        `/securities/${isin}/nav`
      );
      
      return response.data.data?.nav || 0;
    } catch (error) {
      console.error(`Error fetching NAV for ${isin}:`, error);
      return 0;
    }
  }

  // Health check
  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.client.get<ApiResponse<{ status: string }>>('/health');
      return response.data.data?.status === 'OK';
    } catch (error) {
      console.error('Euroclear API health check failed:', error);
      return false;
    }
  }

  // Chainlink integration helper
  formatChainlinkRequest(
    endpoint: string,
    method: 'GET' | 'POST' = 'GET',
    body?: any
  ): ChainlinkRequest {
    return {
      url: `${this.baseURL}${endpoint}`,
      path: 'data',
      method,
      body
    };
  }
}