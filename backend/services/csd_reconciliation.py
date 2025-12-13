"""
CSD Reconciliation Service
Reconciles on-chain issuance data with Central Securities Depository (CSD) systems
"""

import logging
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal
import asyncio
import httpx
from pydantic import ValidationError

# Import models (adjust path as needed)
from backend.models.issuance_models import (
    CSDSystem,
    SettlementRecord,
    InvestorPosition,
    CSDMapping,
    SettlementStatus
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class CSDReconciliationService:
    """
    Service for reconciling blockchain issuance data with CSD systems
    (Clearstream, Euroclear, DTCC, etc.)
    """
    
    def __init__(self, api_credentials: Dict[str, Dict[str, str]]):
        """
        Initialize with API credentials for each CSD system
        
        Args:
            api_credentials: Dict mapping CSD system names to credential dicts
                Example: {
                    "CLEARSTREAM": {"api_key": "...", "endpoint": "..."},
                    "EUROCLEAR": {"api_key": "...", "endpoint": "..."}
                }
        """
        self.credentials = api_credentials
        self.http_client = httpx.AsyncClient(timeout=30.0)
        
    async def reconcile_settlement(
        self,
        on_chain_record: SettlementRecord,
        csd_mapping: CSDMapping
    ) -> Tuple[bool, Optional[str]]:
        """
        Reconcile a single settlement record with the CSD system
        
        Returns:
            Tuple of (reconciled: bool, error_message: Optional[str])
        """
        try:
            csd_system = csd_mapping.csd_system
            
            logger.info(f"Reconciling settlement with {csd_system.value}")
            logger.info(f"On-chain ref: {on_chain_record.external_ref}")
            logger.info(f"Units: {on_chain_record.units}")
            
            # Route to appropriate CSD reconciliation method
            if csd_system == CSDSystem.CLEARSTREAM:
                return await self._reconcile_clearstream(on_chain_record, csd_mapping)
            elif csd_system == CSDSystem.EUROCLEAR:
                return await self._reconcile_euroclear(on_chain_record, csd_mapping)
            elif csd_system == CSDSystem.DTCC:
                return await self._reconcile_dtcc(on_chain_record, csd_mapping)
            elif csd_system == CSDSystem.DPO_GLOBAL:
                return await self._reconcile_dpo_global(on_chain_record, csd_mapping)
            else:
                return False, f"Unsupported CSD system: {csd_system.value}"
                
        except Exception as e:
            error_msg = f"Reconciliation error: {str(e)}"
            logger.error(error_msg)
            return False, error_msg
    
    async def _reconcile_clearstream(
        self,
        record: SettlementRecord,
        mapping: CSDMapping
    ) -> Tuple[bool, Optional[str]]:
        """Reconcile with Clearstream"""
        try:
            if CSDSystem.CLEARSTREAM.value not in self.credentials:
                return False, "Clearstream credentials not configured"
            
            creds = self.credentials[CSDSystem.CLEARSTREAM.value]
            endpoint = creds.get("endpoint")
            api_key = creds.get("api_key")
            
            # Query Clearstream API for settlement confirmation
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
            
            params = {
                "reference": record.external_ref,
                "security_id": mapping.csd_security_id,
                "date": record.settlement_date.strftime("%Y-%m-%d")
            }
            
            response = await self.http_client.get(
                f"{endpoint}/settlements/verify",
                headers=headers,
                params=params
            )
            
            if response.status_code == 200:
                csd_data = response.json()
                
                # Verify units match
                csd_units = str(csd_data.get("quantity", "0"))
                if csd_units == record.units:
                    logger.info(f"Clearstream reconciliation SUCCESS for {record.external_ref}")
                    return True, None
                else:
                    error = f"Unit mismatch: on-chain={record.units}, CSD={csd_units}"
                    logger.warning(error)
                    return False, error
            else:
                error = f"Clearstream API error: {response.status_code}"
                logger.error(error)
                return False, error
                
        except Exception as e:
            return False, f"Clearstream reconciliation failed: {str(e)}"
    
    async def _reconcile_euroclear(
        self,
        record: SettlementRecord,
        mapping: CSDMapping
    ) -> Tuple[bool, Optional[str]]:
        """Reconcile with Euroclear"""
        try:
            if CSDSystem.EUROCLEAR.value not in self.credentials:
                return False, "Euroclear credentials not configured"
            
            creds = self.credentials[CSDSystem.EUROCLEAR.value]
            endpoint = creds.get("endpoint")
            api_key = creds.get("api_key")
            
            headers = {
                "X-API-Key": api_key,
                "Content-Type": "application/json"
            }
            
            payload = {
                "instruction_reference": record.external_ref,
                "isin": mapping.metadata.get("isin"),
                "settlement_date": record.settlement_date.isoformat(),
                "quantity": record.units
            }
            
            response = await self.http_client.post(
                f"{endpoint}/v1/settlement/verify",
                headers=headers,
                json=payload
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get("matched", False):
                    logger.info(f"Euroclear reconciliation SUCCESS for {record.external_ref}")
                    return True, None
                else:
                    error = f"Euroclear mismatch: {result.get('reason', 'Unknown')}"
                    return False, error
            else:
                return False, f"Euroclear API error: {response.status_code}"
                
        except Exception as e:
            return False, f"Euroclear reconciliation failed: {str(e)}"
    
    async def _reconcile_dtcc(
        self,
        record: SettlementRecord,
        mapping: CSDMapping
    ) -> Tuple[bool, Optional[str]]:
        """Reconcile with DTCC"""
        try:
            if CSDSystem.DTCC.value not in self.credentials:
                return False, "DTCC credentials not configured"
            
            # DTCC reconciliation logic
            # Note: DTCC APIs may have different patterns
            creds = self.credentials[CSDSystem.DTCC.value]
            
            logger.info(f"DTCC reconciliation for {record.external_ref}")
            
            # Placeholder for DTCC-specific reconciliation
            # In production, implement actual DTCC API calls
            
            return True, None
            
        except Exception as e:
            return False, f"DTCC reconciliation failed: {str(e)}"
    
    async def _reconcile_dpo_global(
        self,
        record: SettlementRecord,
        mapping: CSDMapping
    ) -> Tuple[bool, Optional[str]]:
        """Reconcile with DPO Global internal system"""
        try:
            if CSDSystem.DPO_GLOBAL.value not in self.credentials:
                return False, "DPO Global credentials not configured"
            
            creds = self.credentials[CSDSystem.DPO_GLOBAL.value]
            endpoint = creds.get("endpoint")
            api_key = creds.get("api_key")
            
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
            
            payload = {
                "settlement_id": record.external_ref,
                "investor": record.investor_address,
                "units": record.units,
                "timestamp": record.settlement_date.isoformat()
            }
            
            response = await self.http_client.post(
                f"{endpoint}/api/v1/settlements/verify",
                headers=headers,
                json=payload
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get("verified", False):
                    logger.info(f"DPO Global reconciliation SUCCESS for {record.external_ref}")
                    return True, None
                else:
                    return False, result.get("error", "Verification failed")
            else:
                return False, f"DPO Global API error: {response.status_code}"
                
        except Exception as e:
            return False, f"DPO Global reconciliation failed: {str(e)}"
    
    async def batch_reconcile(
        self,
        records: List[Tuple[SettlementRecord, CSDMapping]],
        max_concurrent: int = 5
    ) -> Dict[str, Dict]:
        """
        Reconcile multiple settlements concurrently
        
        Returns:
            Dict mapping external_ref to reconciliation results
        """
        results = {}
        
        semaphore = asyncio.Semaphore(max_concurrent)
        
        async def reconcile_with_semaphore(record, mapping):
            async with semaphore:
                success, error = await self.reconcile_settlement(record, mapping)
                return record.external_ref, {"success": success, "error": error}
        
        tasks = [
            reconcile_with_semaphore(record, mapping)
            for record, mapping in records
        ]
        
        completed = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in completed:
            if isinstance(result, Exception):
                logger.error(f"Batch reconciliation error: {result}")
            else:
                ref, data = result
                results[ref] = data
        
        return results
    
    async def generate_reconciliation_report(
        self,
        offering_contract: str,
        start_date: datetime,
        end_date: datetime
    ) -> Dict:
        """
        Generate a reconciliation report for a date range
        """
        # Fetch all settlements in date range
        # Compare on-chain vs CSD records
        # Identify discrepancies
        
        report = {
            "contract": offering_contract,
            "period": {
                "start": start_date.isoformat(),
                "end": end_date.isoformat()
            },
            "summary": {
                "total_settlements": 0,
                "reconciled": 0,
                "pending": 0,
                "discrepancies": 0
            },
            "discrepancies": [],
            "generated_at": datetime.utcnow().isoformat()
        }
        
        # TODO: Implement full report generation logic
        
        return report
    
    async def close(self):
        """Close HTTP client"""
        await self.http_client.aclose()


# Example usage
async def main():
    """Example reconciliation flow"""
    
    credentials = {
        "CLEARSTREAM": {
            "api_key": "your-clearstream-api-key",
            "endpoint": "https://api.clearstream.com/v1"
        },
        "EUROCLEAR": {
            "api_key": "your-euroclear-api-key",
            "endpoint": "https://api.euroclear.com"
        },
        "DPO_GLOBAL": {
            "api_key": "your-dpo-api-key",
            "endpoint": "https://api.dpo-global.com"
        }
    }
    
    service = CSDReconciliationService(credentials)
    
    # Example settlement record
    settlement = SettlementRecord(
        investor_address="0x1234...",
        units="1000000000000000000",  # 1 token
        settlement_system=CSDSystem.CLEARSTREAM,
        external_ref="CLSTM-2025-001",
        settlement_date=datetime.utcnow(),
        block_number=12345,
        transaction_hash="0xabc..."
    )
    
    mapping = CSDMapping(
        csd_system=CSDSystem.CLEARSTREAM,
        csd_security_id="US0378331005",
        active=True
    )
    
    success, error = await service.reconcile_settlement(settlement, mapping)
    
    if success:
        logger.info("✅ Reconciliation successful")
    else:
        logger.error(f"❌ Reconciliation failed: {error}")
    
    await service.close()


if __name__ == "__main__":
    asyncio.run(main())
