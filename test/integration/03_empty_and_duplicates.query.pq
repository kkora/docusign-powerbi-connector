[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.EmptyAndDuplicates;

navEmpty = DocuSignPowerBI.Contents("Demo", "2024-03-01");
envelopesEmpty = Table.SelectRows(navEmpty, each [Name] = "Envelopes"){0}[Data];
recipientsEmpty = Table.SelectRows(navEmpty, each [Name] = "Recipients"){0}[Data];
statusEmpty = Table.SelectRows(navEmpty, each [Name] = "Envelope Status"){0}[Data];

navDup = DocuSignPowerBI.Contents("Demo", "2024-04-01");
envelopesDup = Table.SelectRows(navDup, each [Name] = "Envelopes"){0}[Data];

shared DocuSignPowerBI.Test.Integration.EmptyAndDuplicates = PQTest(
    [Owner = "automation", Traits = [Category = "Integration"]],
    {
        // API-05 / DATA-09: an empty envelope list yields zero rows across all three tables, not an error.
        Fact("API-05/DATA-09 an empty envelope list yields zero Envelopes rows", 0, Table.RowCount(envelopesEmpty)),
        Fact("DATA-09 an empty envelope list yields zero Recipients rows", 0, Table.RowCount(recipientsEmpty)),
        Fact("DATA-09 an empty envelope list yields zero Envelope Status rows", 0, Table.RowCount(statusEmpty)),

        // DATA-10: a duplicated envelope id returned by the API collapses to a single row end-to-end.
        Fact("DATA-10 a duplicated envelope id in the API response collapses to a single row", 1, Table.RowCount(envelopesDup))
    });
