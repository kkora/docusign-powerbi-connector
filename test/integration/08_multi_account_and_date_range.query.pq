[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.MultiAccount;

// F05: default account selection (no accountId given) still resolves to ACCT-1 as before.
navDefault = DocuSignPowerBI.ContentsWithDates("Demo", "2024-10-01");
accountsDefault = Table.SelectRows(navDefault, each [Name] = "Accounts"){0}[Data];

// F05: explicit account selection pulls data from the OTHER account, not the default.
navExplicit = DocuSignPowerBI.ContentsWithDates("Demo", "2024-10-01", null, "ACCT-2");
envelopesExplicit = Table.SelectRows(navExplicit, each [Name] = "Envelopes"){0}[Data];

// F05: an accountId the user doesn't have access to must fail clearly, before any data call.
unauthorizedAccountResult = try Table.RowCount(Table.SelectRows(DocuSignPowerBI.ContentsWithDates("Demo", "2024-10-01", null, "ACCT-DOES-NOT-EXIST"), each [Name] = "Envelopes"){0}[Data]);

// F02: fromDate after toDate must be rejected before any HTTP call.
invalidRangeResult = try Table.RowCount(Table.SelectRows(DocuSignPowerBI.ContentsWithDates("Demo", "2024-05-01", "2024-01-01"), each [Name] = "Envelopes"){0}[Data]);

shared DocuSignPowerBI.Test.Integration.MultiAccount = PQTest(
    [Owner = "automation", Traits = [Category = "Integration-MultiAccount"]],
    {
        // F05: Accounts table lists every accessible account with the right default flag.
        Fact("F05 Accounts table lists both accessible accounts", 2, Table.RowCount(accountsDefault)),
        Fact("F05 Accounts table flags exactly one default account", 1, Table.RowCount(Table.SelectRows(accountsDefault, each [IsDefault] = true))),

        // F05: explicit accountId overrides the default and pulls that account's data.
        Fact("F05 explicit accountId selection retrieves the other account's envelope", "env-acct2-1", envelopesExplicit{0}[EnvelopeId]),
        Fact("F05 explicit accountId selection stamps the correct AccountId", "ACCT-2", envelopesExplicit{0}[AccountId]),

        // F05: an inaccessible accountId is rejected with a clear error, not a confusing API failure.
        Fact("F05 an unauthorized/unknown accountId is rejected", true, unauthorizedAccountResult[HasError]),
        Fact("F05 the unauthorized-account error reason is DocuSign.Account", "DocuSign.Account", unauthorizedAccountResult[Error][Reason]),

        // F02: fromDate after toDate is rejected with a clear, actionable error.
        Fact("F02 fromDate after toDate is rejected", true, invalidRangeResult[HasError]),
        Fact("F02 the invalid-date-range error reason is DocuSign.Config", "DocuSign.Config", invalidRangeResult[Error][Reason])
    });
