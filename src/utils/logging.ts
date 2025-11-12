import { getConfig } from './config';

export class Logger {
  private context: string;
  private config = getConfig();

  constructor(context: string) {
    this.context = context;
  }

  private shouldLog(level: string): boolean {
    const levels = ['error', 'warn', 'info', 'debug'];
    const configLevel = levels.indexOf(this.config.logging.level);
    const messageLevel = levels.indexOf(level);
    return messageLevel <= configLevel;
  }

  private log(level: 'error' | 'warn' | 'info' | 'debug', message: string, meta?: any) {
    const timestamp = new Date().toISOString();
    const logEntry: any = {
      timestamp,
      level,
      context: this.context,
      message
    };

    if (meta) {
      logEntry.meta = meta;
    }

    if (this.config.logging.format === 'json') {
      console.log(JSON.stringify(logEntry));
    } else {
      const metaStr = meta ? ` - ${JSON.stringify(meta)}` : '';
      console.log(`[${timestamp}] ${level.toUpperCase()} [${this.context}] ${message}${metaStr}`);
    }
  }

  error(message: string, meta?: any) {
    if (this.shouldLog('error')) {
      this.log('error', message, meta);
    }
  }

  warn(message: string, meta?: any) {
    if (this.shouldLog('warn')) {
      this.log('warn', message, meta);
    }
  }

  info(message: string, meta?: any) {
    if (this.shouldLog('info')) {
      this.log('info', message, meta);
    }
  }

  debug(message: string, meta?: any) {
    if (this.shouldLog('debug')) {
      this.log('debug', message, meta);
    }
  }

  // Specialized loggers for different components
  static tokenization = new Logger('tokenization');
  static settlement = new Logger('settlement');
  static derivatives = new Logger('derivatives');
  static compliance = new Logger('compliance');
  static euroclear = new Logger('euroclear');
  static blockchain = new Logger('blockchain');
}

export function createPerformanceLogger(operation: string) {
  const startTime = Date.now();
  
  return {
    end: (success: boolean = true, meta?: any) => {
      const duration = Date.now() - startTime;
      const logger = new Logger('performance');
      logger.info(`${operation} completed`, {
        operation,
        duration: `${duration}ms`,
        success,
        ...meta
      });
      return duration;
    },
    
    error: (error: Error, meta?: any) => {
      const duration = Date.now() - startTime;
      const logger = new Logger('performance');
      logger.error(`${operation} failed`, {
        operation,
        duration: `${duration}ms`,
        error: error.message,
        ...meta
      });
      return duration;
    }
  };
}

export function logApiCall(method: string, endpoint: string, params?: any) {
  const logger = new Logger('api');
  logger.debug(`${method} ${endpoint}`, { params });
}

export function logTransaction(txHash: string, operation: string, meta?: any) {
  const logger = new Logger('transaction');
  logger.info(`Transaction ${operation}`, { txHash, ...meta });
}

export function logEuroclearCall(operation: string, isin: string, meta?: any) {
  const logger = new Logger('euroclear');
  logger.info(`Euroclear ${operation}`, { isin, ...meta });
}