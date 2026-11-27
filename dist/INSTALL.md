# DocuSign Power BI Reports - Installation

One connector, two report templates, two steps. You need Power BI Desktop and a
DocuSign login.

## 1. Install the connector

Copy `DocuSignPowerBI.mez` to:

    %USERPROFILE%\Documents\Power BI Desktop\Custom Connectors

(create the folder if it does not exist), then in Power BI Desktop enable:

    File -> Options and settings -> Options -> Security -> Data Extensions
    -> "(Not Recommended) Allow any extension to load without validation or warning"

and restart Power BI Desktop. The connector is unsigned, which is why the
security setting is required.

## 2. Open a report template

Two templates are included - open either (or both):

- **DocuSignReport.pbit** - eSignature activity: envelopes, recipients, status,
  custom fields, audit events, templates, documents, accounts.
- **AgreementsReport.pbit** - DocuSign Navigator agreement repository: AI-extracted
  contract terms, parties, renewals, expirations. Requires the account to have
  DocuSign Navigator provisioned; without it the refresh fails with HTTP 403
  (plan item EnableNavigatorAPIDataOut).

Double-click the `.pbit`. You will be prompted for:

- **Environment** - `Demo` or `Production`.
- **AccountId** - leave blank to use your default DocuSign account, or paste a
  specific account id (the DocuSignReport Accounts table lists the ids you can
  access).

Click **Load**, sign in with your DocuSign account when prompted (OAuth - no
password is stored in the report), and the visuals will populate. The consent
screen includes the Navigator read permission; if you had signed in with an
older version of the connector, clear the credential first
(File -> Options and settings -> Data source settings -> Clear Permissions)
so the new permission is granted.

## Troubleshooting

- "DocuSignPowerBI.Contents isn't recognized" - the .mez is not in the Custom
  Connectors folder, or Desktop was not restarted after copying it.
- OAuth window fails or loops - confirm you are using the right Environment
  (Demo logins live on account-d.docusign.com).
- AgreementsReport fails with HTTP 403 - the selected account does not have
  DocuSign Navigator provisioned, or the saved credential predates the
  Navigator permission (clear it and sign in again).
- Visuals show zeros - the connected account has no envelopes in the last
  30 days (DocuSignReport) or no agreements in Navigator (AgreementsReport);
  send, seed, or upload some first.
