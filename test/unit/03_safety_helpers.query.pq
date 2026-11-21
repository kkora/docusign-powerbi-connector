[Version = "1.0.0"]
section DocuSignPowerBI.Test.Safety;

resolvedExplicit = DocuSignPowerBI.ResolveFromDate("2024-06-15");
resolvedDefault = DocuSignPowerBI.ResolveFromDate(null);
resolvedBlank = DocuSignPowerBI.ResolveFromDate("   ");
badFromDate = try DocuSignPowerBI.ResolveFromDate("not-a-date");

invalidJson = try DocuSignPowerBI.SafeJsonDocument(Text.ToBinary("NOT-JSON-AT-ALL{{{"));
validJson = DocuSignPowerBI.SafeJsonDocument(Text.ToBinary("{""a"":1}"));

shared DocuSignPowerBI.Test.Safety = PQTest(
    [Owner = "automation", Traits = [Category = "Unit-Safety"]],
    {
        // Configurable FromDate: explicit value passes through validated; blank/null fall back to a computed default.
        Fact("ResolveFromDate passes an explicit valid date through unchanged", "2024-06-15", resolvedExplicit),
        Fact("ResolveFromDate defaults a null fromDate to a valid YYYY-MM-DD date", true, (try Date.FromText(resolvedDefault) otherwise null) <> null),
        Fact("ResolveFromDate defaults a blank fromDate the same way as null", true, (try Date.FromText(resolvedBlank) otherwise null) <> null),
        Fact("ResolveFromDate rejects a malformed fromDate instead of passing it to the API", true, badFromDate[HasError]),

        // Null-safe JSON parsing (API-10 / DATA null-safety).
        Fact("SafeJsonDocument raises a clear DocuSign.InvalidResponse error for non-JSON bodies", true, invalidJson[HasError]),
        Fact("SafeJsonDocument's error identifies the failure as an invalid API response", "DocuSign.InvalidResponse", invalidJson[Error][Reason]),
        Fact("SafeJsonDocument parses well-formed JSON normally", 1, validJson[a]),

        // SafeInt / SafeNumber: DocuSign returns numeric fields as strings, and sometimes omits them.
        Fact("SafeInt parses a numeric string", 42, DocuSignPowerBI.SafeInt("42")),
        Fact("SafeInt defaults a null value to 0", 0, DocuSignPowerBI.SafeInt(null)),
        Fact("SafeInt defaults a non-numeric string to 0 rather than erroring", 0, DocuSignPowerBI.SafeInt("not-a-number")),
        Fact("SafeNumber parses a numeric string", 3, DocuSignPowerBI.SafeNumber("3")),
        Fact("SafeNumber defaults a null value to null", null, DocuSignPowerBI.SafeNumber(null)),
        Fact("SafeNumber defaults a non-numeric string to null rather than erroring", null, DocuSignPowerBI.SafeNumber("abc")),

        // ToDateTime: null-safe ISO8601 parsing used across Envelopes/Recipients.
        Fact("ToDateTime parses a Zulu ISO8601 timestamp", #datetime(2024, 3, 4, 5, 6, 7), DocuSignPowerBI.ToDateTime("2024-03-04T05:06:07.0000000Z")),
        Fact("ToDateTime returns null for a null input", null, DocuSignPowerBI.ToDateTime(null)),
        Fact("ToDateTime returns null for an empty string rather than erroring", null, DocuSignPowerBI.ToDateTime("")),
        Fact("ToDateTime returns null for unparseable text rather than erroring", null, DocuSignPowerBI.ToDateTime("not-a-date")),

        // StatusEquals: case-insensitive, null-safe status comparison used to derive Envelope Status flags.
        Fact("StatusEquals is case-insensitive", true, DocuSignPowerBI.StatusEquals("Completed", "completed")),
        Fact("StatusEquals returns false (not an error) for a null status", false, DocuSignPowerBI.StatusEquals(null, "completed")),
        Fact("StatusEquals returns false for a non-matching status", false, DocuSignPowerBI.StatusEquals("sent", "completed"))
    });
