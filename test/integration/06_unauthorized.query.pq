// API-06 / AUTH-09: this query is EXPECTED to fail. HTTP 401 on the envelopes endpoint triggers
// the Power Query engine's built-in Refresh-and-retry; the retried call is also mocked to return
// 401 (the HTTP mock server is stateless), so the credential cannot be repaired. The engine then
// aborts the evaluation with "The credentials provided for the DocuSignPowerBI source are invalid" -
// the correct behavior for an unauthorized/un-refreshable credential. See TEST-RESULTS.md for the
// captured output; PQTest's credential invalidation is a host-level abort, not a catchable M error,
// so it cannot be wrapped in a PQUnit Fact like the other error-handling cases.
Table.RowCount(Table.SelectRows(DocuSignPowerBI.Contents("Demo", "2024-09-01"), each [Name] = "Envelopes"){0}[Data])
