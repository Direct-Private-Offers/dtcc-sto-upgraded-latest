import { VercelRequest, VercelResponse } from '@vercel/node';
import { EuroclearClient } from '../../euroclear/client';
import { EuroclearDerivativeRequest, ApiResponse } from '../../euroclear/types';
import { validateAuth } from '../middleware/auth';
import { validateDerivativeRequest } from '../middleware/validation';

const euroclearClient = new EuroclearClient();

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const authError = await validateAuth(req);
  if (authError) {
    return res.status(401).json({
      success: false,
      error: authError,
      timestamp: new Date().toISOString()
    });
  }

  if (req.method === 'POST') {
    await handleDerivativeReport(req, res);
  } else if (req.method === 'GET') {
    await handleDerivativeLookup(req, res);
  } else {
    res.status(405).json({
      success: false,
      error: 'Method not allowed',
      timestamp: new Date().toISOString()
    });
  }
}

async function handleDerivativeReport(req: VercelRequest, res: VercelResponse) {
  try {
    const validationError = validateDerivativeRequest(req.body);
    if (validationError) {
      return res.status(400).json({
        success: false,
        error: validationError,
        timestamp: new Date().toISOString()
      });
    }

    const request: EuroclearDerivativeRequest = req.body;

    // Validate security exists
    const security = await euroclearClient.getSecurityDetails(request.isin);
    if (!security) {
      return res.status(404).json({
        success: false,
        error: `Security with ISIN ${request.isin} not found`,
        timestamp: new Date().toISOString()
      });
    }

    // Report derivative to Euroclear
    const uti = await euroclearClient.reportDerivative(request);

    res.status(200).json({
      success: true,
      data: {
        uti,
        isin: request.isin,
        status: 'REPORTED',
        timestamp: new Date().toISOString()
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Derivative reporting error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error during derivative reporting',
      timestamp: new Date().toISOString()
    });
  }
}

async function handleDerivativeLookup(req: VercelRequest, res: VercelResponse) {
  try {
    const { uti, isin } = req.query;

    if (!uti && !isin) {
      return res.status(400).json({
        success: false,
        error: 'UTI or ISIN parameter required',
        timestamp: new Date().toISOString()
      });
    }

    // In a real implementation, this would fetch from Euroclear
    // For now, return mock data
    const mockDerivative = {
      uti: uti as string || 'MOCK_UTI_123',
      isin: isin as string || 'US0378331005',
      derivativeData: {
        uti: uti as string || 'MOCK_UTI_123',
        priorUti: '',
        upi: 'UPI_MOCK_001',
        effectiveDate: Math.floor(Date.now() / 1000),
        expirationDate: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
        executionTimestamp: Math.floor(Date.now() / 1000),
        notionalAmount: 1000000,
        notionalCurrency: 'USD',
        productType: 'SWAP',
        underlyingAsset: 'AAPL'
      },
      status: 'ACTIVE'
    };

    res.status(200).json({
      success: true,
      data: mockDerivative,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Derivative lookup error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch derivative data',
      timestamp: new Date().toISOString()
    });
  }
}