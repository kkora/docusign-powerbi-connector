[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.Pagination;

nav = DocuSignPowerBI.ContentsWithDates("Demo", "2024-02-01");
envelopes = Table.SelectRows(nav, each [Name] = "Envelopes"){0}[Data];
ids = List.Sort(Table.Column(envelopes, "EnvelopeId"));

shared DocuSignPowerBI.Test.Integration.Pagination = PQTest(
    [Owner = "automation", Traits = [Category = "Integration"]],
    {
        // API-04: multi-page pagination via resultSetSize/totalSetSize/endPosition.
        Fact("API-04 multi-page pagination combines all 3 envelopes across 2 pages", 3, Table.RowCount(envelopes)),
        Fact("API-04 pagination preserves every envelope id across the page boundary", {"env-mp-1", "env-mp-2", "env-mp-3"}, ids)
    });
