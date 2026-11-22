# DocuSign Report (Power BI Project)

A Power BI Project (`.pbip`) built on top of the `DocuSignPowerBI` connector, covering all 8 Navigator tables: Envelopes, Recipients, Envelope Status, Envelope Custom Fields, Envelope Audit Events, Templates, Envelope Documents, Accounts.

## Confidence / honesty note

The **semantic model** (`DocuSignReport.SemanticModel/` — tables, relationships, M partitions, 21 DAX measures, all hand-authored as TMDL text) is high-confidence: TMDL is a stable, well-documented format and every table/column/measure here maps directly to the connector's actual, tested schema.

The **report** (`DocuSignReport.Report/` — 3 pages, 17 visuals) was hand-authored against the current Power BI enhanced report format (PBIR) from documentation and prior examples, but **could not be opened or rendered to verify it** (no Power BI Desktop available in this environment). All JSON files are syntactically valid (parsed successfully), but that doesn't guarantee they satisfy Power BI Desktop's full schema validation. **If the report fails to open or Desktop offers to "repair" it:** the semantic model will still load correctly on its own — open the `.pbip`, let Desktop rebuild/discard the broken report shell if prompted, then recreate the 3 pages using the visual-by-visual guide below (10-15 minutes).

## Prerequisites

- Enable **Power BI Project (.pbip) save option** under File → Options and settings → Options → Preview features (if not already on).
- The `DocuSignPowerBI.mez` connector must be installed in your Custom Connectors folder (see the main [README](../README.md)) and trusted (unsigned extension loading enabled).

## Opening it

1. In Power BI Desktop: **File → Open report → Browse** → select `DocuSignReport.pbip`.
2. Desktop loads the semantic model and prompts you to sign in to DocuSign (OAuth) the first time — same flow as connecting manually.
3. Click **Refresh** to pull live data into all 8 tables.

## Semantic model structure

**Relationships** (Envelopes as the hub, Accounts as a shared dimension):

| From | To |
|---|---|
| Recipients[EnvelopeId] | Envelopes[EnvelopeId] |
| Envelope Status[EnvelopeId] | Envelopes[EnvelopeId] |
| Envelope Custom Fields[EnvelopeId] | Envelopes[EnvelopeId] |
| Envelope Audit Events[EnvelopeId] | Envelopes[EnvelopeId] |
| Envelope Documents[EnvelopeId] | Envelopes[EnvelopeId] |
| Envelopes[AccountId] | Accounts[AccountId] |
| Templates[AccountId] | Accounts[AccountId] |

**Measures** (21 total, one DAX file per table in `definition/tables/*.tmdl`):

| Table | Measures |
|---|---|
| Envelopes | Total Envelopes, Completed Envelopes, Voided Envelopes, Declined Envelopes |
| Recipients | Total Recipients, Declined Recipients, Avg Recipient Turnaround Hours, Distinct Authentication Methods |
| Envelope Status | Avg Completion Hours, Completed %, Pending %, Voided % |
| Envelope Custom Fields | Total Custom Fields, Required Fields Not Shown |
| Envelope Audit Events | Total Audit Events, Distinct Event Actions |
| Templates | Total Templates, Shared Templates % |
| Envelope Documents | Total Documents, Avg Pages per Document |
| Accounts | Total Accounts |

## Manual build guide (fallback, if the report pages don't open)

### Page 1 — Overview
- 5 **Card** visuals: `Envelopes[Total Envelopes]`, `Envelope Status[Completed %]`, `Envelope Status[Avg Completion Hours]`, `Templates[Total Templates]`, `Accounts[Total Accounts]`.
- **Clustered column chart**: Axis = `Envelopes[Status]`, Values = `Envelopes[Total Envelopes]`.
- **Table**: `Envelopes[EnvelopeId, EmailSubject, Status, SentDateTime, CompletedDateTime]`.

### Page 2 — Recipients & Audit
- **Slicer**: `Recipients[RecipientType]`.
- 2 **Card** visuals: `Recipients[Declined Recipients]`, `Recipients[Avg Recipient Turnaround Hours]`.
- **Bar chart**: Axis = `Envelope Audit Events[Action]`, Values = `Envelope Audit Events[Total Audit Events]`.
- **Table**: `Recipients[RecipientName, RecipientType, RecipientStatus, AuthenticationMethod, CompletionHours]`.

### Page 3 — Templates, Custom Fields & Accounts
- **Slicer**: `Accounts[AccountName]`.
- 2 **Card** visuals: `Envelope Documents[Total Documents]`, `Templates[Shared Templates %]`.
- **Table**: `Templates[TemplateName, OwnerName, Shared, CreatedDateTime]`.
- **Table**: `Envelope Custom Fields[FieldName, FieldValue, FieldType, Required]`.
