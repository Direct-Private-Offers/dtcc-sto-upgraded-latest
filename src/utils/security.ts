import crypto from 'crypto';
import { ethers } from 'ethers';

export class SecurityUtils {
  static generateNonce(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  static generateSignature(message: string, secret: string): string {
    return crypto
      .createHmac('sha256', secret)
      .update(message)
      .digest('hex');
  }

  static verifySignature(message: string, signature: string, secret: string): boolean {
    const expectedSignature = this.generateSignature(message, secret);
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'hex'),
      Buffer.from(expectedSignature, 'hex')
    );
  }

  static encryptData(data: string, key: string): string {
    const algorithm = 'aes-256-gcm';
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher(algorithm, key);
    
    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const authTag = cipher.getAuthTag();
    
    return `${iv.toString('hex')}:${encrypted}:${authTag.toString('hex')}`;
  }

  static decryptData(encryptedData: string, key: string): string {
    const [ivHex, encrypted, authTagHex] = encryptedData.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    
    const decipher = crypto.createDecipher('aes-256-gcm', key);
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }

  static validateISIN(isin: string): boolean {
    if (isin.length !== 12) {
      return false;
    }

    // Basic format validation
    const isinRegex = /^[A-Z]{2}[A-Z0-9]{9}[0-9]$/;
    return isinRegex.test(isin);
  }

  static sanitizeAddress(address: string): string {
    return address.toLowerCase().trim();
  }

  static validateEthereumAddress(address: string): boolean {
    return /^0x[a-fA-F0-9]{40}$/.test(address);
  }

  static validateLEI(lei: string): boolean {
    if (lei.length !== 20) {
      return false;
    }

    const leiRegex = /^[A-Z0-9]{20}$/;
    return leiRegex.test(lei);
  }

  static validateUPI(upi: string): boolean {
    if (upi.length !== 12) {
      return false;
    }

    const upiRegex = /^[A-Z0-9]{12}$/;
    return upiRegex.test(upi);
  }

  static generateAPIKey(): string {
    return `esk_${crypto.randomBytes(32).toString('hex')}`;
  }

  static hashData(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  static generateCSRFToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  static validateCSRFToken(token: string, storedToken: string): boolean {
    return crypto.timingSafeEqual(
      Buffer.from(token, 'hex'),
      Buffer.from(storedToken, 'hex')
    );
  }

  // Blockchain-specific security utilities
  static validateTransactionSignature(
    message: string,
    signature: string,
    expectedSigner: string
  ): boolean {
    try {
      const recoveredAddress = ethers.verifyMessage(message, signature);
      return recoveredAddress.toLowerCase() === expectedSigner.toLowerCase();
    } catch {
      return false;
    }
  }

  static generateSecureRandomBytes(length: number): string {
    return crypto.randomBytes(length).toString('hex');
  }

  static createMessageHash(message: string): string {
    return ethers.hashMessage(message);
  }

  // Rate limiting helper
  static createRateLimitKey(identifier: string, windowMs: number): string {
    const window = Math.floor(Date.now() / windowMs);
    return `rate_limit:${identifier}:${window}`;
  }

  // Input sanitization
  static sanitizeInput(input: string): string {
    return input
      .replace(/[<>]/g, '')
      .replace(/javascript/gi, '')
      .replace(/on\w+=/gi, '')
      .trim();
  }

  // Password strength validation
  static validatePasswordStrength(password: string): {
    isValid: boolean;
    reasons: string[];
  } {
    const reasons: string[] = [];
    
    if (password.length < 8) {
      reasons.push('Password must be at least 8 characters long');
    }
    
    if (!/[A-Z]/.test(password)) {
      reasons.push('Password must contain at least one uppercase letter');
    }
    
    if (!/[a-z]/.test(password)) {
      reasons.push('Password must contain at least one lowercase letter');
    }
    
    if (!/[0-9]/.test(password)) {
      reasons.push('Password must contain at least one number');
    }
    
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
      reasons.push('Password must contain at least one special character');
    }
    
    return {
      isValid: reasons.length === 0,
      reasons
    };
  }
}