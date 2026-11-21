# DocuSign Power BI Connector

Custom Power Query connector for DocuSign eSignature (REST API v2.1), using OAuth 2.0 Authorization Code with PKCE (S256). Exposes exactly eight tables: **Envelopes**, **Recipients**, **Envelope Status**, **Envelope Custom Fields**, **Envelope Audit Events**, **Templates**, **Envelope Documents**, **Accounts**. All read-only — the connector never creates, sends, signs, or modifies anything in DocuSign.

Build and automated-test status: see [TEST-RESULTS.md](TEST-RESULTS.md). 138/138 automated Facts pass against the compiled `.mez`; live Power BI Desktop/gateway/Service steps are documented below but not executed by this repo (they require interactive login and provisioned infrastructure).

## Connecting

`DocuSignPowerBI.Contents(environment, optional fromDate, optional toDate, optional accountId)`:

- `environment` (required): `"Demo"` or `"Production"`.
- `fromDate` (optional, `YYYY-MM-DD`): defaults to 30 days before today if omitted.
- `toDate` (optional, `YYYY-MM-DD`): defaults to no upper bound (through now) if omitted. Must not be before `fromDate`.
- `accountId` (optional): selects a specific DocuSign account when your login has access to more than one. Omit to use your default account. See the **Accounts** table to find available account ids.

All three optional parameters are excluded from the connector's Data Source Path, so changing them does not create a new credential entry or break scheduled refresh (see PBI-06 in TEST-RESULTS.md).

## Prerequisites

- A DocuSign **Demo** account (`account-d.docusign.com`) and a public-client Integration Key configured for Authorization Code + PKCE (no client secret).
- Redirect URI registered on the Integration Key: `https://oauth.powerbi.com/views/oauthredirect.html`.
- VS Code with the Power Query SDK extension (`powerquery.vscode-powerquery-sdk`), or just `dotnet` + the SDK's bundled `PQTest.exe`/MSBuild tasks.

The Integration Key (`ClientId`) is already set in `DocuSignPowerBI.pq` — do not replace it.

## Building

```sh
dotnet msbuild DocuSignPowerBI.proj /t:BuildMez
```

Produces `bin\AnyCPU\Debug\DocuSignPowerBI.mez`.

## Running the automated tests

No real DocuSign credentials are used. Unit tests are pure M (no network); integration tests run against the real compiled M code with HTTP responses mocked by PQTest's `--httpMock`, using an `OAuthPlaceholder` test credential (`test/settings.json`).

```sh
# Pure unit tests (PKCE, OAuth helpers, data transforms, null-safety)
PQTest.exe run-test -e bin\AnyCPU\Debug\DocuSignPowerBI.mez -q test\unit -p

# HTTP-mocked integration tests (pagination, errors, OAuth token exchange, new tables, multi-account, full Contents() flow)
PQTest.exe run-test -e bin\AnyCPU\Debug\DocuSignPowerBI.mez -q test\integration -hm test\mocks\docusign-mocks.txt -sf test\settings.json -p -tf "!06_unauthorized.query.pq"

# 401 -> refresh -> retry evidence (expected to fail with AccessUnauthorized - see TEST-RESULTS.md)
PQTest.exe run-test -e bin\AnyCPU\Debug\DocuSignPowerBI.mez -q test\integration\06_unauthorized.query.pq -hm test\mocks\docusign-mocks.txt -sf test\settings.json -p
```

`PQTest.exe` ships inside the VS Code extension, typically at:
`%USERPROFILE%\.vscode\extensions\powerquery.vscode-powerquery-sdk-*\.nuget\Microsoft.PowerQuery.SdkTools.*\tools\PQTest.exe`

## Power BI Desktop installation

1. Build the `.mez` (above), or use the one already in `bin\AnyCPU\Debug\`.
2. Copy `DocuSignPowerBI.mez` to `%USERPROFILE%\Documents\Power BI Desktop\Custom Connectors\` (create the folder if it doesn't exist).
3. In Power BI Desktop: **File → Options and settings → Options → Security → Data Extensions** → select **"Allow any extension to load without validation or warning"** (required for an unsigned connector in development).
4. Restart Power BI Desktop.
5. **Get Data → More... → Online Services → DocuSign eSignature**, then enter `Demo` (and optionally `fromDate`/`toDate`/`accountId` — see "Connecting" above).
6. Sign in with a DocuSign Demo account when prompted (OAuth browser dialog).
7. In Navigator, select any of the eight tables (**Envelopes**, **Recipients**, **Envelope Status**, **Envelope Custom Fields**, **Envelope Audit Events**, **Templates**, **Envelope Documents**, **Accounts**) and load. Only the tables you actually select trigger their corresponding API calls (Navigator data is lazy).

## Power BI Service / on-premises gateway installation

1. Install a Windows on-premises data gateway (standard mode) on a machine with network access to `account-d.docusign.com` and `demo.docusign.net`.
2. On the gateway machine, open the **On-premises data gateway** app → **Connectors** tab → set/confirm the custom connectors directory (default `C:\Program Files\On-premises data gateway\Custom Connectors` next to the gateway installer, or a custom path you configure there).
3. Copy the same `DocuSignPowerBI.mez` into that directory.
4. Restart the **On-premises data gateway service** (via the gateway app, or `services.msc` → "On-premises data gateway service").
5. In the Power BI Service (as a gateway admin): **Settings → Manage gateways** → select the gateway → **Add data source** → pick the custom connector (it will appear once the gateway picks up the `.mez`) → authenticate with OAuth as a DocuSign Demo user.
6. Publish the report/semantic model that uses this connector, then in the dataset's **Settings → Gateway connection**, map it to the gateway data source configured above.
7. Under **Scheduled refresh**, enable refresh and set a schedule; check **Refresh history** after the first run to confirm success.

OAuth connectors on gateways have real constraints (token refresh must succeed unattended, and some tenants restrict custom connectors by policy) — confirm with your gateway admin before relying on this for production refresh.

## Known limitations

See "Known limitations" in [TEST-RESULTS.md](TEST-RESULTS.md) — in short: the `Production` DocuSign environment is implemented identically to `Demo` but has not been exercised against a live tenant; `EnvironmentFromPath` is a best-effort/defensive parse (Power Query does not document a way to deserialize a function data source's `dataSourcePath`); and 429/5xx retry recovery is proven via the bounded-retry-then-fail path, not a "fails then succeeds" path (not expressible with PQTest's stateless HTTP mock server).

## Notes

This uses the eSignature API only; no envelope document *content* is ever downloaded, only metadata (name/type/page count). Recipients, Custom Fields, Audit Events, and Envelope Documents are each requested individually per envelope — that's up to 4 extra API calls per envelope on top of the envelope list itself, which may be slow or encounter rate limits for accounts with many envelopes. HTTP 429 is retried with bounded exponential backoff (see `MaxRetryAttempts`/`BaseRetryDelaySeconds`/`MaxRetryDelaySeconds` in `DocuSignPowerBI.pq`). Navigator tables are lazy, so a report that only loads, say, Envelopes and Envelope Status never triggers the Recipients/Custom Fields/Audit Events/Documents calls at all.
