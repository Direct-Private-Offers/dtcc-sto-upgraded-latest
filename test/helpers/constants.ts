export const TEST_CONSTANTS = {
  // Token constants
  TOKEN_NAME: "TestSecurityToken",
  TOKEN_SYMBOL: "TST",
  INITIAL_SUPPLY: "1000000",
  DEFAULT_LOCKUP: 90 * 24 * 60 * 60, // 90 days
  
  // CSA Constants
  NOTIONAL_AMOUNT: "1000000",
  NOTIONAL_CURRENCY: "USD",
  MARGIN_CURRENCY: "USD",
  VALUATION_CURRENCY: "USD",
  
  // Jurisdictions
  JURISDICTION_CA: "CA-ON",
  JURISDICTION_US: "US-NY",
  
  // Time constants
  ONE_DAY: 86400,
  ONE_YEAR: 31536000,
  
  // Error messages
  ERROR_INVALID_LEI: "Invalid LEI",
  ERROR_INVALID_UPI: "Invalid UPI",
  ERROR_TRADE_EXISTS: "Trade already reported",
  ERROR_NOT_REPORTER: "Caller is not derivatives reporter"
};

export const DERIVATIVE_TYPES = {
  CLEARED: 0, // Y
  NOT_CLEARED: 1, // N
  INTENT_TO_CLEAR: 2 // I
};

export const COLLATERAL_CATEGORIES = {
  UNCOLLATERALIZED: 0, // UNCL
  PARTIALLY_COLLATERALIZED_1: 1, // PRC1
  PARTIALLY_COLLATERALIZED_2: 2, // PRC2
  ONE_WAY_COLLATERALIZED_1: 3, // OWC1
  ONE_WAY_COLLATERALIZED_2: 4, // OWC2
  FULLY_COLLATERALIZED: 5 // FLCL
};