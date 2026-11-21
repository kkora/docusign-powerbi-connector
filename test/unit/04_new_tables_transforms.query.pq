[Version = "1.0.0"]
section DocuSignPowerBI.Test.NewTables;

// ===== F01: Envelope Custom Fields =====

customFieldsRawBoth = [
    textCustomFields = {
        [ fieldId = "1", name = "Department", value = "Finance", show = "true", required = "false" ],
        [ fieldId = "2", name = "ContractValue", value = "50000", show = "false", required = "true" ]
    },
    listCustomFields = {
        [ fieldId = "3", name = "Region", value = "EMEA", show = "true", required = "true", listItems = {"EMEA", "AMER", "APAC"} ]
    }
];
customFieldsFlattened = DocuSignPowerBI.FlattenCustomFields(customFieldsRawBoth, "ACCT-1", "env-1");
customFieldsEmpty = DocuSignPowerBI.FlattenCustomFields([], "ACCT-1", "env-empty");
deptField = List.First(List.Select(customFieldsFlattened, each [FieldName] = "Department"));
regionField = List.First(List.Select(customFieldsFlattened, each [FieldName] = "Region"));

// ===== F03: Envelope Audit Events =====

auditEventsRaw = [
    auditEvents = {
        [ eventFields = { [name = "logTime", value = "2024-01-01T08:00:00.0000000Z"], [name = "Action", value = "Sent"], [name = "UserName", value = "Jane Sender"], [name = "Email", value = "jane@example.com"], [name = "IP Address", value = "10.0.0.1"] } ],
        [ eventFields = { [name = "logTime", value = "2024-01-01T09:00:00.0000000Z"], [name = "Action", value = "Viewed"], [name = "UserName", value = "John Signer"] } ]
    }
];
auditEventsFlattened = DocuSignPowerBI.FlattenAuditEvents(auditEventsRaw, "ACCT-1", "env-1");
auditEventsEmpty = DocuSignPowerBI.FlattenAuditEvents([], "ACCT-1", "env-empty");
firstAuditEvent = auditEventsFlattened{0};
secondAuditEvent = auditEventsFlattened{1};

// ===== F06: Templates =====

templatesRaw = {
    [ templateId = "t1", name = "NDA Template", description = "Standard NDA", created = "2024-01-01T00:00:00.0000000Z", lastModifiedDateTime = "2024-02-01T00:00:00.0000000Z", owner = [userName = "Jane Owner"], #"shared" = true ],
    [ templateId = "t2", name = "Offer Letter" ]
};
templatesTable = DocuSignPowerBI.BuildTemplatesTable(templatesRaw, "ACCT-1");
template1 = Table.SelectRows(templatesTable, each [TemplateId] = "t1"){0};
template2 = Table.SelectRows(templatesTable, each [TemplateId] = "t2"){0};
templatesEmptyTable = DocuSignPowerBI.BuildTemplatesTable({}, "ACCT-1");

// ===== F07: Envelope Documents =====

documentsRawMultiple = [
    envelopeDocuments = {
        [ documentId = "1", name = "Contract.pdf", #"type" = "content", order = "1", pages = { [pageId = "1"], [pageId = "2"], [pageId = "3"] } ],
        [ documentId = "2", name = "Summary.pdf", #"type" = "summary", order = "2", pages = { [pageId = "1"] } ]
    }
];
documentsFlattened = DocuSignPowerBI.FlattenDocuments(documentsRawMultiple, "ACCT-1", "env-1");
documentsEmpty = DocuSignPowerBI.FlattenDocuments([], "ACCT-1", "env-empty");
contractDoc = List.First(List.Select(documentsFlattened, each [DocumentId] = "1"));

// ===== F05: Accounts =====

accountsRaw = {
    [ account_id = "ACCT-1", account_name = "Primary Account", is_default = true ],
    [ account_id = "ACCT-2", account_name = "Secondary Account", is_default = false ]
};
accountsTable = DocuSignPowerBI.BuildAccountsTable(accountsRaw, "Demo");
acct1 = Table.SelectRows(accountsTable, each [AccountId] = "ACCT-1"){0};
acct2 = Table.SelectRows(accountsTable, each [AccountId] = "ACCT-2"){0};

// ===== F02: ToDate resolution =====

toDateValid = DocuSignPowerBI.ResolveToDate("2024-06-01");
toDateBlank = DocuSignPowerBI.ResolveToDate(null);
toDateInvalid = try DocuSignPowerBI.ResolveToDate("not-a-date");

shared DocuSignPowerBI.Test.NewTables = PQTest(
    [Owner = "automation", Traits = [Category = "Unit-NewTables"]],
    {
        // F01 Custom Fields
        Fact("F01 text custom field maps FieldType = text", "text", deptField[FieldType]),
        Fact("F01 text custom field value/show/required map correctly", {"Finance", true, false}, {deptField[FieldValue], deptField[Show], deptField[Required]}),
        Fact("F01 list custom field maps FieldType = list", "list", regionField[FieldType]),
        Fact("F01 schema has exactly the required columns", {"AccountId", "EnvelopeId", "FieldName", "FieldValue", "FieldType", "Show", "Required"}, Record.FieldNames(deptField)),
        Fact("F01 an envelope with no custom fields at all flattens to zero rows", 0, List.Count(customFieldsEmpty)),
        Fact("F01 both text and list buckets are combined", 3, List.Count(customFieldsFlattened)),

        // F03 Audit Events
        Fact("F03 event ordering is preserved (Sent before Viewed)", {"Sent", "Viewed"}, {firstAuditEvent[Action], secondAuditEvent[Action]}),
        Fact("F03 EventDateTime parses as a timezone-aware value", #datetimezone(2024, 1, 1, 8, 0, 0, 0, 0), firstAuditEvent[EventDateTime]),
        Fact("F03 UserName/UserEmail/IPAddress map via alias lookup", {"Jane Sender", "jane@example.com", "10.0.0.1"}, {firstAuditEvent[UserName], firstAuditEvent[UserEmail], firstAuditEvent[IPAddress]}),
        Fact("F03 missing optional fields (no email/IP on 2nd event) default to null, not an error", {null, null}, {secondAuditEvent[UserEmail], secondAuditEvent[IPAddress]}),
        Fact("F03 an envelope with no audit events flattens to zero rows", 0, List.Count(auditEventsEmpty)),
        Fact("F03 schema has exactly the required columns", {"AccountId", "EnvelopeId", "EventDateTime", "EventType", "EventDescription", "UserName", "UserEmail", "IPAddress", "Action", "Result"}, Record.FieldNames(firstAuditEvent)),

        // F06 Templates
        Fact("F06 schema has exactly the required columns", {"AccountId", "TemplateId", "TemplateName", "Description", "CreatedDateTime", "LastModifiedDateTime", "OwnerName", "Shared", "Status"}, Table.ColumnNames(templatesTable)),
        Fact("F06 CreatedDateTime maps from the API's 'created' field (not 'createdDateTime')", #datetime(2024, 1, 1, 0, 0, 0), template1[CreatedDateTime]),
        Fact("F06 OwnerName maps from the nested owner.userName", "Jane Owner", template1[OwnerName]),
        Fact("F06 Shared maps to a logical", true, template1[Shared]),
        Fact("F06 a template missing optional metadata defaults those columns to null", {null, null, null, null}, {template2[Description], template2[CreatedDateTime], template2[OwnerName], template2[Shared]}),
        Fact("F06 an empty template list yields zero rows with the full schema intact", 0, Table.RowCount(templatesEmptyTable)),

        // F07 Envelope Documents
        Fact("F07 schema has exactly the required columns", {"AccountId", "EnvelopeId", "DocumentId", "DocumentName", "DocumentType", "Order", "Pages"}, Record.FieldNames(contractDoc)),
        Fact("F07 Pages is derived as a count of the pages array, not raw page objects", 3, contractDoc[Pages]),
        Fact("F07 multiple documents on one envelope all appear", 2, List.Count(documentsFlattened)),
        Fact("F07 an envelope with no documents metadata flattens to zero rows", 0, List.Count(documentsEmpty)),

        // F05 Accounts
        Fact("F05 schema has exactly the required columns", {"AccountId", "AccountName", "IsDefault", "Environment"}, Table.ColumnNames(accountsTable)),
        Fact("F05 the default account is flagged IsDefault = true", true, acct1[IsDefault]),
        Fact("F05 a non-default account is flagged IsDefault = false", false, acct2[IsDefault]),
        Fact("F05 every account row carries the requested environment", {"Demo", "Demo"}, {acct1[Environment], acct2[Environment]}),

        // F02 ToDate
        Fact("F02 a valid toDate passes through unchanged", "2024-06-01", toDateValid),
        Fact("F02 a null toDate resolves to null (no upper bound)", null, toDateBlank),
        Fact("F02 an invalid toDate is rejected", true, toDateInvalid[HasError])
    });
