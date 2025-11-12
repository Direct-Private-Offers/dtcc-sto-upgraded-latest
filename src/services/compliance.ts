import { ethers } from 'ethers';

export interface ComplianceCheck {
  isValid: boolean;
  restrictions: string[];
  investorType: 'RETAIL' | 'ACCREDITED' | 'INSTITUTIONAL';
  jurisdiction: string;
  kycStatus: 'PENDING' | 'APPROVED' | 'REJECTED';
  lei?: string;
  isQIB: boolean;
}

export class ComplianceService {
  private provider: ethers.JsonRpcProvider;
  private contract: ethers.Contract;

  constructor() {
    this.provider = new ethers.JsonRpcProvider(process.env.ARBITRUM_NOVA_RPC_URL);
    
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, this.provider);
    this.contract = new ethers.Contract(
      process.env.DTCC_STO_CONTRACT!,
      [
        'function validateCompliance(address from, address to, uint256 amount) external view returns (bool, string)',
        'function blacklisted(address) external view returns (bool)',
        'function investors(address) external view returns (bool, bool, bool, uint256, uint256, uint256, bytes32[])',
        'function isQIB(address) external view returns (bool)'
      ],
      wallet
    );
  }

  async checkInvestorCompliance(
    investorAddress: string,
    isin: string,
    amount: number
  ): Promise<ComplianceCheck> {
    try {
      // Check blacklist status
      const isBlacklisted = await this.contract.blacklisted(investorAddress);
      
      if (isBlacklisted) {
        return {
          isValid: false,
          restrictions: ['BLACKLISTED'],
          investorType: 'RETAIL',
          jurisdiction: 'UNKNOWN',
          kycStatus: 'REJECTED',
          isQIB: false
        };
      }

      // Get investor details
      const investorData = await this.contract.investors(investorAddress);
      const [isVerified, isAccredited, isQIB, verificationDate, lastKycRefresh, totalInvested, issuanceIds] = investorData;

      // Validate transfer compliance
      const [isValid, reason] = await this.contract.validateCompliance(
        ethers.ZeroAddress, // from (minting)
        investorAddress,
        amount
      );

      const restrictions: string[] = [];
      if (!isValid && reason) {
        restrictions.push(reason);
      }

      // Check KYC status
      let kycStatus: 'PENDING' | 'APPROVED' | 'REJECTED' = 'PENDING';
      if (!isVerified) {
        kycStatus = 'PENDING';
        restrictions.push('KYC_NOT_VERIFIED');
      } else {
        kycStatus = 'APPROVED';
      }

      // Determine investor type
      let investorType: 'RETAIL' | 'ACCREDITED' | 'INSTITUTIONAL' = 'RETAIL';
      if (isQIB) {
        investorType = 'INSTITUTIONAL';
      } else if (isAccredited) {
        investorType = 'ACCREDITED';
      }

      // Additional jurisdiction checks based on ISIN
      const jurisdiction = this.getJurisdictionFromISIN(isin);
      const jurisdictionRestrictions = this.checkJurisdictionRestrictions(jurisdiction, investorAddress);
      
      if (jurisdictionRestrictions) {
        restrictions.push(jurisdictionRestrictions);
      }

      // Generate mock LEI for institutional investors
      const lei = investorType === 'INSTITUTIONAL' ? this.generateMockLEI(investorAddress) : undefined;

      return {
        isValid: isValid && restrictions.length === 0 && isVerified,
        restrictions,
        investorType,
        jurisdiction,
        kycStatus,
        lei,
        isQIB
      };

    } catch (error) {
      console.error('Compliance check error:', error);
      return {
        isValid: false,
        restrictions: ['COMPLIANCE_CHECK_FAILED'],
        investorType: 'RETAIL',
        jurisdiction: 'UNKNOWN',
        kycStatus: 'PENDING',
        isQIB: false
      };
    }
  }

  async checkTransferCompliance(
    fromAddress: string,
    toAddress: string,
    amount: number,
    isin: string
  ): Promise<{
    isValid: boolean;
    fromCheck: ComplianceCheck;
    toCheck: ComplianceCheck;
    restrictions: string[];
  }> {
    const fromCheck = await this.checkInvestorCompliance(fromAddress, isin, amount);
    const toCheck = await this.checkInvestorCompliance(toAddress, isin, amount);

    const restrictions = [...fromCheck.restrictions, ...toCheck.restrictions];

    // Additional transfer-specific restrictions
    if (fromCheck.investorType === 'RETAIL' && toCheck.investorType === 'INSTITUTIONAL') {
      restrictions.push('RETAIL_TO_INSTITUTIONAL_TRANSFER_RESTRICTED');
    }

    const isValid = fromCheck.isValid && toCheck.isValid && restrictions.length === 0;

    return {
      isValid,
      fromCheck,
      toCheck,
      restrictions
    };
  }

  private getJurisdictionFromISIN(isin: string): string {
    const countryCode = isin.substring(0, 2);
    
    const jurisdictions: { [key: string]: string } = {
      'US': 'UNITED_STATES',
      'GB': 'UNITED_KINGDOM',
      'DE': 'GERMANY',
      'FR': 'FRANCE',
      'JP': 'JAPAN',
      'CA': 'CANADA',
      'AU': 'AUSTRALIA',
      'CH': 'SWITZERLAND',
      'NL': 'NETHERLANDS'
    };

    return jurisdictions[countryCode] || 'OTHER';
  }

  private checkJurisdictionRestrictions(jurisdiction: string, investorAddress: string): string | null {
    const restrictedJurisdictions = ['CU', 'IR', 'KP', 'SY']; // OFAC restricted
    
    if (restrictedJurisdictions.includes(jurisdiction)) {
      return `Restricted jurisdiction: ${jurisdiction}`;
    }

    // EU-specific restrictions
    const euJurisdictions = ['DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'LU'];
    if (euJurisdictions.includes(jurisdiction)) {
      // Additional EU compliance checks
      return null;
    }

    return null;
  }

  private generateMockLEI(address: string): string {
    // Generate a mock LEI based on address (in production, this would come from a registry)
    const base = address.slice(2, 22).toUpperCase();
    return `549300${base}${this.calculateLEIChecksum(`549300${base}`)}`;
  }

  private calculateLEIChecksum(leiBase: string): string {
    // Simple checksum calculation for mock LEI
    let sum = 0;
    for (let i = 0; i < leiBase.length; i++) {
      const char = leiBase.charAt(i);
      const value = isNaN(Number(char)) ? char.charCodeAt(0) - 55 : Number(char);
      sum += value;
    }
    return (sum % 10).toString();
  }
}