# DocuSign Report (Power BI Project)

A Power BI Project (`.pbip`) built on top of the `DocuSignPowerBI` connector, covering all 8 Navigator tables: Envelopes, Recipients, Envelope Status, Envelope Custom Fields, Envelope Audit Events, Templates, Envelope Documents, Accounts.

This folder also contains a second, independent project — **`AgreementsReport.pbip`** — covering the connector's DocuSign Navigator agreement tables; see [AgreementsReport](#agreementsreport-power-bi-project) below.

## Verification status

**Verified working in Power BI Desktop 2.159 (October 2026) on 2026-11-24**: the `.pbip` opens, the semantic model loads all 8 tables, and the report renders all 3 pages / 17 visuals with data matching the live Demo account (2 envelopes, 1 template, 2 accounts — same counts as the connector's live verification in [TEST-RESULTS.md](../TEST-RESULTS.md)).

The originally hand-authored files needed three fixes before Desktop would load them — all defects a static JSON/TMDL syntax check can't catch, discovered by actually opening the project:

1. **`DocuSignReport.Report/definition/version.json` was missing.** It is a required PBIR file, and its `version` must be `"2.0.0"` — declaring a higher version (e.g. `2.1.0`) makes Desktop open the project but silently load **zero pages** (no error, no tabs, blank canvas).
2. **`report.json` was missing the required `themeCollection` property** (an empty `{}` satisfies the schema). Without it, Desktop discards the entire PBIR `definition/` folder on open and replaces it with a blank legacy `report.json` — recoverable only from source control.
3. **`database.tmdl` had a de-indented property** (`compatibilityLevel` at column 0 instead of tabbed under the `database` object), which TMDL's parser rejects outright.

The visual-by-visual guide below is kept as reference documentation of the report's content; it is no longer needed as a fallback.

## Theming & screenshots

Two custom themes are registered under `DocuSignReport.Report/StaticResources/RegisteredResources/`; the active one is set in `report.json` → `themeCollection.customTheme`:

- **`Eda.json`** (active) — NJEDA-branded: teal `#00608E` (brand `#00597c`, minimally saturation-adjusted to pass color validation) and apple green `#84BD00` lead the CVD-validated 8-color palette; navy `#112337` ink; green card borders on white surfaces over a faint green-white page plane.
- **`DocuSignModern.json`** — neutral blue-led variant of the same design (swap by changing the `customTheme` name in `report.json`).

All measures are wrapped in `COALESCE(..., 0)` so slicer selections that filter a table to zero rows show a readable `0` instead of `(Blank)`.

Rendered in Power BI Desktop (2026-11-24, live Demo-account data):

| Page | Screenshot |
|---|---|
| Overview | [screenshots/overview.png](screenshots/overview.png) |
| Recipients & Audit | [screenshots/recipients-audit.png](screenshots/recipients-audit.png) |
| Templates, Custom Fields & Accounts | [screenshots/templates-custom-fields-accounts.png](screenshots/templates-custom-fields-accounts.png) |

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

## AgreementsReport (Power BI Project)

A second, independent `.pbip` (`AgreementsReport.pbip` → `AgreementsReport.Report` + `AgreementsReport.SemanticModel`) over the connector's three DocuSign **Navigator** agreement tables added in v1.3.0. Its design is ported from DocuSign's official "PowerBI Agreements Report" cloud template (analyzed in [AGREEMENTS-REPORT-PLAN.md](../AGREEMENTS-REPORT-PLAN.md)), rebuilt in source-controlled PBIR/TMDL rather than rebinding the legacy-format `.pbit`.

### Verification status

**Authored 2026-11-27, not yet opened in Power BI Desktop.** All 24 JSON files parse, every visual field reference was machine-checked against the TMDL model (99 fields), and the three PBIR pitfalls documented above (version `2.0.0`, `themeCollection`, TMDL tab indentation) were applied from the start. Desktop open + live refresh is the remaining verification step.

### Semantic model

Parameters `Environment` (`Demo`/`Production`) and `AccountId` — same pattern as DocuSignReport; the Navigator tables require the account to have DocuSign Navigator provisioned (on this project's Demo tenant that is the `njeda` account only).

| Table | Source | Notes |
|---|---|---|
| Agreements | connector `Agreements` | all 67 connector columns, 14 measures |
| Parties | connector `Parties` | `Total Parties` measure |
| CustomField | connector `CustomField` | empty unless Navigator custom fields are defined |
| Date | M-generated calendar (2010 → today+10y) | **disconnected** — used via `MIN`/`MAX` filter context in measures, matching the official template's pattern |
| Agreement Status Breakdown | static 3-row M table | drives the status donut via `Dynamic Status Count` |

Relationships: `Parties[AgreementId] → Agreements[Id]`, `CustomField[AgreementId] → Agreements[Id]` (many-to-one, single direction).

Measures (ported from the official template, all `COALESCE`-wrapped; `Fiscal_*`, `IsTrashed`, and Obligations/Tickets measures were not ported — their columns/tables have no public-API source): `Agreements`, `Active Agreements`, `Agreements Expiring Next 90 Days`, `Agreements Due for Renewal Next 90 Days`, `Termination Notice Deadlines`, `All Expired Agreements`, `All Pending Renewal`, `All Active Agreements Without Renewals`, `Renewing Soon Count`, `Expiring Soon (Non-Renewing) Count`, `Dynamic Status Count`, `ActiveAgreementsCount`, `AutoRenewalAgreementsCount`, `Total Contract Value`, `Total Parties`.

### Report pages (Eda theme, same as DocuSignReport)

| Page | Visuals |
|---|---|
| Agreements Overview | 5 KPI cards (total / active / expiring 90d / renewal due 90d / total value), status-breakdown donut, Agreements by Type, Agreements by Party (via the Parties relationship), agreement detail table |
| Renewals & Deadlines | RenewalType slicer, 4 cards (renewing soon / expiring non-renewing / pending renewal / expired), Expirations by Year, Agreements by Governing Law, renewal-pipeline table (notice dates, termination deadlines) |

### Opening it

Same steps as DocuSignReport: **File → Open report → Browse** → `AgreementsReport.pbip`, sign in to DocuSign (the credential must have been granted the Navigator scope — clear and re-enter a credential saved before connector v1.3.0), refresh. Leave `AccountId` blank to use the default (`njeda`) account.
