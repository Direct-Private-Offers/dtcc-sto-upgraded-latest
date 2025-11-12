import { VercelRequest, VercelResponse } from '@vercel/node';
import { EuroclearClient } from '../../euroclear/client.js';
import { TokenizationRequest, ApiResponse } from '../../euroclear/types.js';
import { validateAuth } from '../middleware/auth';
import { validateTokenizationRequest } from '../middleware/validation';

const euroclearClient = new EuroclearClient();

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Auth validation
  const authError = await validateAuth(req);
  if (authError) {
    return res.status(401).json({
      success: false,
      error: authError,
      timestamp: new Date().toISOString()
    });
  }

  if (req.method === 'POST') {
    await handleTokenization(req, res);
  } else if (req.method === 'GET') {
    await handleSecurityLookup(req, res);
  } else {
    res.status(405).json({
      success: false,
      error: 'Method not allowed',
      timestamp: new Date().toISOString()
    });
  }
}

async function handleTokenization(req: VercelRequest, res: VercelResponse) {
  try {
    // Request validation
    const validationError = validateTokenizationRequest(req.body);
    if (validationError) {
      return res.status(400).json({
        success: false,
        error: validationError,
        timestamp: new Date().toISOString()
      });
    }

    const request: TokenizationRequest = req.body;

    // 1. Validate security exists in Euroclear
    const security = await euroclearClient.getSecurityDetails(request.isin);
    if (!security) {
      return res.status(404).json({
        success: false,
        error: `Security with ISIN ${request.isin} not found`,
        timestamp: new Date().toISOString()
      });
    }

    // 2. Validate investor
    const isValidInvestor = await euroclearClient.validateInvestor(
      request.isin,
      request.investorAddress
    );
    
    if (!isValidInvestor) {
      return res.status(403).json({
        success: false,
        error: 'Investor not authorized for this security',
        timestamp: new Date().toISOString()
      });
    }

    // 3. Initiate tokenization with Euroclear
    const transactionId = await euroclearClient.initiateTokenization(request);

    res.status(200).json({
      success: true,
      data: {
        transactionId,
        isin: request.isin,
        investor: request.investorAddress,
        amount: request.amount,
        status: 'PENDING'
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Tokenization error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error during tokenization',
      timestamp: new Date().toISOString()
    });
  }
}

async function handleSecurityLookup(req: VercelRequest, res: VercelResponse) {
  try {
    const { isin } = req.query;
    
    if (!isin || typeof isin !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'ISIN parameter required',
        timestamp: new Date().toISOString()
      });
    }

    const security = await euroclearClient.getSecurityDetails(isin);
    
    res.status(200).json({
      success: true,
      data: security,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Security lookup error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch security details',
      timestamp: new Date().toISOString()
    });
  }
}