[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.NewTables;

nav = DocuSignPowerBI.Contents("Demo", "2024-10-01");
customFields = Table.SelectRows(nav, each [Name] = "Envelope Custom Fields"){0}[Data];
auditEvents = Table.SelectRows(nav, each [Name] = "Envelope Audit Events"){0}[Data];
templates = Table.SelectRows(nav, each [Name] = "Templates"){0}[Data];
documents = Table.SelectRows(nav, each [Name] = "Envelope Documents"){0}[Data];

deptField = Table.SelectRows(customFields, each [FieldName] = "Department"){0};
regionField = Table.SelectRows(customFields, each [FieldName] = "Region"){0};
sentEvent = Table.SelectRows(auditEvents, each [Action] = "Sent"){0};
template1 = templates{0};
doc1 = Table.SelectRows(documents, each [DocumentId] = "1"){0};

shared DocuSignPowerBI.Test.Integration.NewTables = PQTest(
    [Owner = "automation", Traits = [Category = "Integration-NewTables"]],
    {
        // F01: Envelope Custom Fields, fetched live and flattened end-to-end.
        Fact("F01 a text custom field is retrieved from the live custom_fields endpoint", "Sales", deptField[FieldValue]),
        Fact("F01 a list custom field is retrieved from the live custom_fields endpoint", "list", regionField[FieldType]),
        Fact("F01 both custom fields are associated with the right envelope and account", {"env-new-1", "ACCT-1"}, {deptField[EnvelopeId], deptField[AccountId]}),

        // F03: Envelope Audit Events, fetched live, ordering and alias-based field lookup.
        Fact("F03 audit events are fetched for the envelope (2 events)", 2, Table.RowCount(auditEvents)),
        Fact("F03 the Sent event's UserName/UserEmail/IPAddress resolve via alias lookup", {"Jane Sender", "jane@example.com", "10.0.0.5"}, {sentEvent[UserName], sentEvent[UserEmail], sentEvent[IPAddress]}),

        // F06: Templates, independent of envelope date range, fetched once per account.
        Fact("F06 the account's template list is retrieved", 1, Table.RowCount(templates)),
        Fact("F06 template metadata maps correctly (owner, shared, created)", {"Standard NDA", "Account Owner", true}, {template1[TemplateName], template1[OwnerName], template1[Shared]}),

        // F07: Envelope Documents - metadata only (names/types/page counts), never binary content.
        Fact("F07 both documents on the envelope are retrieved", 2, Table.RowCount(documents)),
        Fact("F07 Pages is a derived count, matching the 2-page document", 2, doc1[Pages]),
        Fact("F07 DocumentType and DocumentName map correctly", {"Agreement.pdf", "content"}, {doc1[DocumentName], doc1[DocumentType]})
    });
