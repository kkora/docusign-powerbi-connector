# DocuSign Power BI Connector

Custom Power Query connector for DocuSign eSignature (REST API v2.1), using OAuth 2.0 Authorization Code with PKCE (S256). Exposes exactly eight tables: **Envelopes**, **Recipients**, **Envelope Status**, **Envelope Custom Fields**, **Envelope Audit Events**, **Templates**, **Envelope Documents**, **Accounts**. All read-only — the connector never creates, sends, signs, or modifies anything in DocuSign.

Build and automated-test status: see [TEST-RESULTS.md](TEST-RESULTS.md). 138/138 automated Facts pass against the compiled `.mez`. The OAuth/PKCE/token-exchange path and all 8 tables have also been verified live against a real DocuSign Demo account (see "Live verification" in TEST-RESULTS.md); literal Power BI Desktop UI, gateway, and Service scheduled refresh are documented below but still not executed by this repo (they require provisioned infrastructure beyond interactive login).

## Connecting

`DocuSignPowerBI.Contents(environment, optional accountId)`:

- `environment` (required): `"Demo"` or `"Production"`.
- `accountId` (optional): selects a specific DocuSign account when your login has access to more than one. Omit to use your default account. See the **Accounts** table to find available account ids.

Envelope retrieval covers the last 30 days through now. The unpublished `DocuSignPowerBI.ContentsWithDates(environment, optional fromDate, optional toDate, optional accountId)` variant retains explicit `YYYY-MM-DD` date-range control (used by the integration test suite; also callable from hand-written M).

The optional parameters are excluded from the connector's Data Source Path, so changing them does not create a new credential entry or break scheduled refresh (see PBI-06 in TEST-RESULTS.md).

## Prerequisites

- A DocuSign **Demo** account (`account-d.docusign.com`) and a public-client Integration Key configured for Authorization Code + PKCE (no client secret).
- Redirect URI registered on the Integration Key: `https://oauth.powerbi.com/views/oauthredirect.html`.
- VS Code with the Power Query SDK extension (`powerquery.vscode-powerquery-sdk`), or just `dotnet` + the SDK's bundled `PQTest.exe`/MSBuild tasks.

The Integration Key (`ClientId`) is already set in `DocuSignPowerBI.pq` — do not replace it.

### DocuSign Admin configuration (required — confirmed by live testing)

On the Integration Key, under **Authentication → User Application**:

- **"Is your application able to securely store a client secret?"** → **No** (this is a public client; PKCE replaces the secret).
- **"Select App Type"** → **Single-Page Web Application** — *not* "Native OS Application". This matters even though the connector's actual token-exchange HTTP call runs in Power Query's native engine, not browser JavaScript: DocuSign's classification is driven by the redirect mechanism (Power BI's OAuth catcher is a real `https://` page loaded in a browser/WebView), not by which component later makes the token request.
- **"Authentication Method"** → **Authorization Code Grant with Proof Key for Code Exchange (PKCE)**.
- Under the **CORS** section (only visible when App Type is Single-Page Web Application): enable **"Allow CORS for OAuth calls"** and add `https://oauth.powerbi.com` as an allowed origin.
- Under **Redirect URIs**: confirm `https://oauth.powerbi.com/views/oauthredirect.html` is present.

Without the CORS setting enabled, DocuSign's token endpoint rejects the exchange with `invalid_grant / cors_not_enabled_for_oauth`. This was discovered via live testing (see "Live verification" in [TEST-RESULTS.md](TEST-RESULTS.md)) — mocked tests cannot catch it, since it's a property of DocuSign's real OAuth server, not of request/response shapes.

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
2. Copy `DocuSignPowerBI.mez` to `%USERPROFILE%\Documents\Power BI Desktop\Custom Connectors\` (creates the folder if it doesn't exist):

   ```powershell
   $dest = "$env:USERPROFILE\Documents\Power BI Desktop\Custom Connectors"
   New-Item -ItemType Directory -Force -Path $dest | Out-Null
   Copy-Item "bin\AnyCPU\Debug\DocuSignPowerBI.mez" -Destination $dest -Force
   ```

3. In Power BI Desktop: **File → Options and settings → Options → Security → Data Extensions** → select **"Allow any extension to load without validation or warning"** (required for an unsigned connector in development).
4. Restart Power BI Desktop.
5. **Get Data → More... → Online Services → DocuSign eSignature**, then enter `Demo` (and optionally `accountId` — see "Connecting" above).
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

## Distributing this connector to another org

This connector uses a **single shared Integration Key** (Model A: the key identifies the app, not the customer — the same pattern certified connectors like Salesforce/ServiceNow use). A different org can use it with their own DocuSign data with **no code changes**:

1. Copy the same `DocuSignPowerBI.mez` to their machine and follow the Desktop installation steps above.
2. They sign in with **their own** DocuSign login, not yours — DocuSign's `/oauth/userinfo` only returns accounts that login has access to, so there's no cross-org data mixing.
3. They'll see an OAuth consent screen for this app (by its registered name) and need to approve it, since it's a third-party app from their tenant's perspective.
4. For **scheduled refresh in Power BI Service**, they need their **own on-premises data gateway** — this is mandatory for any uncertified custom connector (Power BI Service can't run one directly in the cloud) and can't be shared across orgs. Same gateway steps as above, done on their own gateway machine.

Two things that don't change with the org, and are worth confirming before distributing:

- **Demo works for anyone immediately; Production does not.** DocuSign's Demo environment has no consent gate. For another org's **Production** DocuSign data, this Integration Key needs DocuSign's one-time "Go-Live" review first (done once by the key owner, not per customer).
- If an org's security policy won't allow consenting to a third-party-owned app, the alternative is a "bring-your-own-key" design (`integrationKey` as a required connection parameter, so each org registers their own Integration Key) — not currently implemented; would need `StartLogin`/`FinishLogin`/`Refresh` to recover it from `dataSourcePath` the same defensive way `environment` is recovered today.

## Known limitations

See "Known limitations" in [TEST-RESULTS.md](TEST-RESULTS.md) — in short: the `Production` DocuSign environment is implemented identically to `Demo` and the `Demo` OAuth path is now live-verified, but `Production` has not been exercised against a live tenant; and 429/5xx retry recovery is proven via the bounded-retry-then-fail path, not a "fails then succeeds" path (not expressible with PQTest's stateless HTTP mock server).

## Notes

This uses the eSignature API only; no envelope document *content* is ever downloaded, only metadata (name/type/page count). Recipients, Custom Fields, Audit Events, and Envelope Documents are each requested individually per envelope — that's up to 4 extra API calls per envelope on top of the envelope list itself, which may be slow or encounter rate limits for accounts with many envelopes. HTTP 429 is retried with bounded exponential backoff (see `MaxRetryAttempts`/`BaseRetryDelaySeconds`/`MaxRetryDelaySeconds` in `DocuSignPowerBI.pq`). Navigator tables are lazy, so a report that only loads, say, Envelopes and Envelope Status never triggers the Recipients/Custom Fields/Audit Events/Documents calls at all.
