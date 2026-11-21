[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.Happy;

nav = DocuSignPowerBI.Contents("Demo", "2024-01-01");
envelopes = Table.SelectRows(nav, each [Name] = "Envelopes"){0}[Data];
recipients = Table.SelectRows(nav, each [Name] = "Recipients"){0}[Data];
statuses = Table.SelectRows(nav, each [Name] = "Envelope Status"){0}[Data];

e1 = Table.SelectRows(envelopes, each [EnvelopeId] = "env-happy-1"){0};
s1 = Table.SelectRows(statuses, each [EnvelopeId] = "env-happy-1"){0};
r1 = Table.SelectRows(recipients, each [EnvelopeId] = "env-happy-1" and [RecipientType] = "signers"){0};
r2 = Table.SelectRows(recipients, each [EnvelopeId] = "env-happy-1" and [RecipientType] = "carbonCopies"){0};

shared DocuSignPowerBI.Test.Integration.Happy = PQTest(
    [Owner = "automation", Traits = [Category = "Integration"]],
    {
        // PBI-04: the Navigator exposes exactly the eight required tables.
        Fact("PBI-04 Navigator exposes exactly eight tables", 8, Table.RowCount(nav)),
        Fact("PBI-04 Navigator table names are exactly the eight required tables", List.Sort({"Envelopes", "Recipients", "Envelope Status", "Envelope Custom Fields", "Envelope Audit Events", "Templates", "Envelope Documents", "Accounts"}), List.Sort(Table.Column(nav, "Name"))),

        // API-01 / API-02: account discovery (/oauth/userinfo) drove the account-specific API base URI and account id used for every downstream call.
        Fact("API-01/02 AccountId from account discovery is stamped onto every envelope row", "ACCT-1", e1[AccountId]),

        // API-03: single-page envelope retrieval.
        Fact("API-03 both envelopes in the single mocked page are present", 2, Table.RowCount(envelopes)),
        Fact("API-03 envelope fields map correctly from the DocuSign JSON shape", "Please sign: Happy Path A", e1[EmailSubject]),

        // DATA-06 / DATA-07: status mapping and completion-hours calculation on a real completed envelope.
        Fact("DATA-06 a completed envelope is flagged IsCompleted", true, s1[IsCompleted]),
        Fact("DATA-07 CompletionHours matches (18:00 - 08:00) = 10 hours", 10.0, s1[CompletionHours]),

        // DATA-04: recipients fan out across multiple buckets for the same envelope.
        Fact("DATA-04 a signer recipient is present for env-happy-1", "John Signer", r1[RecipientName]),
        Fact("DATA-04 a carbonCopies recipient is present for the same envelope", "Jane CC", r2[RecipientName]),
        Fact("API-03 recipients were fetched for both envelopes (2 for env-1, 1 for env-2 = 3 rows)", 3, Table.RowCount(recipients))
    });
