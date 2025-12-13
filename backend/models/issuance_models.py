from django.db import models


class Identifier(models.Model):
    internal_asset_id = models.CharField(max_length=128, unique=True)
    isin = models.CharField(max_length=32, blank=True, null=True)
    lei = models.CharField(max_length=32, blank=True, null=True)
    upi = models.CharField(max_length=64, blank=True, null=True)
    cusip = models.CharField(max_length=32, blank=True, null=True)
    clearstream_id = models.CharField(max_length=64, blank=True, null=True)
    euroclear_id = models.CharField(max_length=64, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class Offering(models.Model):
    internal_asset_id = models.CharField(max_length=128, unique=True)
    offering_type = models.CharField(max_length=64)
    max_raise_amount = models.BigIntegerField()
    lockup_period = models.BigIntegerField()
    start_timestamp = models.BigIntegerField()
    end_timestamp = models.BigIntegerField()
    base_currency = models.CharField(max_length=16)

    identifier = models.ForeignKey(
        Identifier, on_delete=models.PROTECT, related_name="offerings"
    )

    total_committed = models.BigIntegerField(default=0)
    total_units_issued = models.BigIntegerField(default=0)
    is_finalized = models.BooleanField(default=False)
    finalized_at = models.BigIntegerField(blank=True, null=True)

    last_event_tx_hash = models.CharField(max_length=100, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class Investor(models.Model):
    wallet_address = models.CharField(max_length=64, unique=True)
    jurisdiction = models.CharField(max_length=16, blank=True, null=True)
    kyc_passed = models.BooleanField(default=False)
    aml_passed = models.BooleanField(default=False)

    last_event_tx_hash = models.CharField(max_length=100, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class Commitment(models.Model):
    investor = models.ForeignKey(
        Investor, on_delete=models.CASCADE, related_name="commitments"
    )
    amount = models.BigIntegerField()
    currency = models.CharField(max_length=16)
    payment_reference = models.CharField(max_length=128)

    tx_hash = models.CharField(max_length=100)
    committed_at = models.DateTimeField()

    created_at = models.DateTimeField(auto_now_add=True)


class UnitsIssued(models.Model):
    investor = models.ForeignKey(
        Investor, on_delete=models.CASCADE, related_name="units_issued"
    )
    units = models.BigIntegerField()
    lockup_release = models.BigIntegerField()

    isin = models.CharField(max_length=32, blank=True, null=True)
    lei = models.CharField(max_length=32, blank=True, null=True)
    upi = models.CharField(max_length=64, blank=True, null=True)
    identifier = models.ForeignKey(
        Identifier,
        on_delete=models.SET_NULL,
        related_name="issuance_records",
        blank=True,
        null=True,
    )

    tx_hash = models.CharField(max_length=100)
    issued_at = models.DateTimeField()

    created_at = models.DateTimeField(auto_now_add=True)


class SettlementRecord(models.Model):
    investor = models.ForeignKey(
        Investor, on_delete=models.CASCADE, related_name="settlements"
    )
    units = models.BigIntegerField()
    settlement_system = models.CharField(max_length=64)
    external_reference = models.CharField(max_length=128)

    tx_hash = models.CharField(max_length=100)
    settled_at = models.DateTimeField()

    created_at = models.DateTimeField(auto_now_add=True)


class CSDMapping(models.Model):
    identifier = models.OneToOneField(
        Identifier, on_delete=models.CASCADE, related_name="csd_mapping"
    )

    clearstream_asset_id = models.CharField(max_length=64, blank=True, null=True)
    clearstream_settlement_reference = models.CharField(
        max_length=128, blank=True, null=True
    )
    clearstream_status = models.CharField(max_length=32, blank=True, null=True)

    euroclear_asset_id = models.CharField(max_length=64, blank=True, null=True)
    euroclear_settlement_reference = models.CharField(
        max_length=128, blank=True, null=True
    )
    euroclear_status = models.CharField(max_length=32, blank=True, null=True)

    last_updated = models.DateTimeField(auto_now=True)
