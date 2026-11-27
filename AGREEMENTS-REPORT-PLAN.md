# AgreementsReport.pbip — Plan

Build a second, source-controlled Power BI report (`powerbi-report/AgreementsReport.pbip`) for
**DocuSign agreement (Navigator) data**, modeled on DocuSign's official `AgreementsDemo.pbit`
sample, powered by our own `DocuSignPowerBI` connector, and shipped through the existing
`dist\` packaging pipeline as `AgreementsReport.pbit`.

Status: **Phase 1 complete (2026-11-27)** — connector v1.3.0 ships the `Agreements`/`Parties`/`CustomField`
tables (Navigator scope, ctoken pagination, ISO-duration helper, 46 new test Facts; 184/184 total pass —
see TEST-RESULTS.md "v1.3.0"). Phase 0 results in §5. Next: Phase 2 (AgreementsReport.pbip).

---

## 1. What the sample is (analysis of `AgreementsDemo.pbit`)

Source file analyzed: `C:\Users\kkora\Downloads\AgreementsDemo.pbit` (183 KB, 2026-11-19).
It is DocuSign's official cloud-exported template — file description: *"This is a template file
of PowerBI Agreements Report which has all the standard visuals to get started and build on top
of this."* (CreatedFrom: Cloud, release 2026.03).

Key facts:

| Aspect | Finding |
| --- | --- |
| Data source | `Docusign.Contents(Environment, AccountId)` — the **Microsoft-certified Docusign connector built into Power BI Desktop**, not our custom connector |
| Parameters | `Environment` (list: `Demo`, `Prod`), `AccountId` — same signature as our `DocuSignPowerBI.Contents(Environment, AccountId)`; note our connector spells it `Production`, theirs `Prod` |
| Data domain | **Navigator / agreement-AI data** (contract metadata), not eSignature envelope data — complements, does not overlap, our existing 8 envelope tables |
| Source tables | `Agreements` (123 cols), `Parties` (22), `Obligations` (43), `CustomField` (15), `Tickets` (35) |
| DAX tables | `Date` (calendar 2010→today+10y), `FiscalDateDimension` (FY starts Feb), `Agreement Status Breakdown` (3-row UNION over measures) |
| Relationships | `Parties/Obligations/CustomField[AgreementId] → Agreements[Id]`; `CustomField/Obligations[RowNum] → Parties[RowNum]` (odd, verify need); `Agreements[AccountId] → Tickets[AccountId]` |
| Measures | 22 total — 17 on Agreements, 2 on Obligations, 3 on Tickets (full list in Appendix B) |
| Report pages | Agreements Overview (12 visuals), Advanced Analysis (4), Obligations Analysis (4), Tickets Analysis (5), Custom Charts (7) |
| Extras | `VerifiedAnswers\` (19 Copilot Q&A definitions) — cloud feature, out of scope for us |
| Format | **Legacy single-file `Report\Layout`** (not PBIR folders) — cannot be dropped into source control as-is; we rebuild in PBIR instead of rebinding the pbit |

M-query quirks worth knowing (visible in its partitions):

- Replaces sentinel `#datetime(1,1,1,5,30,0)` with `null` on several date columns (cloud-side
  export artifact — our connector should just emit real `null`s).
- Null/blank text → `"Unassigned"` on `RenewalOwner`, `PaymentTerms`,
  `AssignmentTerminationRights`, `PartyName`, `Obligations[Owner]`.
- Year-number columns use `0` as "missing" and the query nulls them out.
- Many `Agreements` columns are **precomputed flags** the certified connector ships
  (`IsActive`, `IsExpiringIn30days/90days`, `IsRenewingIn…`, `IsTakingEffectIn…`,
  `*YearNumber`, `*MonthYear`, `TerminationNoticeDueDate`, `PaymentDueDate`). The report's
  measures lean on these, so we must compute them in M ourselves.

To re-extract the sample for reference: it is a zip — `Expand-Archive` after renaming to
`.zip`, `DataModelSchema` is UTF-16, `Report\Layout` is UTF-16 JSON.

---

## 2. Decisions

1. **New sibling project, not new pages in DocuSignReport**: `powerbi-report/AgreementsReport.pbip`
   with `AgreementsReport.Report/` + `AgreementsReport.SemanticModel/` (PBIR + TMDL, same as the
   existing report). Different data domain, different audience, independent refresh cost.
2. **Rebuild, don't rebind.** The demo pbit stays a design reference only. Its legacy layout
   format and 123-column contract make direct rebinding to our connector fragile and
   un-reviewable.
3. **Our connector grows an Agreements table group** fed by the **Navigator API**
   (`GET https://api-d.docusign.com/v1/accounts/{accountId}/agreements`, prod: `api.docusign.com`).
   We implement a pragmatic **v1 column subset** (Appendix A), not 123-column parity — enough to
   drive the Overview-page measures and visuals.
4. **v1 scope: `Agreements` + `Parties` + `CustomField`.** `Obligations` is **out of v1**
   (Phase 0 probed `/obligations` on both account and agreement level: 404 — no public
   Navigator endpoint; the certified connector gets it from an internal data-out pipe).
   `Tickets` is **out of scope** (different product surface, no public API identified).
5. **Theme/UX**: reuse the Eda theme and the conventions from DocuSignReport
   (`COALESCE(..., 0)` on all measures, same PBIR pitfalls checklist).

---

## 3. Phases

### Phase 0 — Feasibility gate (~half day) ⬅ do first; everything else depends on it

| # | Task | Pass criteria |
| --- | --- | --- |
| 0.1 | Open `AgreementsDemo.pbit` in Desktop with the built-in certified Docusign connector against the Demo account | Visuals populate → Navigator data exists on the account; capture ground-truth values & screenshots |
| 0.2 | Add the Navigator read scope (`adm_store_unified_repo_read`) to our Integration Key (SPA app — see existing OAuth config notes) and update `Scope` in `DocuSignPowerBI.pq` (currently `"signature extended"`) | Consent screen shows the new scope; token acquired |
| 0.3 | Call `GET api-d.docusign.com/v1/accounts/{id}/agreements` with that token; page through; save a raw response sample into `test/mocks/` | 200 + agreement JSON; document pagination (`ctoken`/`limit`) and the field names actually returned |
| 0.4 | Check whether obligations/custom-field data is reachable (inline in the agreement payload or a separate endpoint) | Written go/no-go for `Obligations` table in v1 |

**Risks surfaced here:** Navigator not provisioned on the Demo account (mitigation: enable
Navigator sample data in the demo admin, else build against mocks and verify on Production
later); scope addition rejected for the SPA app type; Navigator API field names differing from
the certified connector's column names (we map, we don't guess).

### Phase 1 — Connector: Agreements table group (1–2 days)

- `DocuSignPowerBI.pq`: add `GetAgreementsRaw` (paginated, reuse `HttpGetWithRetry`),
  `BuildAgreementsTable`, `FlattenParties`/`BuildPartiesTable`,
  `BuildAgreementCustomFieldsTable` (+ `BuildObligationsTable` if 0.4 passed) following the
  existing Build*/Flatten* pattern and `Safe*`/`ToDateTime` converters.
- Compute v1 derived columns in M (Appendix A, "derived" rows): `IsActive`,
  `IsExpiringIn30days/90days`, `IsRenewingIn30days/90days`, `IsTakingEffectIn30days/90days`,
  `EffectiveYearNumber`/`ExpirationYearNumber`, `EffectiveMonthYear`/`ExpirationMonthYear`,
  `TerminationNoticeDueDate`, `RenewalNoticeDate`. Emit real `null`s (no sentinel dates); do
  **not** bake "Unassigned" into the connector — leave presentation defaults to the report
  queries, mirroring the demo.
- Add the new entries to the navigation table next to the existing 8; keep names exactly
  `Agreements`, `Parties`, `CustomField` (`Obligations`) so query M stays close to the demo's.
- Tests: new `test/integration/08_agreements_endpoints.query.pq` with Facts over mocks; extend
  `test/mocks/docusign-mocks.txt` with the Phase 0 raw samples (scrubbed).
- 403 error hint in `HttpGetWithRetry` call sites should mention the Navigator scope, not just
  `signature extended`.

### Phase 2 — AgreementsReport.pbip (1–2 days)

- Scaffold `powerbi-report/AgreementsReport.pbip` + `.Report/` + `.SemanticModel/` by copying
  the structural files from DocuSignReport (known pitfalls: `version.json` must say exactly
  `"2.0.0"`; `report.json` must include `themeCollection` (`{}` ok); TMDL properties must be
  tab-indented under their object).
- Semantic model (TMDL): `Environment`/`AccountId` parameters (same as DocuSignReport);
  tables `Agreements`, `Parties`, `CustomField` (+`Obligations`); DAX `Date` table; DAX
  `Agreement Status Breakdown` union table; relationships
  `Parties[AgreementId] → Agreements[Id]`, `CustomField[AgreementId] → Agreements[Id]`
  (+ Obligations). Skip `FiscalDateDimension` and the `RowNum` cross-relationships in v1 unless
  a kept visual needs them.
- Port the Agreements measures (17 — Appendix B), wrapped in `COALESCE(..., 0)`, pointing at our
  column subset.
- Pages for v1: **Agreements Overview** (KPI cards: Agreements / Active / Expiring 90d / Due for
  Renewal 90d; status breakdown donut; expirations & renewals over time; by-type and
  by-party breakdowns; agreements detail table) and **Renewals & Obligations** (renewal
  pipeline, termination-notice deadlines; obligations visuals if in scope). Demo's Advanced
  Analysis / Tickets / Custom Charts pages: reference only, not ported.
- Eda theme + screenshots, mirroring `powerbi-report/README.md` conventions; add an
  AgreementsReport section or sibling README documenting model + verification status.

### Phase 3 — Package & verify (~half day)

- Desktop: open `AgreementsReport.pbip`, refresh against live Demo, fix, **File → Export →
  Power BI template** → `powerbi-report/Templates/AgreementsReport.pbit`.
- `scripts/package-distribution.ps1`: generalize the pbit step to verify/ship **both**
  templates (staleness + `DocuSignPowerBI.Contents(Environment, AccountId)` content check per
  template); dist gains `AgreementsReport.pbit`; regenerate `INSTALL.md` covering both.
- Run `/verify`-style end-to-end: fresh pbit open → parameter prompt → OAuth → visuals populate
  with live Demo counts; record results in `TEST-RESULTS.md`.

---

## 4. Open questions — all answered by Phase 0 (see §5)

1. ~~Does the Demo account have Navigator agreements?~~ **Only the `njeda` account has the
   Navigator API enabled; it was empty until seeded via Upload on 2026-11-26.** The `kkora`
   account returns 403 `EnableNavigatorAPIDataOut plan item` — the report must be run against
   `njeda` (the default account, so a blank AccountId works).
2. ~~Response schema vs. certified connector columns?~~ **snake_case JSON; contract terms live
   nested under `provisions` / `custom_provisions`** (vocabulary confirmed via
   `/agreement-types`: `effective_date`, `expiration_date`, `execution_date`,
   `total_contract_value`, `annual_contract_value`, `renewal`, `payment_terms`,
   `governing_law`, `jurisdiction_and_venue`, `liability_cap`, `late_payment_fee`,
   `price_cap_increase`, `termination_for_cause_notice_period`,
   `termination_for_convenience_notice_period`, `confidentiality_duration`, `nda_type`,
   `initial_term_length`, `assignment`, `signed_date`, `termination_date`, HR fields).
   Mapping to the demo's PascalCase columns is mechanical.
3. ~~Obligations / custom fields via public API?~~ **Obligations: no (404) — dropped from v1.**
   Custom fields: `custom_provisions` exists on the agreement payload (empty on the seed doc);
   the `c_*` pivot can be built from it in M.
4. ~~Scope addition admin work?~~ **None.** `adm_store_unified_repo_read` was accepted for the
   existing SPA Integration Key at consent time with zero Admin-UI changes.

## 5. Phase 0 results (live-verified 2026-11-26, Demo / `njeda` account)

- Full OAuth round-trip with scope `signature extended adm_store_unified_repo_read` using our
  ClientId + PKCE + the `Origin: https://oauth.powerbi.com` token-exchange header: **works**.
- `GET https://api-d.docusign.com/v1/accounts/{id}/agreements?limit=N` → 200. Response shape:
  `{ response_metadata, _links (first/self/next hrefs for paging), data: [agreement…] }`.
- Agreement object (list and detail endpoints return the same shape; detail adds `_actions`):
  `id`, `title`, `file_name`, `document_id`, `type`, `category`, `status` (e.g. `COMPLETE`),
  `review_status` (e.g. `PENDING`), `provisions {}`, `custom_provisions {}`, `languages []`,
  `source_name` (e.g. `UploadCenter`), `source_id`, `source_account_id`, `agreement_set_ids []`,
  `metadata { created_at/by, modified_at/by }`, `_links { document, agreement_types }`.
- 403 body worth surfacing in connector error hints:
  `"User does not have EnableNavigatorAPIDataOut plan item enabled"`.
- **Seed data (2026-11-26):** `scripts/seed-navigator-contracts.ps1` generated three
  contract .docx files (mutual NDA, auto-renewing MSA, office lease expiring 2027-02-28),
  manually uploaded via Navigator's Upload Center. All three extracted successfully —
  Navigator typed them `Nda` / `Msa` / `Lease` with 11 / 19 / 18 provisions and 2 parties
  each. Live 4-agreement response captured in `test/mocks/navigator-agreements-list.json`
  (plus `navigator-agreement-detail.json` for the detail-endpoint shape).
- **Parties shape (confirmed):** `parties: [{ id, name_in_agreement }]` — an array inline on
  each agreement. No role/side/type/email at this level, so the v1 `Parties` table is
  `AccountId, AgreementId, PartyId, PartyName` (trimmed from Appendix A's earlier guess).
- **Provision field names (confirmed, differ slightly from the `/agreement-types` vocabulary):**
  e.g. `effective_date`, `expiration_date`, `execution_date`, `term_length` (`"P1Y"`),
  `renewal_type` (`"AUTO_RENEW"`), `renewal_notice_period` (`"P60D"`), `renewal_notice_date`
  (computed by Navigator), `auto_renewal_term_length`, `payment_terms_due_date`
  (`"THIRTY_DAYS"`), `can_charge_late_payment_fees`, `late_payment_fee_percent`,
  `liability_cap_duration` (`"P12M"`), `price_cap_percent_increase`,
  `termination_period_for_cause` / `_for_convenience`, `assignment_type`,
  `assignment_change_of_control`, `assignment_termination_rights`, `governing_law`.
  **Durations are ISO-8601 strings (`P1Y`, `P60D`, `P12M`)** — Phase 1 needs a small M
  helper to convert these to day counts for the demo's `*Days` columns.

---

## Appendix A — v1 `Agreements` column subset (~40 of the demo's 123)

**Pass-through (from Navigator API):** `AccountId`, `Id`, `Name`, `Title`, `AgreementType`,
`Status`, `Summary`, `EffectiveDate`, `ExpirationDate`, `ExecutionDate`, `CreatedDate`,
`MetadataUpdatedAt`, `IsAutoRenewal`, `RenewalType`, `RenewalTerm`, `RenewalTermDays`,
`RenewalNoticePeriodDays`, `RenewalOwner`, `TerminationNoticePeriodDays`,
`TerminationNoticePeriod`, `TotalValue`, `TotalValueCurrency`, `AnnualContractValue`,
`GoverningLaw`, `Jurisdiction`, `PaymentTerms`, `Languages`, `SourceName`, `EnvelopeId`,
`IsTrashed`, `AiExtractionReviewStatus`, `MainPartyType`.

**Derived in M (the demo's measures/visuals depend on these):** `IsActive`,
`IsActiveIn30days`, `IsActiveIn90days`, `IsExpiringIn30days`, `IsExpiringIn90days`,
`IsRenewingIn30days`, `IsRenewingIn90days`, `IsTakingEffectIn30days`, `IsTakingEffectIn90days`
(all 0/1 Int64), `EffectiveYearNumber`, `ExpirationYearNumber`, `EffectiveMonthYear`,
`ExpirationMonthYear`, `RenewalNoticeDate` (ExpirationDate − RenewalNoticePeriodDays),
`TerminationNoticeDueDate` (ExpirationDate − TerminationNoticePeriodDays).

`Parties` v1: `AccountId`, `AgreementId`, `PartyId`, `PartyName`, `PartyRole`, `PartySide`,
`PartyType`, `PartyContactEmail`, `MainPartyDisplayName`, `CreatedDate`.

`Obligations` v1 (if in scope): `AccountId`, `Id`, `AgreementId`, `AgreementName`, `Type`,
`Name`, `Description`, `Owner`, `ObligationStatus`, `ObligationDueDate`, `Amount`,
`AmountCurrency`, + derived `IsDueIn90Days`, `ObligationDueDateYear`,
`ObligationDueDateMonthYear`.

## Appendix B — Demo measures to port

**Agreements (17):** `Agreements`, `Active Agreements`, `Agreements Expiring Next 90 Days`,
`Agreements Due for Renewal Next 90 Days`, `Confidentiality Obligations Due`,
`Payment Obligations Due`, `Termination Notice Deadlines`, `All Expired Agreements`,
`All Pending Renewal`, `All Active Agreements Without Renewals`, `Renewing Soon Count`,
`Expiring Soon (Non-Renewing) Count`, `Dynamic Status Count`, `Fiscal_Active Agreements`,
`ActiveAgreementsCount`, `AutoRenewalAgreementsCount`, `TrashedAgreementsCount`.

**Obligations (2):** `Obligation Activity Count`, `Obligations Due in Period` — only if
Obligations ships in v1.

**Tickets (3):** out of scope.

(The DAX bodies live in the sample's `DataModelSchema`; copy-adapt them during Phase 2 rather
than re-deriving.)
