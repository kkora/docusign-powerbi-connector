[Version = "1.0.0"]
section DocuSignPowerBI.Test.Transforms;

rawEnvelopes = {
    [ envelopeId = "e1", emailSubject = "Subj 1", status = "completed",
      createdDateTime = "2024-01-01T08:00:00.0000000Z", sentDateTime = "2024-01-01T08:00:00.0000000Z",
      completedDateTime = "2024-01-01T11:30:00.0000000Z", lastModifiedDateTime = "2024-01-01T11:30:00.0000000Z" ],
    // DATA-05: missing emailSubject / voidedDateTime-only fields.
    [ envelopeId = "e2", status = "voided", voidedDateTime = "2024-01-02T09:00:00.0000000Z" ],
    // DATA-10: duplicate of e2 as DocuSign might (incorrectly) return across overlapping pages.
    [ envelopeId = "e2", status = "voided", voidedDateTime = "2024-01-02T09:00:00.0000000Z" ],
    // DATA-08: sent but never completed -> CompletedDateTime stays null.
    [ envelopeId = "e3", emailSubject = "Subj 3", status = "sent", sentDateTime = "2024-01-03T08:00:00.0000000Z" ]
};

envelopesTable = DocuSignPowerBI.BuildEnvelopesTable(rawEnvelopes, "ACCT-X");
envelopesDistinct = Table.Distinct(envelopesTable, {"EnvelopeId"});
emptyEnvelopesTable = DocuSignPowerBI.BuildEnvelopesTable({}, "ACCT-X");

e1 = Table.SelectRows(envelopesDistinct, each [EnvelopeId] = "e1"){0};
e2 = Table.SelectRows(envelopesDistinct, each [EnvelopeId] = "e2"){0};

recipientsRawWithTwoBuckets = [
    signers = { [ recipientId = "r1", name = "Sam Signer", email = "sam@example.com", routingOrder = "1", status = "completed", signedDateTime = "2024-01-01T11:00:00.0000000Z" ] },
    carbonCopies = { [ recipientId = "r2", name = "Cara CC", email = "cara@example.com", routingOrder = "2", status = "sent" ] }
];
flattenedRecipients = DocuSignPowerBI.FlattenRecipients(recipientsRawWithTwoBuckets, "e1");
signerRow = List.First(List.Select(flattenedRecipients, each [RecipientType] = "signers"));
ccRow = List.First(List.Select(flattenedRecipients, each [RecipientType] = "carbonCopies"));

flattenedEmptyRecipients = DocuSignPowerBI.FlattenRecipients([], "e-empty");

statusTable = DocuSignPowerBI.BuildStatusTable(envelopesDistinct);
e1Status = Table.SelectRows(statusTable, each [EnvelopeId] = "e1"){0};
e2Status = Table.SelectRows(statusTable, each [EnvelopeId] = "e2"){0};
e3Status = Table.SelectRows(statusTable, each [EnvelopeId] = "e3"){0};

shared DocuSignPowerBI.Test.Transforms = PQTest(
    [Owner = "automation", Traits = [Category = "Unit-Data"]],
    {
        // DATA-01 / DATA-02: Envelopes schema and types.
        Fact("DATA-01 Envelopes table has exactly the required columns", {"AccountId", "EnvelopeId", "EmailSubject", "Status", "CreatedDateTime", "SentDateTime", "CompletedDateTime", "VoidedDateTime", "LastModifiedDateTime"}, Table.ColumnNames(envelopesTable)),
        Fact("DATA-02 CreatedDateTime column is typed datetime", "datetime", Table.Schema(envelopesTable){[Name = "CreatedDateTime"]}[Kind]),
        Fact("DATA-02 AccountId is propagated from account discovery onto every row", "ACCT-X", e1[AccountId]),
        Fact("DATA-02 ISO8601 CompletedDateTime parses to a datetime value", #datetime(2024, 1, 1, 11, 30, 0), e1[CompletedDateTime]),

        // DATA-05: missing optional fields default to null rather than erroring.
        Fact("DATA-05 missing EmailSubject defaults to null", null, e2[EmailSubject]),
        Fact("DATA-05 missing SentDateTime defaults to null", null, e2[SentDateTime]),
        Fact("DATA-05 VoidedDateTime still parses when present", #datetime(2024, 1, 2, 9, 0, 0), e2[VoidedDateTime]),

        // DATA-09: an empty envelope list still yields a typed, zero-row table (not an error).
        Fact("DATA-09 empty envelope list yields zero rows", 0, Table.RowCount(emptyEnvelopesTable)),
        Fact("DATA-09 empty envelope list keeps the full typed schema", Table.ColumnNames(envelopesTable), Table.ColumnNames(emptyEnvelopesTable)),

        // DATA-10: duplicate envelopes collapse to one row once de-duplicated by EnvelopeId.
        Fact("DATA-10 duplicate EnvelopeId rows collapse to one after de-duplication", 1, Table.RowCount(Table.SelectRows(envelopesDistinct, each [EnvelopeId] = "e2"))),
        Fact("DATA-10 total distinct envelope count is 3 (e1, e2, e3)", 3, Table.RowCount(envelopesDistinct)),

        // DATA-03 / DATA-04: Recipients schema and types, across multiple recipient buckets.
        Fact("DATA-03 Recipients rows have exactly the required columns (extended by F04)", {"AccountId", "EnvelopeId", "RecipientId", "RecipientName", "RecipientEmail", "RecipientType", "RecipientRole", "RoutingOrder", "RecipientStatus", "SentDateTime", "SignedDateTime", "DeliveredDateTime", "DeclinedDateTime", "DeclineReason", "AuthenticationMethod", "CompletionHours"}, Record.FieldNames(signerRow)),
        Fact("DATA-04 a signer bucket recipient is flattened with RecipientType = signers", "signers", signerRow[RecipientType]),
        Fact("DATA-04 a carbonCopies bucket recipient is flattened with RecipientType = carbonCopies", "carbonCopies", ccRow[RecipientType]),
        Fact("DATA-04 RoutingOrder is converted from the API's string number to a numeric type", 1, signerRow[RoutingOrder]),
        Fact("DATA-04 SignedDateTime parses for a completed signer", #datetime(2024, 1, 1, 11, 0, 0), signerRow[SignedDateTime]),
        Fact("DATA-04 an unsigned recipient (carbonCopies, no signedDateTime) has a null SignedDateTime", null, ccRow[SignedDateTime]),
        Fact("DATA-05 a recipients response with no buckets at all flattens to zero rows (not an error)", 0, List.Count(flattenedEmptyRecipients)),

        // DATA-06: status mapping.
        Fact("DATA-06 a completed envelope maps IsCompleted = true", true, e1Status[IsCompleted]),
        Fact("DATA-06 a completed envelope maps IsPending/IsDeclined/IsVoided = false", {false, false, false}, {e1Status[IsPending], e1Status[IsDeclined], e1Status[IsVoided]}),
        Fact("DATA-06 a voided envelope maps IsVoided = true and IsCompleted/IsPending = false", {true, false, false}, {e2Status[IsVoided], e2Status[IsCompleted], e2Status[IsPending]}),
        Fact("DATA-06 a sent (in-flight) envelope maps IsPending = true", true, e3Status[IsPending]),

        // DATA-07 / DATA-08: CompletionHours is computed only from valid timestamp pairs.
        Fact("DATA-07 CompletionHours is computed as (CompletedDateTime - SentDateTime) in hours", 3.5, e1Status[CompletionHours]),
        Fact("DATA-08 a null CompletedDateTime yields a null CompletionHours, not an error", null, e3Status[CompletionHours]),
        Fact("DATA-08 a voided envelope with no CompletedDateTime yields a null CompletionHours", null, e2Status[CompletionHours])
    });
