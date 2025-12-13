import json
from typing import Any, Dict

from django.utils import timezone
from backend.models.issuance_models import (
    Offering,
    Investor,
    Commitment,
    UnitsIssued,
    SettlementRecord,
    Identifier,
    CSDMapping,
)

# Optional: if you want to validate against JSON schemas later
# from jsonschema import validate


EVENT_HANDLERS = {}


def event_handler(event_name: str):
    """
    Decorator to register handlers for specific event types.
    """
    def wrapper(fn):
        EVENT_HANDLERS[event_name] = fn
        return fn
    return wrapper


def ingest_event(event_payload: Dict[str, Any]) -> None:
    """
    Entry point for all issuance-related events.

    event_payload is expected to match the JSON schemas in /schemas.
    """
    event_name = event_payload.get("event")
    if not event_name:
        return

    handler = EVENT_HANDLERS.get(event_name)
    if handler is None:
        return

    handler(event_payload)


@event_handler("OfferingConfigured")
def handle_offering_configured(payload: Dict[str, Any]) -> None:
    identifiers_data = payload.get("identifiers", {})

    identifier, _ = Identifier.objects.update_or_create(
        internal_asset_id=identifiers_data.get("internal_asset_id"),
        defaults={
            "isin": identifiers_data.get("isin"),
            "lei": identifiers_data.get("lei"),
            "upi": identifiers_data.get("upi"),
            "cusip": identifiers_data.get("cusip"),
            "clearstream_id": identifiers_data.get("clearstream_id"),
            "euroclear_id": identifiers_data.get("euroclear_id"),
        },
    )

    Offering.objects.update_or_create(
        internal_asset_id=identifiers_data.get("internal_asset_id"),
        defaults={
            "offering_type": payload.get("offering_type"),
            "max_raise_amount": payload.get("max_raise_amount"),
            "lockup_period": payload.get("lockup_period"),
            "start_timestamp": payload.get("start_timestamp"),
            "end_timestamp": payload.get("end_timestamp"),
            "base_currency": payload.get("base_currency"),
            "identifier": identifier,
            "last_event_tx_hash": payload.get("transaction_hash"),
        },
    )


@event_handler("InvestorWhitelisted")
def handle_investor_whitelisted(payload: Dict[str, Any]) -> None:
    Investor.objects.update_or_create(
        wallet_address=payload.get("investor").lower(),
        defaults={
            "jurisdiction": payload.get("jurisdiction"),
            "kyc_passed": payload.get("kyc_passed", False),
            "aml_passed": payload.get("aml_passed", False),
            "last_event_tx_hash": payload.get("transaction_hash"),
        },
    )


@event_handler("CommitmentRecorded")
def handle_commitment_recorded(payload: Dict[str, Any]) -> None:
    wallet = payload.get("investor").lower()
    investor, _ = Investor.objects.get_or_create(wallet_address=wallet)

    Commitment.objects.create(
        investor=investor,
        amount=payload.get("amount"),
        currency=payload.get("currency"),
        payment_reference=payload.get("payment_reference"),
        tx_hash=payload.get("transaction_hash"),
        committed_at=timezone.now(),
    )


@event_handler("UnitsIssued")
def handle_units_issued(payload: Dict[str, Any]) -> None:
    wallet = payload.get("investor").lower()
    investor, _ = Investor.objects.get_or_create(wallet_address=wallet)

    identifiers_data = payload.get("identifiers", {})
    identifier = None
    internal_asset_id = identifiers_data.get("internal_asset_id")

    if internal_asset_id:
        identifier, _ = Identifier.objects.get_or_create(
            internal_asset_id=internal_asset_id
        )

    UnitsIssued.objects.create(
        investor=investor,
        units=payload.get("units"),
        lockup_release=payload.get("lockup_release"),
        isin=identifiers_data.get("isin"),
        lei=identifiers_data.get("lei"),
        upi=identifiers_data.get("upi"),
        identifier=identifier,
        tx_hash=payload.get("transaction_hash"),
        issued_at=timezone.now(),
    )


@event_handler("SettlementRecorded")
def handle_settlement_recorded(payload: Dict[str, Any]) -> None:
    wallet = payload.get("investor").lower()
    investor, _ = Investor.objects.get_or_create(wallet_address=wallet)

    SettlementRecord.objects.create(
        investor=investor,
        units=payload.get("units"),
        settlement_system=payload.get("settlement_system"),
        external_reference=payload.get("external_reference"),
        tx_hash=payload.get("transaction_hash"),
        settled_at=timezone.now(),
    )


@event_handler("Finalized")
def handle_finalized(payload: Dict[str, Any]) -> None:
    tx_hash = payload.get("transaction_hash")

    Offering.objects.filter(last_event_tx_hash=tx_hash).update(
        total_committed=payload.get("total_committed"),
        total_units_issued=payload.get("total_units_issued"),
        finalized_at=payload.get("finalized_at"),
        is_finalized=True,
    )
