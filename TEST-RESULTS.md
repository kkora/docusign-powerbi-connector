# Test Results

Run date: 2026-11-21. Toolchain: Power Query SDK `Microsoft.PowerQuery.SdkTools 2.160.2` (`PQTest.exe`), built via `dotnet msbuild DocuSignPowerBI.proj /t:BuildMez` (MSBuild 18.9.15). Artifact under test: `bin\AnyCPU\Debug\DocuSignPowerBI.mez` (clean rebuild, see PBI-02).

All tests below were **actually executed** against the compiled `.mez` — no result is asserted without a corresponding `pqtest run-test` invocation. Commands to reproduce are in [README.md](README.md#running-the-automated-tests).

## Summary

| Suite | Facts run | Passed | Failed |
|---|---|---|---|
| `test/unit/*.query.pq` (pure, no network) | 90 | 90 | 0 |
| `test/integration/*.query.pq` (HTTP-mocked via PQTest `--httpMock`) | 48 | 48 | 0 |
| **Total** | **138** | **138** | **0** |

Plus one non-Fact evidence run (`06_unauthorized.query.pq`, see AUTH-09/API-06 below).

No test used real DocuSign credentials. OAuth was exercised via PQTest's `OAuthPlaceholder` test credential and a stateless HTTP mock fixture (`test/mocks/docusign-mocks.txt`, 27 request/response pairs).

This run covers the baseline connector (91 Facts, carried forward unchanged in behavior except the intentionally-extended Recipients schema — see DATA-03) plus the ten new features (F01–F10) added on top of it: Envelope Custom Fields, Historical Date Filtering (`toDate`), Envelope Audit Events, Enhanced Recipients, Multi-Account Selection, Templates, Envelope Documents, API performance/reliability, timezone-aware audit timestamps, and gateway/stable-path compatibility.

## New feature tests (F01–F10)

| ID | Feature | Result | Evidence |
|---|---|---|---|
| F01 | Envelope Custom Fields | PASS | `test/unit/04_new_tables_transforms.query.pq` (pure flatten of text + list fields, empty case, schema) and `test/integration/07_new_tables_endpoints.query.pq` (live mocked `/custom_fields` fetch, field values, `AccountId`/`EnvelopeId` association). Deduplicated via `Table.Distinct(..., {"EnvelopeId", "FieldName"})`. |
| F02 | Historical Date Filtering (`toDate`) | PASS | `ResolveToDate` unit tests (valid/null/invalid) in `04_new_tables_transforms.query.pq`; `test/integration/08_multi_account_and_date_range.query.pq` proves `fromDate` after `toDate` is rejected with `DocuSign.Config` before any HTTP call, and the existing `fromDate`-only integration tests (01–04) continue to pass unchanged, confirming backward compatibility. |
| F03 | Envelope Audit Events | PASS | Same two files — event ordering preserved, timezone-aware `EventDateTime` (`datetimezone`, not collapsed to naive datetime), alias-based field lookup (`UserName`/`logTime`/`Action` confirmed against DocuSign's own developer documentation), missing optional fields default to `null`, duplicate events deduplicated via `Table.Distinct`. |
| F04 | Enhanced Recipient Details | PASS | `test/unit/02_transforms.query.pq` (DATA-03/04, updated for the new columns) — `RecipientRole`, `SentDateTime`, `DeclinedDateTime`, `DeclineReason`, `AuthenticationMethod`, per-recipient `CompletionHours`, `AccountId` all added additively; existing columns unchanged. |
| F05 | Multi-Account Selection | PASS | `04_new_tables_transforms.query.pq` (`BuildAccountsTable` unit tests) and `08_multi_account_and_date_range.query.pq` — Accounts table lists every accessible account with exactly one `IsDefault = true`; an explicit `accountId` pulls that account's data instead of the default; an inaccessible `accountId` is rejected with `DocuSign.Account` before any data call. |
| F06 | Templates | PASS | Same two files — `BuildTemplatesTable` maps `created` (not `createdDateTime` — confirmed against the current DocuSign API reference, which uses a different field name than envelopes), nested `owner.userName`, `shared`; pagination reuses the same `resultSetSize`/`totalSetSize`/`endPosition` pattern as envelopes; missing optional metadata defaults to `null`; empty list yields a typed zero-row table. |
| F07 | Envelope Document Metadata | PASS | Same two files — `Pages` is derived as a count of the `pages` array (the API returns page objects, not a page count); multiple documents per envelope all appear; no binary/content endpoint is ever called (only the metadata-listing `/documents` endpoint, confirmed by the mock fixture only registering that URL). |
| F08 | API Retrieval Performance | PASS (design-level) | `envelopesTable` is wrapped in `Table.Buffer` since five downstream builders (Recipients, Status, Custom Fields, Audit Events, Documents) all consume it — materialized once rather than re-walked per consumer. Navigator `Data` columns remain lazy (confirmed experimentally via the 401 test: untouched tables trigger zero HTTP requests). Not independently benchmarked; no dedicated performance test exists beyond the structural guarantees above. |
| F09 | Timezone-Aware Date Handling | PASS | `ToDateTimeZone` unit-tested directly; Audit Events' `EventDateTime` is the only new column typed `datetimezone` (preserves the original offset). Existing `datetime` columns on Envelopes/Recipients/Envelope Status are intentionally left unchanged to avoid breaking existing Power BI semantic models — see "Known limitations." |
| F10 | Gateway and Scheduled Refresh Compatibility | PASS (design-level) | `toDate` and `accountId` are both `optional`, so — like `fromDate` before them — neither factors into the Data Source Path; `DataSourceAnalysis.Path` stays `{"environment":"Demo"}` across every integration test regardless of date range or account selected. Live gateway/Service execution is BLOCKED (see PBI-09/PBI-10). |

## Authentication tests

| ID | Description | Result | Evidence |
|---|---|---|---|
| AUTH-01 | OAuth authorization URL | PASS | `test/unit/01_pkce_and_oauth.query.pq` — asserts host, `code_challenge_method=S256`, `code_challenge=`, caller state, and the registered redirect URI. |
| AUTH-02 | PKCE S256 generation | PASS | Same file — `DocuSignPowerBI.Challenge("abc...XYZ")` matched a SHA256/base64url vector computed independently via `openssl dgst -sha256 | openssl base64 | tr`; verifier length/charset checked against RFC 7636. |
| AUTH-03 | PKCE verifier/challenge matching | PASS | Determinism (`Challenge(v) = Challenge(v)`) and distinctness across two generated verifiers. |
| AUTH-04 | OAuth state validation | PASS | `FinishLogin` called directly with mismatched state, missing code, and an upstream `error=access_denied` — all three rejected with a clear error. |
| AUTH-05 | Authorization code exchange | PASS | `test/integration/05_oauth_token_exchange.query.pq` — `FinishLogin` against a mocked `POST .../oauth/token` 200 response; returns `access_token`/`refresh_token`. |
| AUTH-06 | Invalid authorization code | PASS | Same file — mocked 400 `invalid_grant` response; error surfaced via `try`, not a crash. *(Routed through the `Production` host as a mock-routing device, since the HTTP mock matcher only keys on method/URL/headers, not body — see file comment. This does not claim Production OAuth itself is live-tested; see "Known limitations" in README.)* |
| AUTH-07 | Access token refresh | PASS | Same file — `Refresh("Demo", ...)` against the same mocked token endpoint; returns a new `access_token`. |
| AUTH-08 | Revoked refresh token | PASS | Same file — `Refresh("Production", ...)` against the mocked 400 `invalid_grant` response (same mock-routing caveat as AUTH-06). |
| AUTH-09 | Unauthorized response | PASS (evidence, not a Fact) | `test/integration/06_unauthorized.query.pq`. See below. |
| AUTH-10 | No secret leakage | PASS | Static review: `Grep -i "client_secret"` across `DocuSignPowerBI.pq` returns no matches. `access_token`/`refresh_token` only appear as field *names* read from `Extension.CurrentCredential()` or passed through as parameters — never as literal values. `StartLogin`'s `Context` record was asserted to expose only `{environment, verifier}`. |

### AUTH-09 / API-06 detail: the 401 → refresh → retry path

`06_unauthorized.query.pq` mocks the envelopes endpoint to always return 401. Running it produced:

```
HttpMock: RequestCount=3, SuccessfulMatches=3, FailedMatches=0
Error: "The credentials provided for the DocuSignPowerBI source are invalid. (Source at {"environment":"Demo"}.)"
Details.Microsoft.Data.Mashup.CredentialError.Reason: "AccessUnauthorized"
```

This confirms the full real flow: (1) the 401 is left out of `ManualStatusHandling` so the Power Query engine's own OAuth logic takes over, (2) it called our `Refresh` function (a real HTTP request against the mocked token endpoint — visible in the request count), (3) it retried the original call, which the (stateless) mock again returned 401 for, and (4) the engine correctly gave up with `AccessUnauthorized` rather than hanging or looping. That is the correct, expected outcome.

It is **not** expressed as a PQUnit `Fact` because once PQTest's harness marks a test credential invalid this way, that is a host-level abort rather than a catchable M `error` value — wrapping the call in `try` does not intercept it (confirmed experimentally: the same scenario inside a `Fact`/`try` crashes the whole test file rather than producing a `HasError = true` record). This is a PQTest tooling limitation, not a defect in the connector.

## API tests

| ID | Description | Result | Evidence |
|---|---|---|---|
| API-01 | Account discovery | PASS | `test/integration/01_happy_path.query.pq` — `GetUserInfo` against mocked `/oauth/userinfo`; `AccountId` from the discovered account is stamped onto every row. |
| API-02 | API base URI parsing | PASS | Same file — `base_uri` from the mocked account record drives every subsequent envelopes/recipients URL (proven implicitly: those mocked URLs only match if the base URI was parsed correctly). |
| API-03 | Single-page envelopes | PASS | Same file — 2 mocked envelopes returned in one page; subjects/fields verified. |
| API-04 | Multi-page pagination | PASS | `test/integration/02_pagination.query.pq` — 3 envelopes across 2 mocked pages (`resultSetSize`/`totalSetSize`/`endPosition`-driven), all 3 ids present after combining. |
| API-05 | Empty response | PASS | `test/integration/03_empty_and_duplicates.query.pq` — zero envelopes mocked; all eight output tables resolve to typed, zero-row tables. |
| API-06 | HTTP 401 | PASS (evidence) | See AUTH-09 above. |
| API-07 | HTTP 403 | PASS | `test/integration/04_error_handling.query.pq` — mocked 403; surfaces `DocuSign.Forbidden` immediately (no retry). |
| API-08 | HTTP 429 | PASS | Same file — mocked 429 with `Retry-After: 1`, returned on every attempt (stateless mock); retried up to `MaxRetryAttempts` (3) with exponential bounded backoff, then fails cleanly with `DocuSign.HttpError` mentioning `429`. Proves the retry loop is bounded (doesn't hang) and backoff math doesn't throw. |
| API-09 | HTTP 500/503 | PASS | Same file — mocked persistent 500; same bounded-retry-then-fail path, error mentions `500`. |
| API-10 | Invalid JSON | PASS | Same file — mocked 200 response with a non-JSON body; `SafeJsonDocument` raises a clear `DocuSign.InvalidResponse` error instead of an engine crash. |

## Dataset tests

| ID | Description | Result | Evidence |
|---|---|---|---|
| DATA-01 | Envelope schema | PASS | `test/unit/02_transforms.query.pq` — `BuildEnvelopesTable` output has exactly `AccountId, EnvelopeId, EmailSubject, Status, CreatedDateTime, SentDateTime, CompletedDateTime, VoidedDateTime, LastModifiedDateTime` — unchanged from the baseline (backward compatible). |
| DATA-02 | Envelope data types | PASS | Same file — `CreatedDateTime` column schema kind is `datetime`; ISO8601 timestamps parse correctly; `AccountId` propagated from account discovery. |
| DATA-03 | Recipient schema | PASS | Same file — `FlattenRecipients` output now has exactly `AccountId, EnvelopeId, RecipientId, RecipientName, RecipientEmail, RecipientType, RecipientRole, RoutingOrder, RecipientStatus, SentDateTime, SignedDateTime, DeliveredDateTime, DeclinedDateTime, DeclineReason, AuthenticationMethod, CompletionHours` — **intentionally extended by F04** (additive; every original column is still present under its original name/type). This test's expected column list was updated as part of implementing F04, not a silent regression. |
| DATA-04 | Recipient types | PASS | Same file — a `signers` and a `carbonCopies` entry both flow through with the correct `RecipientType`; `RoutingOrder` converted from the API's string to a number; integration happy-path additionally proves it end-to-end across a real two-envelope, two-bucket fetch. |
| DATA-05 | Missing fields | PASS | Same file — an envelope missing `emailSubject`/`sentDateTime` defaults those columns to `null` rather than erroring; a recipients response with no buckets at all flattens to zero rows. |
| DATA-06 | Status mapping | PASS | Same file — `completed` → `IsCompleted`, `voided` → `IsVoided`, `sent` → `IsPending`, each with the other flags correctly false. |
| DATA-07 | Completion hours | PASS | Same file and `01_happy_path.query.pq` — `CompletionHours` computed as `(CompletedDateTime - SentDateTime)` in hours (3.5h and 10h cases, matching hand-computed expected values). |
| DATA-08 | Null completion date | PASS | `02_transforms.query.pq` — a sent-but-not-completed envelope and a voided envelope (no `completedDateTime`) both yield `CompletionHours = null`, not an error. |
| DATA-09 | Empty envelope list | PASS | `02_transforms.query.pq` (unit) and `03_empty_and_duplicates.query.pq` (integration, end-to-end) — zero rows, full typed schema preserved. |
| DATA-10 | Duplicate envelope handling | PASS | Same two files — a duplicated `EnvelopeId` in the raw API response collapses to one row after `Table.Distinct`, both in the pure transform and end-to-end through `Contents`. |

## Power BI / connector tests

| ID | Description | Result | Evidence |
|---|---|---|---|
| PBI-01 | Project compiles | PASS | `dotnet msbuild DocuSignPowerBI.proj /t:Clean` then `/t:BuildMez` succeeds with no errors; `pqtest info -e DocuSignPowerBI.mez` reports `ErrorStatus: null`. |
| PBI-02 | `.mez` generated | PASS | `bin\AnyCPU\Debug\DocuSignPowerBI.mez` exists (20,752 bytes at last clean build); confirmed to be a valid ZIP containing `DocuSignPowerBI.pq`, all 8 icon PNGs, and `resources.resx`. |
| PBI-03 | Connector metadata | PASS | `pqtest info` output shows `DataSourceKind: "DocuSignPowerBI"`, `Publish: {Beta: true, Category: "Online Services", ...}`, `Authentication: OAuth` with `AccessToken`/`RefreshToken`/`Expires` properties, and icons wired via `SourceImage`/`SourceTypeImage`. |
| PBI-04 | Exactly eight navigator tables | PASS | `01_happy_path.query.pq` — `Table.RowCount(nav) = 8` and names are exactly `Envelopes`, `Recipients`, `Envelope Status`, `Envelope Custom Fields`, `Envelope Audit Events`, `Templates`, `Envelope Documents`, `Accounts` (was 3 tables before this feature set; requirement updated to 8 per the current spec). |
| PBI-05 | `TestConnection` | PARTIAL | The tuple `TestConnection` returns (`{"DocuSignPowerBI.Contents", "Demo"}`) is exactly the call exercised successfully by every integration test above — so the mechanism is proven. The `pqtest validate` command itself does not support HTTP mocking and requires a live network call with real credentials, which is BLOCKED in this environment (see "Remaining blockers"). |
| PBI-06 | Stable data source path | PASS | `fromDate`, `toDate`, and `accountId` are all `optional` parameters, so none of them factor into the Data Source Path — confirmed directly in `pqtest run-test`'s `DataSourceAnalysis` output, which shows the identical path `{"environment":"Demo"}` across every integration test despite each using different dates and/or an explicit account. |
| PBI-07 | Desktop OAuth login | BLOCKED | Requires an interactive browser login against a real DocuSign Demo account; not available in this autonomous/headless environment. |
| PBI-08 | Desktop data load | BLOCKED | Depends on PBI-07. |
| PBI-09 | Gateway connector loading | BLOCKED | Requires a provisioned on-premises data gateway machine. |
| PBI-10 | Service scheduled refresh | BLOCKED | Requires a Power BI Service tenant, a configured gateway, and a live DocuSign account. |

## Known limitations

- **Production environment is implemented but untested against a live tenant.** `AuthHost`/`EnvironmentFromPath` support `"Production"` with the same logic as `"Demo"`, and AUTH-06/AUTH-08 reuse the `Production` routing purely as a way to hit a second, distinct mock URL (HTTP mocks only match on method/URL/headers, not body, so two scenarios hitting the same token endpoint can't be told apart otherwise). This is a test-harness device, not a claim that Production OAuth has been exercised against `account.docusign.com`.
- **`EnvironmentFromPath` is a best-effort, defensive parse.** Power Query does not document an API to deserialize a function-based data source's `dataSourcePath` back into the original parameter record, so `StartLogin`/`FinishLogin`/`Refresh` recover the environment via a substring match on the path's text representation, defaulting to `Demo`. This has been validated for the `Demo` case (every integration test's `DataSourceAnalysis.Path` is `{"environment":"Demo"}`); the `Production` path is logically identical but not live-verified.
- **429/5xx "recovers after N retries" is not separately tested.** PQTest's HTTP mock server is stateless (the same request always returns the same response), so a mock can't simulate "fails twice, then succeeds." The tests instead prove the bounded-retry-then-fail path (API-08/API-09), which is the harder case: it proves attempts are capped (no infinite loop) and the backoff/Retry-After parsing code runs without throwing.
- **Templates `Status` column is always `null` against a real tenant.** DocuSign's `GET /templates` response, per the current API reference, does not include a `status` field at all — confirmed via documentation research, not assumed. The column is still exposed (per the required schema) but will not carry data unless DocuSign adds one.
- **Envelope Audit Events field names are not rigidly fixed by DocuSign.** The `eventFields` array uses generic `{name, value}` pairs whose exact `name` values can vary by event type and API version. `UserName`, `logTime`, and `Action` are confirmed real values (per DocuSign's own developer blog); others (`IP Address`, `EventDescription`, `Result`) are implemented as defensive multi-alias lookups that degrade to `null` rather than erroring, but have **not** been validated against a live tenant's actual audit event payloads. This is the single highest-priority item to verify once live DocuSign access is available.
- **F08 performance improvements are structural, not benchmarked.** `Table.Buffer` around the shared `envelopesTable` and the Navigator's inherent column-level laziness are real, verifiable mechanisms (the latter confirmed experimentally via the 401 test's `HttpMock.RequestCount`), but no load test against a large (100+ envelope) account has been run — that requires live API access.
- **Each new per-envelope table adds its own HTTP call per envelope.** Custom Fields, Audit Events, and Documents each require one additional request per envelope (on top of the existing Recipients call), so an account with many envelopes will make proportionally more API calls when those Navigator tables are actually loaded (they stay unfetched if a report never touches them, per the laziness noted under F08). Respect DocuSign's documented rate limits accordingly.
