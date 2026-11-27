# Scripts

## package-distribution.ps1

Builds and packages everything an end user needs to run the report, into `dist\`:
`DocuSignPowerBI.mez` (the connector), `DocuSignReport.pbit` (the parameterized report
template), and a generated `INSTALL.md` with end-user setup steps.

### What it does

1. **Build** — compiles the connector via `dotnet msbuild DocuSignPowerBI.proj -t:BuildMez`.
2. **Deploy** — copies the fresh `.mez` into this machine's `Documents\Power BI Desktop\Custom Connectors` folder (skip with `-SkipDeploy`). Restart Power BI Desktop afterwards to load it.
3. **Verify template** — checks that `powerbi-report\Templates\DocuSignReport.pbit` exists, warns if it's older than any report/model source file, and inspects the zip's `DataModelSchema` to confirm it contains the parameterized `DocuSignPowerBI.Contents(Environment, AccountId)` call and the `Environment`/`AccountId` parameters — catching a stale export before it ships.
4. **Package** — assembles `dist\` with the `.mez`, `.pbit`, and `INSTALL.md`.

### The one manual step

Power BI Desktop is the only tool that can export a `.pbit` (there is no CLI for it).
After any report or model change:

1. Open `powerbi-report\DocuSignReport.pbip` in Power BI Desktop.
2. **File → Export → Power BI template**.
3. Save as `powerbi-report\Templates\DocuSignReport.pbit`.
4. Re-run this script.

The template stores no data and no credentials — on open it prompts for `Environment`
and `AccountId`, then runs OAuth sign-in.

### Usage and parameters

```powershell
.\package-distribution.ps1              # build + deploy + verify + package
.\package-distribution.ps1 -SkipDeploy  # build + verify + package only
```

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `PbitPath` | No | `powerbi-report\Templates\DocuSignReport.pbit` | Location of the Desktop-exported template. |
| `SkipDeploy` | No | off | Don't copy the `.mez` to the local Custom Connectors folder. |
| `DistDir` | No | `dist` | Output folder for the distribution package. |

## seed-docusign-data.ps1

Seeds a DocuSign **Demo** account with one reusable template and three test envelopes — one **completed**, one **pending**, one **voided** — so the DocuSignPowerBI connector has varied data to display in Power BI.

### How it works

1. **OAuth login (PKCE)** — generates a PKCE verifier/challenge, opens your system browser to the DocuSign login page, and captures the authorization code on a local HTTP listener (`http://localhost:8912/` by default). Your credentials are entered only in the browser, directly on DocuSign's site; the script never sees them. No client secret is used, matching the connector's public-client design.
2. **Token exchange** — swaps the authorization code + PKCE verifier for an access token.
3. **Account discovery** — calls `/oauth/userinfo` and picks your default account (falls back to the first account) to build the REST API base URL.
4. **Template creation** — uploads a small text document with a `/sig1/` anchor and creates a template named **"PBI Test Template"** with a single signer role.
5. **Envelope #1 (completed)** — sent with an embedded signing session; the script opens the signing ceremony in your browser and waits for you to press Enter after signing.
6. **Envelope #2 (pending)** — sent to your email and intentionally left unsigned, so it stays in `sent` status.
7. **Envelope #3 (voided)** — sent, then immediately voided with reason "Test void for Power BI validation".

### Prerequisites

- **Windows PowerShell 5.1+** (uses `System.Net.HttpListener` and `System.Web`; no modules to install).
- A **DocuSign Demo account** (the default auth host is `https://account-d.docusign.com`).
- In **DocuSign Admin → Apps and Keys**, on the *"Docusign Power Bi Connector"* Integration Key:
  - Add a redirect URI of `http://localhost:8912/` (in addition to the Power BI one).
  - Leave the existing connector settings as they are: App Type **Single-Page Web Application**, **Authorization Code Grant with PKCE**, and **CORS enabled** for `https://oauth.powerbi.com`. The script sends a matching `Origin` header on the token exchange, because DocuSign requires one for SPA-type keys (`invalid_grant / origin_required_but_not_included` otherwise).

### Usage

```powershell
.\seed-docusign-data.ps1 -SignerEmail "you@yourcompany.com" -SignerName "Your Name"
```

Use **your own** email and name — you are the signer on all three envelopes, which lets you complete the first one yourself in the browser.

When the signing page opens for envelope #1, click through and sign it, then return to the terminal and press **Enter** so the script can continue.

### Parameters

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `SignerEmail` | Yes | — | Email used as the recipient on all three envelopes. |
| `SignerName` | Yes | — | Display name shown on the signed document. |
| `ClientId` | No | `226dd43b-...-100833` | The connector's public Integration Key. |
| `AuthHost` | No | `https://account-d.docusign.com` | DocuSign account server. Use `https://account.docusign.com` for Production (not recommended for seeding test data). |
| `CallbackPort` | No | `8912` | Local port for the OAuth redirect. If you change it, the redirect URI registered in DocuSign Admin must match. |
| `TemplateId` | No | — | Reuse an existing template instead of creating a new one (resume after a partial run). |
| `SkipCompleted` | No | off | Skip envelope #1 and its interactive signing step (resume when a completed envelope already exists). |

### What you end up with

| Item | Status | Notes |
| --- | --- | --- |
| PBI Test Template | — | Reusable template with one signer role (`signer1`). |
| PBI Test Envelope - Completed | `completed` | Signed by you via embedded signing. |
| PBI Test Envelope - Pending | `sent` | Arrives in your inbox; leave it unsigned. |
| PBI Test Envelope - Voided | `voided` | Voided immediately after sending. |

Then open Power BI Desktop and connect/refresh with the DocuSignPowerBI connector to see the data.

### Resuming a partial run

If the script fails partway (e.g. after the template and completed envelope were created), don't start from scratch — reuse what exists:

```powershell
.\seed-docusign-data.ps1 -SignerEmail "you@yourcompany.com" -SignerName "Your Name" `
    -TemplateId "<template id printed earlier>" -SkipCompleted
```

Omit `-SkipCompleted` if the completed envelope was never signed.

### Troubleshooting

- **Browser opened but the script hangs on "Waiting for you to log in"** — the listener blocks until the redirect arrives. If you closed the login tab, re-run the script (Ctrl+C to stop it first).
- **Port already in use / listener fails to start** — pass a different `-CallbackPort` and add the matching `http://localhost:<port>/` redirect URI in DocuSign Admin.
- **"OAuth state mismatch" error** — the listener received a request that wasn't the real OAuth redirect (the script now ignores stray browser requests like `favicon.ico`, so this should only appear if a genuinely different login response arrived — e.g. a leftover tab from a previous run). Re-run the script and use the freshly opened browser tab.
- **`invalid_grant / origin_required_but_not_included` on token exchange** — the Integration Key is SPA-type, so DocuSign demands an `Origin` header matching a registered CORS origin. The script sends `Origin: https://oauth.powerbi.com`; if this error appears, verify that origin is still listed under "Allow CORS for OAuth calls" in DocuSign Admin.
- **`consent_required` or OAuth error page** — the Integration Key is missing the localhost redirect URI, or the app type/grant settings don't match the prerequisites above.
- **"A connection that was expected to be kept alive was closed by the server"** — Windows PowerShell 5.1 reuses pooled HTTPS connections, and DocuSign closes them server-side during long pauses (like the signing wait). The script now retries these transient failures automatically (up to 3 attempts), so if you still see this error it persisted across retries — check your network and re-run with `-TemplateId`/`-SkipCompleted` to resume.
- **Envelope #1 shows as `sent`, not `completed`** — you pressed Enter before finishing the signing ceremony. Sign it from the browser tab (or the email link), and it will complete; the script does not verify the final status.

### Notes

- The script is **not idempotent**: each run creates a new template and three new envelopes. That's harmless in a Demo account, but repeated runs will accumulate duplicates named "PBI Test Template".
- The access token is held only in the PowerShell session's memory and is not written to disk.
