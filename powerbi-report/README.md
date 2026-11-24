# DocuSign Report (Power BI Project)

A Power BI Project (`.pbip`) built on top of the `DocuSignPowerBI` connector, covering all 8 Navigator tables: Envelopes, Recipients, Envelope Status, Envelope Custom Fields, Envelope Audit Events, Templates, Envelope Documents, Accounts.

## Verification status

**Verified working in Power BI Desktop 2.159 (October 2026) on 2026-11-24**: the `.pbip` opens, the semantic model loads all 8 tables, and the report renders all 3 pages / 17 visuals with data matching the live Demo account (2 envelopes, 1 template, 2 accounts — same counts as the connector's live verification in [TEST-RESULTS.md](../TEST-RESULTS.md)).

The originally hand-authored files needed three fixes before Desktop would load them — all defects a static JSON/TMDL syntax check can't catch, discovered by actually opening the project:

1. **`DocuSignReport.Report/definition/version.json` was missing.** It is a required PBIR file, and its `version` must be `"2.0.0"` — declaring a higher version (e.g. `2.1.0`) makes Desktop open the project but silently load **zero pages** (no error, no tabs, blank canvas).
2. **`report.json` was missing the required `themeCollection` property** (an empty `{}` satisfies the schema). Without it, Desktop discards the entire PBIR `definition/` folder on open and replaces it with a blank legacy `report.json` — recoverable only from source control.
3. **`database.tmdl` had a de-indented property** (`compatibilityLevel` at column 0 instead of tabbed under the `database` object), which TMDL's parser rejects outright.

The visual-by-visual guide below is kept as reference documentation of the report's content; it is no longer needed as a fallback.

## Prerequisites

- Power BI Desktop from 2024 or later (`.pbip`/PBIR support is GA — recent builds have no preview toggle for it; only enable the Preview-features option if your build still lists one).
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

## Page/visual reference

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
