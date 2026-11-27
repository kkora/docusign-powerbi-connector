# DocuSign Power BI Report - Installation

Two files, two steps. You need Power BI Desktop and a DocuSign login.

## 1. Install the connector

Copy `DocuSignPowerBI.mez` to:

    %USERPROFILE%\Documents\Power BI Desktop\Custom Connectors

(create the folder if it does not exist), then in Power BI Desktop enable:

    File -> Options and settings -> Options -> Security -> Data Extensions
    -> "(Not Recommended) Allow any extension to load without validation or warning"

and restart Power BI Desktop. The connector is unsigned, which is why the
security setting is required.

## 2. Open the report template

Double-click `DocuSignReport.pbit`. You will be prompted for:

- **Environment** - `Demo` or `Production`.
- **AccountId** - leave blank to use your default DocuSign account, or paste a
  specific account id (the report's Accounts table lists the ids you can access).

Click **Load**, sign in with your DocuSign account when prompted (OAuth - no
password is stored in the report), and the visuals will populate.

## Troubleshooting

- "DocuSignPowerBI.Contents isn't recognized" - the .mez is not in the Custom
  Connectors folder, or Desktop was not restarted after copying it.
- OAuth window fails or loops - confirm you are using the right Environment
  (Demo logins live on account-d.docusign.com).
- Visuals show zeros - the connected account has no envelopes in the last
  30 days; send or seed some envelopes first.
