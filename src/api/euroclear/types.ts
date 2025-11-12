export interface EuroclearSecurity {
  isin: string;
  description: string;
  currency: string;
  issueDate: string;
  maturityDate?: string;
  totalSupply: number;
  issuerName: string;
  status: 'ACTIVE' | 'SUSPENDED' | 'MATURED';
  upi: string;
  issuerLEI: string;
}

export interface EuroclearInvestor {
  investorId: string;
  name: string;
  country: string;
  accreditation: 'RETAIL' | 'PROFESSIONAL' | 'INSTITUTIONAL';
  kycStatus: 'PENDING' | 'APPROVED' | 'REJECTED';
  restrictions: string[];
  lei?: string;
}

export interface TokenizationRequest {
  isin: string;
  investorAddress: string;
  amount: number;
  euroclearRef: string;
  ipfsCID: string;
}

export interface SettlementRequest {
  tradeRef: string;
  isin: string;
  fromAddress: string;
  toAddress: string;
  amount: number;
  euroclearRef: string;
}

export interface CorporateActionRequest {
  isin: string;
  actionType: 'DIVIDEND' | 'SPLIT' | 'MERGER' | 'RIGHTS_ISSUE';
  effectiveDate: string;
  recordDate: string;
  reference: string;
  data: any;
}

export interface DerivativeData {
  uti: string;
  priorUti: string;
  upi: string;
  effectiveDate: number;
  expirationDate: number;
  executionTimestamp: number;
  notionalAmount: number;
  notionalCurrency: string;
  productType: string;
  underlyingAsset: string;
}

export interface CounterpartyData {
  lei: string;
  walletAddress: string;
  jurisdiction: string;
  isReportable: boolean;
}

export interface CollateralData {
  collateralAmount: number;
  collateralCurrency: string;
  collateralType: string;
  valuationTimestamp: number;
}

export interface ValuationData {
  marketValue: number;
  valuationCurrency: string;
  valuationTimestamp: number;
  valuationModel: string;
}

export interface EuroclearDerivativeRequest {
  isin: string;
  derivativeData: DerivativeData;
  counterparty1: CounterpartyData;
  counterparty2: CounterpartyData;
  collateralData: CollateralData;
  valuationData: ValuationData;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp: string;
}

export interface ChainlinkRequest {
  url: string;
  path: string;
  method: 'GET' | 'POST';
  body?: any;
}