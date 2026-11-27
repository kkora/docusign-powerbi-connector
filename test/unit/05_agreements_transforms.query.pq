[Version = "1.0.0"]
section DocuSignPowerBI.Test.Agreements;

// ===== Navigator Agreements: pure transforms (no network). All date-window flags are pinned
// to a fixed asOf date so these Facts never drift with the wall clock. =====

AsOf = #date(2026, 11, 26);

// Modeled on the live-verified Demo payload (see test/mocks/navigator-agreements-list.json).
msaRaw = [
    id = "ag-msa-1",
    title = "Master Services Agreement",
    file_name = "MSA - Example Vendor.docx",
    document_id = "doc-msa-1",
    #"type" = "Msa",
    category = "BusinessServices",
    status = "COMPLETE",
    review_status = "PENDING",
    metadata = [ created_at = "2026-11-27T03:46:59.573335+00:00", modified_at = "2026-11-27T03:48:15.493053+00:00" ],
    parties = {
        [ id = "party-a", name_in_agreement = "New Jersey Economic Development Authority" ],
        [ id = "party-b", name_in_agreement = "BrightPath Consulting Inc." ]
    },
    provisions = [
        effective_date = "2026-03-01T00:00:00",
        expiration_date = "2027-02-28T00:00:00",
        execution_date = "2026-02-20T00:00:00",
        term_length = "P1Y",
        governing_law = "New Jersey",
        payment_terms_due_date = "THIRTY_DAYS",
        can_charge_late_payment_fees = true,
        late_payment_fee_percent = 1.5,
        liability_cap_duration = "P12M",
        price_cap_percent_increase = 5,
        renewal_type = "AUTO_RENEW",
        renewal_notice_period = "P60D",
        renewal_notice_date = "2026-12-30T00:00:00",
        auto_renewal_term_length = "P1Y",
        termination_period_for_cause = "P15D",
        termination_period_for_convenience = "P45D",
        total_agreement_value = 240000,
        total_agreement_value_currency_code = "USD"
    ],
    custom_provisions = [ c_Department_cOtkJt = "legal", c_LeaseDeposit_G75EQU = 17500 ],
    languages = {"en"},
    source_name = "UploadCenter"
];

// FIXED_TERM: Navigator still emits renewal_notice_date (= expiration), but there is no renewal
// to act on, so the connector must null it out and keep the renewing flags at 0.
ndaRaw = [
    id = "ag-nda-2",
    title = "Mutual Non-Disclosure Agreement",
    #"type" = "Nda",
    status = "COMPLETE",
    provisions = [
        effective_date = "2026-01-15T00:00:00",
        expiration_date = "2028-01-14T00:00:00",
        term_length = "P2Y",
        nda_type = "MUTUAL",
        renewal_type = "FIXED_TERM",
        renewal_notice_date = "2028-01-14T00:00:00",
        confidentiality_obligation_period = "P5Y"
    ],
    custom_provisions = [],
    parties = { [ id = "party-c", name_in_agreement = "Garden State Analytics LLC" ] }
];

// Non-contract upload: empty provisions, no parties field at all (live-observed shape).
formRaw = [
    id = "ag-form-3",
    title = "Bank Account Verification Form",
    #"type" = "Other",
    status = "COMPLETE",
    provisions = [],
    custom_provisions = []
];

// Takes effect inside the 30-day window relative to AsOf.
futureRaw = [
    id = "ag-future-4",
    title = "Future Services Agreement",
    #"type" = "Msa",
    status = "COMPLETE",
    provisions = [ effective_date = "2026-12-15T00:00:00", renewal_type = "AUTO_RENEW" ]
];

agreements = DocuSignPowerBI.BuildAgreementsTable({msaRaw, ndaRaw, formRaw, futureRaw}, "ACCT-1", AsOf);
msa = Table.SelectRows(agreements, each [Id] = "ag-msa-1"){0};
nda = Table.SelectRows(agreements, each [Id] = "ag-nda-2"){0};
form = Table.SelectRows(agreements, each [Id] = "ag-form-3"){0};
future = Table.SelectRows(agreements, each [Id] = "ag-future-4"){0};

partiesRows = DocuSignPowerBI.FlattenAgreementParties({msaRaw, ndaRaw, formRaw}, "ACCT-1");
customFieldRows = DocuSignPowerBI.FlattenAgreementCustomFields({msaRaw, ndaRaw, formRaw}, "ACCT-1");
depositRow = List.First(List.Select(customFieldRows, each [FieldName] = "LeaseDeposit"));

shared DocuSignPowerBI.Test.Agreements = PQTest(
    [Owner = "automation", Traits = [Category = "Unit-Agreements"]],
    {
        // DurationToDays: ISO-8601 durations to approximate day counts (Y=365, M=30, W=7, D=1).
        Fact("DurationToDays parses years", 365, DocuSignPowerBI.DurationToDays("P1Y")),
        Fact("DurationToDays parses days", 60, DocuSignPowerBI.DurationToDays("P60D")),
        Fact("DurationToDays parses months", 360, DocuSignPowerBI.DurationToDays("P12M")),
        Fact("DurationToDays parses weeks", 14, DocuSignPowerBI.DurationToDays("P2W")),
        Fact("DurationToDays parses combined components", 545, DocuSignPowerBI.DurationToDays("P1Y6M")),
        Fact("DurationToDays ignores the time part", 1, DocuSignPowerBI.DurationToDays("P1DT12H")),
        Fact("DurationToDays returns null for non-ISO text", null, DocuSignPowerBI.DurationToDays("45 days")),
        Fact("DurationToDays returns null for null", null, DocuSignPowerBI.DurationToDays(null)),
        Fact("DurationToDays returns null for a bare P", null, DocuSignPowerBI.DurationToDays("P")),

        // Pass-through field mapping.
        Fact("Agreement identity and type map from the raw payload", {"ag-msa-1", "Msa", "BusinessServices", "ACCT-1"}, {msa[Id], msa[AgreementType], msa[Category], msa[AccountId]}),
        Fact("Provision scalars map (payment terms, late fee, governing law)", {"THIRTY_DAYS", 1.5, "New Jersey"}, {msa[PaymentTerms], msa[LatePaymentFeePercent], msa[GoverningLaw]}),
        Fact("Agreement values map with currency", {240000, "USD"}, {msa[TotalValue], msa[TotalValueCurrency]}),
        Fact("Languages joins to a single text value", "en", msa[Languages]),
        Fact("Metadata timestamps map to CreatedDate/ModifiedDate", true, #datetime(2026, 11, 27, 3, 46, 59) <= msa[CreatedDate] and msa[CreatedDate] < #datetime(2026, 11, 27, 3, 47, 0)),

        // Derived duration-day companions and dates.
        Fact("TermLengthDays derives from the ISO duration", 365, msa[TermLengthDays]),
        Fact("RenewalNoticePeriodDays derives from the ISO duration", 60, msa[RenewalNoticePeriodDays]),
        Fact("TerminationNoticeDueDate is expiration minus the convenience notice period", #datetime(2027, 1, 14, 0, 0, 0), msa[TerminationNoticeDueDate]),
        Fact("IsAutoRenewal is true for AUTO_RENEW", true, msa[IsAutoRenewal]),
        Fact("IsAutoRenewal is false for FIXED_TERM", false, nda[IsAutoRenewal]),

        // Window flags, pinned to AsOf = 2026-11-26.
        Fact("An in-term agreement is active", 1, msa[IsActive]),
        Fact("Renewal notice 34 days out: in the 90-day window, not the 30-day window", {0, 1}, {msa[IsRenewingIn30days], msa[IsRenewingIn90days]}),
        Fact("Expiration 94 days out is not in the 90-day window", 0, msa[IsExpiringIn90days]),
        Fact("FIXED_TERM agreements never count as renewing", {0, 0}, {nda[IsRenewingIn30days], nda[IsRenewingIn90days]}),
        Fact("FIXED_TERM renewal notice date is nulled out", null, nda[RenewalNoticeDate]),
        Fact("A future agreement is not active but is taking effect within 30 days", {0, 1, 1}, {future[IsActive], future[IsTakingEffectIn30days], future[IsActiveIn30days]}),
        Fact("Empty provisions yield null dates and inactive flags, not errors", {null, 0, 0}, {form[EffectiveDate], form[IsActive], form[IsExpiringIn90days]}),

        // Year/month derivations.
        Fact("Year numbers derive from provision dates", {2026, 2027}, {msa[EffectiveYearNumber], msa[ExpirationYearNumber]}),
        Fact("MonthYear derives from the effective date", Date.ToText(#date(2026, 3, 1), "MMM yyyy"), msa[EffectiveMonthYear]),

        // Parties flatten.
        Fact("One row per party per agreement", 3, List.Count(partiesRows)),
        Fact("Party rows carry the agreement key and party name", {"ag-msa-1", "party-a", "New Jersey Economic Development Authority"}, (let r = partiesRows{0} in {r[AgreementId], r[PartyId], r[PartyName]})),
        Fact("An agreement without a parties field yields no party rows", 0, List.Count(List.Select(partiesRows, each [AgreementId] = "ag-form-3"))),

        // Custom provisions unpivot.
        Fact("custom_provisions unpivots to one row per field", 2, List.Count(customFieldRows)),
        Fact("Non-text custom values are stringified", {"ag-msa-1", "17500"}, {depositRow[AgreementId], depositRow[FieldValue]}),
        Fact("The raw generated key is preserved alongside the cleaned name", "c_LeaseDeposit_G75EQU", depositRow[FieldKey]),
        Fact("Empty custom_provisions yield no rows", 0, List.Count(List.Select(customFieldRows, each [AgreementId] = "ag-nda-2"))),

        // CleanCustomFieldName: Navigator's generated "c_<Name>_<6-char suffix>" keys.
        Fact("Generated key cleans to the display name", "RiskLevel", DocuSignPowerBI.CleanCustomFieldName("c_RiskLevel_pfcXAX")),
        Fact("c_ prefix without a generated suffix is still stripped", "Description", DocuSignPowerBI.CleanCustomFieldName("c_Description")),
        Fact("A non-6-char tail is not treated as a suffix", "Custom_Pay", DocuSignPowerBI.CleanCustomFieldName("c_Custom_Pay")),
        Fact("Keys without the c_ prefix pass through unchanged", "lease_deposit", DocuSignPowerBI.CleanCustomFieldName("lease_deposit")),
        Fact("Null keys stay null", null, DocuSignPowerBI.CleanCustomFieldName(null))
    });
