[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.Errors;

// Navigator Data columns are lazily evaluated, so each case forces evaluation (RowCount on the
// Envelopes table) inside the try - otherwise the try would see a "successful" Navigator shell
// without ever issuing the underlying HTTP request.
ForceEnvelopes = (fromDate as text) as number =>
    Table.RowCount(Table.SelectRows(DocuSignPowerBI.Contents("Demo", fromDate), each [Name] = "Envelopes"){0}[Data]);

invalidJsonResult = try ForceEnvelopes("2024-05-01");
forbiddenResult = try ForceEnvelopes("2024-06-01");
tooManyRequestsResult = try ForceEnvelopes("2024-07-01");
serverErrorResult = try ForceEnvelopes("2024-08-01");

shared DocuSignPowerBI.Test.Integration.Errors = PQTest(
    [Owner = "automation", Traits = [Category = "Integration-Errors"]],
    {
        // API-10: invalid JSON from the envelopes endpoint surfaces a clear error instead of crashing.
        Fact("API-10 a non-JSON 200 response surfaces an error", true, invalidJsonResult[HasError]),
        Fact("API-10 the invalid-JSON error reason is DocuSign.InvalidResponse", "DocuSign.InvalidResponse", invalidJsonResult[Error][Reason]),

        // API-07: HTTP 403 is surfaced immediately with a clear, non-retried error.
        Fact("API-07 HTTP 403 surfaces an error", true, forbiddenResult[HasError]),
        Fact("API-07 the 403 error reason is DocuSign.Forbidden", "DocuSign.Forbidden", forbiddenResult[Error][Reason]),

        // API-08: HTTP 429 is retried with bounded backoff, then fails cleanly once attempts are exhausted.
        Fact("API-08 a persistent HTTP 429 is retried then fails with a bounded, clear error", true, tooManyRequestsResult[HasError]),
        Fact("API-08 the exhausted-429 error reason is DocuSign.HttpError", "DocuSign.HttpError", tooManyRequestsResult[Error][Reason]),
        Fact("API-08 the exhausted-429 error message reports HTTP 429", true, Text.Contains(tooManyRequestsResult[Error][Message], "429")),

        // API-09: transient HTTP 5xx is retried with bounded backoff, then fails cleanly.
        Fact("API-09 a persistent HTTP 500 is retried then fails with a bounded, clear error", true, serverErrorResult[HasError]),
        Fact("API-09 the exhausted-500 error message reports HTTP 500", true, Text.Contains(serverErrorResult[Error][Message], "500"))
    });
