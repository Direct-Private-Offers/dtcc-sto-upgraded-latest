import { 
  TokenizationRequest, 
  SettlementRequest, 
  CorporateActionRequest,
  EuroclearDerivativeRequest,
  DerivativeData,
  CounterpartyData,
  CollateralData,
  ValuationData
} from '../../euroclear/types';
import { SecurityUtils } from '../../../utils/security';

export function validateTokenizationRequest(data: any): string | null {
  if (!data.isin || typeof data.isin !== 'string') {
    return 'Valid ISIN required';
  }

  if (!SecurityUtils.validateISIN(data.isin)) {
    return 'Invalid ISIN format';
  }

  if (!data.investorAddress || typeof data.investorAddress !== 'string') {
    return 'Valid investor address required';
  }

  if (!SecurityUtils.validateEthereumAddress(data.investorAddress)) {
    return 'Invalid Ethereum address';
  }

  if (!data.amount || typeof data.amount !== 'number' || data.amount <= 0) {
    return 'Valid positive amount required';
  }

  if (!data.euroclearRef || typeof data.euroclearRef !== 'string') {
    return 'Valid Euroclear reference required';
  }

  if (!data.ipfsCID || typeof data.ipfsCID !== 'string') {
    return 'Valid IPFS CID required';
  }

  return null;
}

export function validateSettlementRequest(data: any): string | null {
  if (!data.tradeRef || typeof data.tradeRef !== 'string') {
    return 'Valid trade reference required';
  }

  if (!data.isin || typeof data.isin !== 'string') {
    return 'Valid ISIN required';
  }

  if (!SecurityUtils.validateISIN(data.isin)) {
    return 'Invalid ISIN format';
  }

  if (!data.fromAddress || typeof data.fromAddress !== 'string') {
    return 'Valid from address required';
  }

  if (!SecurityUtils.validateEthereumAddress(data.fromAddress)) {
    return 'Invalid from address';
  }

  if (!data.toAddress || typeof data.toAddress !== 'string') {
    return 'Valid to address required';
  }

  if (!SecurityUtils.validateEthereumAddress(data.toAddress)) {
    return 'Invalid to address';
  }

  if (!data.amount || typeof data.amount !== 'number' || data.amount <= 0) {
    return 'Valid positive amount required';
  }

  if (!data.euroclearRef || typeof data.euroclearRef !== 'string') {
    return 'Valid Euroclear reference required';
  }

  return null;
}

export function validateCorporateActionRequest(data: any): string | null {
  const validActionTypes = ['DIVIDEND', 'SPLIT', 'MERGER', 'RIGHTS_ISSUE'];

  if (!data.isin || typeof data.isin !== 'string') {
    return 'Valid ISIN required';
  }

  if (!SecurityUtils.validateISIN(data.isin)) {
    return 'Invalid ISIN format';
  }

  if (!data.actionType || !validActionTypes.includes(data.actionType)) {
    return `Valid action type required. Must be one of: ${validActionTypes.join(', ')}`;
  }

  if (!data.effectiveDate || typeof data.effectiveDate !== 'string') {
    return 'Valid effective date required';
  }

  if (!data.recordDate || typeof data.recordDate !== 'string') {
    return 'Valid record date required';
  }

  if (!data.reference || typeof data.reference !== 'string') {
    return 'Valid reference required';
  }

  // Validate dates
  try {
    const effectiveDate = new Date(data.effectiveDate);
    const recordDate = new Date(data.recordDate);
    
    if (isNaN(effectiveDate.getTime()) || isNaN(recordDate.getTime())) {
      return 'Invalid date format';
    }

    if (effectiveDate < recordDate) {
      return 'Effective date cannot be before record date';
    }

    if (effectiveDate < new Date()) {
      return 'Effective date cannot be in the past';
    }
  } catch {
    return 'Invalid date format';
  }

  return null;
}

export function validateDerivativeRequest(data: any): string | null {
  if (!data.isin || typeof data.isin !== 'string') {
    return 'Valid ISIN required';
  }

  if (!SecurityUtils.validateISIN(data.isin)) {
    return 'Invalid ISIN format';
  }

  // Validate derivative data
  const derivativeError = validateDerivativeData(data.derivativeData);
  if (derivativeError) {
    return `Derivative data: ${derivativeError}`;
  }

  // Validate counterparties
  const counterparty1Error = validateCounterpartyData(data.counterparty1);
  if (counterparty1Error) {
    return `Counterparty 1: ${counterparty1Error}`;
  }

  const counterparty2Error = validateCounterpartyData(data.counterparty2);
  if (counterparty2Error) {
    return `Counterparty 2: ${counterparty2Error}`;
  }

  // Validate collateral data
  const collateralError = validateCollateralData(data.collateralData);
  if (collateralError) {
    return `Collateral data: ${collateralError}`;
  }

  // Validate valuation data
  const valuationError = validateValuationData(data.valuationData);
  if (valuationError) {
    return `Valuation data: ${valuationError}`;
  }

  return null;
}

function validateDerivativeData(data: any): string | null {
  if (!data.uti || typeof data.uti !== 'string') {
    return 'UTI required';
  }

  if (data.uti.length < 10 || data.uti.length > 52) {
    return 'UTI must be between 10 and 52 characters';
  }

  if (!data.upi || typeof data.upi !== 'string') {
    return 'UPI required';
  }

  if (!SecurityUtils.validateUPI(data.upi)) {
    return 'Invalid UPI format';
  }

  if (!data.effectiveDate || typeof data.effectiveDate !== 'number') {
    return 'Valid effective date required';
  }

  if (!data.expirationDate || typeof data.expirationDate !== 'number') {
    return 'Valid expiration date required';
  }

  if (data.effectiveDate >= data.expirationDate) {
    return 'Effective date must be before expiration date';
  }

  if (!data.executionTimestamp || typeof data.executionTimestamp !== 'number') {
    return 'Valid execution timestamp required';
  }

  if (!data.notionalAmount || typeof data.notionalAmount !== 'number' || data.notionalAmount <= 0) {
    return 'Valid positive notional amount required';
  }

  if (!data.notionalCurrency || typeof data.notionalCurrency !== 'string') {
    return 'Notional currency required';
  }

  if (data.notionalCurrency.length !== 3) {
    return 'Notional currency must be 3 characters';
  }

  if (!data.productType || typeof data.productType !== 'string') {
    return 'Product type required';
  }

  if (!data.underlyingAsset || typeof data.underlyingAsset !== 'string') {
    return 'Underlying asset required';
  }

  return null;
}

function validateCounterpartyData(data: any): string | null {
  if (!data.lei || typeof data.lei !== 'string') {
    return 'LEI required';
  }

  if (!SecurityUtils.validateLEI(data.lei)) {
    return 'Invalid LEI format';
  }

  if (!data.walletAddress || typeof data.walletAddress !== 'string') {
    return 'Wallet address required';
  }

  if (!SecurityUtils.validateEthereumAddress(data.walletAddress)) {
    return 'Invalid wallet address';
  }

  if (!data.jurisdiction || typeof data.jurisdiction !== 'string') {
    return 'Jurisdiction required';
  }

  if (data.jurisdiction.length < 2) {
    return 'Jurisdiction must be at least 2 characters';
  }

  if (typeof data.isReportable !== 'boolean') {
    return 'isReportable must be a boolean';
  }

  return null;
}

function validateCollateralData(data: any): string | null {
  if (!data.collateralAmount || typeof data.collateralAmount !== 'number') {
    return 'Collateral amount required';
  }

  if (!data.collateralCurrency || typeof data.collateralCurrency !== 'string') {
    return 'Collateral currency required';
  }

  if (data.collateralCurrency.length !== 3) {
    return 'Collateral currency must be 3 characters';
  }

  if (!data.collateralType || typeof data.collateralType !== 'string') {
    return 'Collateral type required';
  }

  if (!data.valuationTimestamp || typeof data.valuationTimestamp !== 'number') {
    return 'Valuation timestamp required';
  }

  return null;
}

function validateValuationData(data: any): string | null {
  if (!data.marketValue || typeof data.marketValue !== 'number') {
    return 'Market value required';
  }

  if (!data.valuationCurrency || typeof data.valuationCurrency !== 'string') {
    return 'Valuation currency required';
  }

  if (data.valuationCurrency.length !== 3) {
    return 'Valuation currency must be 3 characters';
  }

  if (!data.valuationTimestamp || typeof data.valuationTimestamp !== 'number') {
    return 'Valuation timestamp required';
  }

  if (!data.valuationModel || typeof data.valuationModel !== 'string') {
    return 'Valuation model required';
  }

  return null;
}

export function validatePaginationParams(page: any, limit: any): string | null {
  const pageNum = parseInt(page);
  const limitNum = parseInt(limit);

  if (isNaN(pageNum) || pageNum < 1) {
    return 'Page must be a positive integer';
  }

  if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
    return 'Limit must be between 1 and 100';
  }

  return null;
}

export function sanitizeQueryParams(params: any): any {
  const sanitized: any = {};
  
  for (const [key, value] of Object.entries(params)) {
    if (typeof value === 'string') {
      sanitized[key] = SecurityUtils.sanitizeInput(value);
    } else {
      sanitized[key] = value;
    }
  }
  
  return sanitized;
}