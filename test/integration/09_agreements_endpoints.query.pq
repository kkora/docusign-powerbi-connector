[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.Agreements;

// Navigator agreement tables fetched end-to-end through Contents() against the HTTP mocks:
// two pages of /v1/accounts/{id}/agreements stitched together via _links.next (ctoken paging).
// Date-window flags (IsExpiringIn90days etc.) are asserted only in the unit suite, where the
// as-of date is pinned; here the mocks' dates would make them drift with the wall clock.
nav = DocuSignPowerBI.ContentsWithDates("Demo", "2024-10-01");
agreements = Table.SelectRows(nav, each [Name] = "Agreements"){0}[Data];
parties = Table.SelectRows(nav, each [Name] = "Parties"){0}[Data];
customFields = Table.SelectRows(nav, each [Name] = "CustomField"){0}[Data];

msa = Table.SelectRows(agreements, each [Id] = "ag-msa-1"){0};
form = Table.SelectRows(agreements, each [Id] = "ag-form-2"){0};
lease = Table.SelectRows(agreements, each [Id] = "ag-lease-3"){0};
leaseParty = Table.SelectRows(parties, each [AgreementId] = "ag-lease-3"){0};

shared DocuSignPowerBI.Test.Integration.Agreements = PQTest(
    [Owner = "automation", Traits = [Category = "Integration-Agreements"]],
    {
        // Pagination: page 2 is reached by following the relative _links.next href.
        Fact("Agreements from both Navigator pages are combined", 3, Table.RowCount(agreements)),
        Fact("The page-2 agreement is present with its metadata", {"Commercial Office Lease Agreement", "Lease"}, {lease[Title], lease[AgreementType]}),

        // Field mapping through the live fetch path.
        Fact("Agreement identity maps (account, type, category)", {"ACCT-1", "Msa", "BusinessServices"}, {msa[AccountId], msa[AgreementType], msa[Category]}),
        Fact("Renewal provisions map (type, auto flag, notice days)", {"AUTO_RENEW", true, 60}, {msa[RenewalType], msa[IsAutoRenewal], msa[RenewalNoticePeriodDays]}),
        Fact("Agreement value maps with currency", {240000, "USD"}, {msa[TotalValue], msa[TotalValueCurrency]}),
        Fact("TerminationNoticeDueDate derives from expiration minus the convenience period", #datetime(2027, 1, 14, 0, 0, 0), msa[TerminationNoticeDueDate]),
        Fact("An uploaded agreement has no EnvelopeId", null, msa[EnvelopeId]),
        Fact("An extraction-free document round-trips with null provisions", {null, null}, {form[EffectiveDate], form[TotalValue]}),

        // Parties table.
        Fact("One party row per party across all agreements", 3, Table.RowCount(parties)),
        Fact("Party rows carry account, agreement key, and name", {"ACCT-1", "Trenton Commerce Center Partners LP"}, {leaseParty[AccountId], leaseParty[PartyName]}),

        // CustomField table.
        Fact("custom_provisions unpivot to one row per field", 2, Table.RowCount(customFields)),
        Fact("Generated keys are cleaned to display names, raw key preserved", {"c_LeaseDeposit_G75EQU", "17500"}, (let r = Table.SelectRows(customFields, each [FieldName] = "LeaseDeposit"){0} in {r[FieldKey], r[FieldValue]}))
    });
