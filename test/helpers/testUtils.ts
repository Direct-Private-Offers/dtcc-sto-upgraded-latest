import { ethers } from "hardhat";
import { COLLATERAL_CATEGORIES, DERIVATIVE_TYPES, TEST_CONSTANTS } from "./constants.js";

export const generateTestLEI = () => {
  return ethers.hexlify(ethers.randomBytes(20));
};

export const generateTestUPI = () => {
  return ethers.hexlify(ethers.randomBytes(12));
};

export const generateTestUTI = () => {
  return ethers.hexlify(ethers.randomBytes(32));
};

export const createTestDerivativeData = (overrides: any = {}) => {
  const now = Math.floor(Date.now() / 1000);
  
  return {
    uti: overrides.uti || generateTestUTI(),
    priorUti: overrides.priorUti || ethers.ZeroHash,
    upi: overrides.upi || generateTestUPI(),
    effectiveDate: overrides.effectiveDate || now,
    expirationDate: overrides.expirationDate || now + TEST_CONSTANTS.ONE_YEAR,
    executionTimestamp: overrides.executionTimestamp || now - TEST_CONSTANTS.ONE_DAY,
    notionalAmount: overrides.notionalAmount || ethers.parseEther(TEST_CONSTANTS.NOTIONAL_AMOUNT),
    notionalCurrency: overrides.notionalCurrency || TEST_CONSTANTS.NOTIONAL_CURRENCY,
    productType: overrides.productType || "SWAP",
    underlyingAsset: overrides.underlyingAsset || "AAPL",
    ...overrides
  };
};

export const createTestCounterparty = (overrides: any = {}) => {
  return {
    lei: overrides.lei || generateTestLEI(),
    walletAddress: overrides.walletAddress || ethers.Wallet.createRandom().address,
    jurisdiction: overrides.jurisdiction || TEST_CONSTANTS.JURISDICTION_CA,
    isReportable: overrides.isReportable !== undefined ? overrides.isReportable : (overrides.isReporting !== undefined ? overrides.isReporting : true),
    ...overrides
  };
};

export const createTestCollateralData = (overrides: any = {}) => {
  const now = Math.floor(Date.now() / 1000);
  return {
    collateralAmount: overrides.collateralAmount || ethers.parseEther("100000"),
    collateralCurrency: overrides.collateralCurrency || TEST_CONSTANTS.MARGIN_CURRENCY,
    collateralType: overrides.collateralType || "CASH",
    valuationTimestamp: overrides.valuationTimestamp || now,
    ...overrides
  };
};

export const createTestValuationData = (overrides: any = {}) => {
  const now = Math.floor(Date.now() / 1000);
  
  return {
    marketValue: overrides.marketValue || overrides.valuationAmount || ethers.parseEther("1050000"),
    valuationCurrency: overrides.valuationCurrency || TEST_CONSTANTS.VALUATION_CURRENCY,
    valuationTimestamp: overrides.valuationTimestamp || now,
    valuationModel: overrides.valuationModel || overrides.valuationMethod !== undefined ? String(overrides.valuationMethod) : "BLACK_SCHOLES",
    ...overrides
  };
};