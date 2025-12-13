// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Full DTCC-style Issuance Contract
/// @notice Central on-chain record for a single security offering:
///         identifiers, metadata, documents, issuance, lockups, and settlement events.

interface IComplianceModule {
    function isInvestorEligible(address investor, bytes32 jurisdiction) external view returns (bool);
}

contract FullIssuanceContract {
    // ============ Roles ============

    address public issuer;              // Legal issuer (entity behind the offer)
    address public complianceOfficer;   // Compliance / legal operations
    address public settlementOperator;  // Ops handling settlement finalization

    modifier onlyIssuer() {
        require(msg.sender == issuer, "NOT_ISSUER");
        _;
    }

    modifier onlyCompliance() {
        require(msg.sender == complianceOfficer, "NOT_COMPLIANCE");
        _;
    }

    modifier onlySettlement() {
        require(msg.sender == settlementOperator, "NOT_SETTLEMENT");
        _;
    }

    // ============ Identifiers & Offering Configuration ============

    struct Identifiers {
        string isin;        // e.g. US0378331005
        string lei;         // 20-char Legal Entity Identifier
        string upi;         // Unique Product Identifier
        string cusip;       // Optional, US-specific
        string clearstreamId;
        string euroclearId;
        string internalAssetId;  // Your own DPO internal identifier
    }

    struct OfferingConfig {
        string offeringType;       // e.g. "REG_D_506C", "REG_CF", "144A"
        uint256 maxRaiseAmount;    // Max total amount (in smallest unit of reference currency)
        uint256 lockupPeriod;      // Seconds from issuance to free transfer
        uint256 startTimestamp;    // Offering open time
        uint256 endTimestamp;      // Offering close time
        string baseCurrency;       // "USD", "EUR", etc.
    }

    struct DocumentRefs {
        string termSheetCid;       // IPFS CID for term sheet
        string offeringMemorandumCid;
        string subscriptionAgreementCid;
        string kycPolicyCid;
    }

    Identifiers public identifiers;
    OfferingConfig public offeringConfig;
    DocumentRefs public documents;

    // ============ State ============

    uint256 public totalCommitted;        // Total committed by investors (off-chain payments matched)
    uint256 public totalUnitsIssued;      // On-chain units representing the security
    bool public finalized;               // Once true, issuance is closed and configuration is immutable

    IComplianceModule public complianceModule;

    // ============ Per-investor state ============

    struct InvestorPosition {
        uint256 committedAmount;  // Off-chain committed cash equivalent
        uint256 unitsIssued;      // On-chain units allocated
        uint256 lockupRelease;    // Timestamp when units become freely transferable
        bool kycPassed;
        bool amlPassed;
        bytes32 jurisdiction;     // 2/3-letter country / region code
    }

    mapping(address => InvestorPosition) public investorPositions;

    // ============ Events ============

    event RolesConfigured(
        address indexed issuer,
        address indexed complianceOfficer,
        address indexed settlementOperator
    );

    event OfferingConfigured(OfferingConfig config, Identifiers identifiers);
    event DocumentsUpdated(DocumentRefs docs);

    event InvestorWhitelisted(
        address indexed investor,
        bytes32 jurisdiction,
        bool kycPassed,
        bool amlPassed
    );

    event CommitmentRecorded(
        address indexed investor,
        uint256 amount,
        string currency,      // Mirrors offeringConfig.baseCurrency
        string paymentRef     // PSP / bank reference ID
    );

    event UnitsIssued(
        address indexed investor,
        uint256 units,
        uint256 lockupRelease,
        string isin,
        string lei,
        string upi
    );

    event SettlementRecorded(
        address indexed investor,
        uint256 units,
        string settlementSystem,  // "CLEARSTREAM", "EUROCLEAR", "DTCC"
        string externalRef        // external settlement reference
    );

    event Finalized(
        uint256 totalCommitted,
        uint256 totalUnitsIssued,
        uint256 timestamp
    );

    // ============ Errors ============

    error AlreadyFinalized();
    error NotInOfferingWindow();
    error MaxRaiseExceeded();
    error InvestorNotEligible();
    error InvalidConfiguration();

    // ============ Constructor ============

    constructor(
        address _issuer,
        address _complianceOfficer,
        address _settlementOperator,
        Identifiers memory _identifiers,
        OfferingConfig memory _offeringConfig,
        DocumentRefs memory _documents,
        address _complianceModule
    ) {
        if (
            _issuer == address(0) ||
            _complianceOfficer == address(0) ||
            _settlementOperator == address(0)
        ) {
            revert InvalidConfiguration();
        }

        issuer = _issuer;
        complianceOfficer = _complianceOfficer;
        settlementOperator = _settlementOperator;
        identifiers = _identifiers;
        offeringConfig = _offeringConfig;
        documents = _documents;
        complianceModule = IComplianceModule(_complianceModule);

        emit RolesConfigured(_issuer, _complianceOfficer, _settlementOperator);
        emit OfferingConfigured(_offeringConfig, _identifiers);
        emit DocumentsUpdated(_documents);
    }

    // ============ Admin updates (pre-finalization only) ============

    modifier onlyBeforeFinalized() {
        if (finalized) revert AlreadyFinalized();
        _;
    }

    function updateDocuments(
        DocumentRefs calldata _docs
    ) external onlyIssuer onlyBeforeFinalized {
        documents = _docs;
        emit DocumentsUpdated(_docs);
    }

    // Optionally allow updating time window / caps before finalization
    function updateOfferingConfig(
        OfferingConfig calldata _cfg
    ) external onlyIssuer onlyBeforeFinalized {
        offeringConfig = _cfg;
        emit OfferingConfigured(_cfg, identifiers);
    }

    // ============ Investor onboarding & commitments ============

    /// @notice Called by complianceOfficer after KYC/AML is done off-chain.
    function whitelistInvestor(
        address investor,
        bytes32 jurisdiction,
        bool kycPassed,
        bool amlPassed
    ) external onlyCompliance onlyBeforeFinalized {
        investorPositions[investor].kycPassed = kycPassed;
        investorPositions[investor].amlPassed = amlPassed;
        investorPositions[investor].jurisdiction = jurisdiction;

        emit InvestorWhitelisted(investor, jurisdiction, kycPassed, amlPassed);
    }

    /// @notice Record a commitment (off-chain payment matched but not yet tokenized).
    function recordCommitment(
        address investor,
        uint256 amount,
        string calldata currency,
        string calldata paymentRef
    ) external onlySettlement onlyBeforeFinalized {
        // Offering window check
        if (
            block.timestamp < offeringConfig.startTimestamp ||
            block.timestamp > offeringConfig.endTimestamp
        ) {
            revert NotInOfferingWindow();
        }

        // Simple currency alignment (off-chain: FX handled by PSP / bank)
        require(
            keccak256(bytes(currency)) == keccak256(bytes(offeringConfig.baseCurrency)),
            "CURRENCY_MISMATCH"
        );

        InvestorPosition storage pos = investorPositions[investor];

        // Compliance module check (jurisdictional logic)
        if (
            address(complianceModule) != address(0) &&
            !complianceModule.isInvestorEligible(investor, pos.jurisdiction)
        ) {
            revert InvestorNotEligible();
        }

        pos.committedAmount += amount;
        totalCommitted += amount;

        if (totalCommitted > offeringConfig.maxRaiseAmount) {
            revert MaxRaiseExceeded();
        }

        emit CommitmentRecorded(investor, amount, currency, paymentRef);
    }

    // ============ Issuance / tokenization ============

    /// @notice Called once the off-chain cash has settled and you want to reflect units.
    /// @dev This is where you would integrate with DTCCCompliantSTO or another token contract.
    function issueUnits(
        address investor,
        uint256 units
    ) external onlySettlement onlyBeforeFinalized {
        InvestorPosition storage pos = investorPositions[investor];

        require(pos.kycPassed && pos.amlPassed, "KYC/AML_NOT_PASSED");
        require(units > 0, "ZERO_UNITS");

        // In a real integration, this is where you'd:
        // - call a token contract to mint to `investor`
        // - or update internal balance mapping if you embed balances here

        pos.unitsIssued += units;
        totalUnitsIssued += units;

        uint256 lockupRelease = block.timestamp + offeringConfig.lockupPeriod;
        pos.lockupRelease = lockupRelease;

        emit UnitsIssued(
            investor,
            units,
            lockupRelease,
            identifiers.isin,
            identifiers.lei,
            identifiers.upi
        );
    }

    // ============ Settlement reporting ============

    /// @notice Records that units for this investor have been booked in a given settlement system.
    function recordSettlement(
        address investor,
        uint256 units,
        string calldata settlementSystem,
        string calldata externalRef
    ) external onlySettlement {
        // This is a pure reporting hook: DTCC / Clearstream / Euroclear reference can be captured here.
        emit SettlementRecorded(investor, units, settlementSystem, externalRef);
    }

    // ============ Finalization ============

    /// @notice Once called, offering is closed and configs become immutable.
    function finalizeOffering() external onlyIssuer onlyBeforeFinalized {
        finalized = true;
        emit Finalized(totalCommitted, totalUnitsIssued, block.timestamp);
    }

    // ============ View helpers ============

    function getInvestorPosition(
        address investor
    ) external view returns (InvestorPosition memory) {
        return investorPositions[investor];
    }

    function isInLockup(address investor) external view returns (bool) {
        InvestorPosition memory pos = investorPositions[investor];
        return block.timestamp < pos.lockupRelease;
    }
}
