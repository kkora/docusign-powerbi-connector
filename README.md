# DocuSign Power BI Connector — source prototype

This is a source prototype, **not a validated or production-ready .mez**. It has not been compiled or tested against DocuSign or Power BI. The current source is Demo-only. The `TestConnection` handler and navigator presentation require validation with the Power Query SDK and gateway. Do not use for production refresh without completing the checklist below.

## Configuration
1. Create/configure a DocuSign public-client Integration Key for Authorization Code with PKCE (no embedded client secret).
2. Register `https://oauth.powerbi.com/views/oauthredirect.html` as the exact redirect URI, subject to DocuSign application settings and verification.
3. Replace `REPLACE_WITH_DOCUSIGN_INTEGRATION_KEY` in `DocuSignPowerBI.pq`.
4. Install VS Code and Microsoft Power Query SDK; create a connector project and replace the generated `.pq` source with this file. Build the project to produce `.mez`.
5. Install `.mez` in `[Documents]\Power BI Desktop\Custom Connectors`; allow trusted unsigned extensions during local development and restart Desktop.
6. Connect using `DocuSignPowerBI.Contents("Demo", "2026-01-01")` and select the resulting table's `Data` cells. This prototype does not yet implement a standard navigation table.

## Gateway
1. Install a supported Windows on-premises data gateway (standard mode recommended).
2. Configure its custom connectors directory, place the identical `.mez` there, enable custom connector loading, and restart the gateway service.
3. In Power BI Service, configure a gateway data source and OAuth credentials as a gateway admin. Map the published semantic model to it, then enable scheduled refresh.

## Validation required before claiming completion
- Build and load in Power BI Desktop, and validate OAuth authorization, state, PKCE, token refresh, and redirect.
- Validate `TestConnection` with the gateway; the current hard-coded date/parameter mapping is not adequate for arbitrary `fromDate` values.
- Verify the default account selection, pagination behavior and rate-limit handling against real API responses.
- Add safe retries for 429/5xx, optional date range and incremental refresh strategy.
- Replace Demo-only host handling with an explicit environment selector and verified production base URI.
- Implement proper navigation metadata and stable typed table schemas.
- Validate gateway service OAuth refresh and end-to-end scheduled refresh.

## Notes
This uses the eSignature API only; no envelope documents are downloaded. Recipients are requested individually for each envelope, which may be slow or hit rate limits for large datasets.
