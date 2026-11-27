<#
.SYNOPSIS
    Builds the DocuSignPowerBI connector, deploys it locally, and packages the
    end-user distribution (connector .mez + both report templates .pbit + install
    guide) into the dist\ folder.

.DESCRIPTION
    Steps:
      1. Build  - compiles DocuSignPowerBI.mez via dotnet msbuild.
      2. Deploy - copies the .mez into this machine's Power BI Desktop
                  Custom Connectors folder (skip with -SkipDeploy).
      3. Pbit   - for each report template (DocuSignReport, AgreementsReport):
                  verifies the exported template exists, is newer than its
                  report/model sources, and actually contains the parameterized
                  2-argument connector call (catches a stale export).
      4. Package- assembles dist\ with the .mez, both .pbit files, and a
                  generated INSTALL.md.

    The .pbit files themselves must be exported manually first - Power BI Desktop
    is the only tool that can produce one:
        open powerbi-report\<Name>.pbip in Desktop
        -> File -> Export -> Power BI template
        -> save as powerbi-report\Templates\<Name>.pbit
    (Leave the template description blank or describe the report; do NOT enter data.)

.EXAMPLE
    .\package-distribution.ps1
.EXAMPLE
    .\package-distribution.ps1 -SkipDeploy
#>
param(
    # Skip copying the .mez to this machine's Custom Connectors folder.
    [switch]$SkipDeploy,
    # Output folder for the distribution package.
    [string]$DistDir = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
if ($DistDir -eq "") { $DistDir = Join-Path $RepoRoot "dist" }
$MezPath = Join-Path $RepoRoot "bin\AnyCPU\Debug\DocuSignPowerBI.mez"

# Each shipped template: the Desktop-exported .pbit plus the source folders whose
# newest file participates in the staleness check.
$Templates = @(
    @{
        Name       = "DocuSignReport"
        PbitPath   = Join-Path $RepoRoot "powerbi-report\Templates\DocuSignReport.pbit"
        SourceDirs = @(
            (Join-Path $RepoRoot "powerbi-report\DocuSignReport.SemanticModel"),
            (Join-Path $RepoRoot "powerbi-report\DocuSignReport.Report")
        )
    },
    @{
        Name       = "AgreementsReport"
        PbitPath   = Join-Path $RepoRoot "powerbi-report\Templates\AgreementsReport.pbit"
        SourceDirs = @(
            (Join-Path $RepoRoot "powerbi-report\AgreementsReport.SemanticModel"),
            (Join-Path $RepoRoot "powerbi-report\AgreementsReport.Report")
        )
    }
)

# ----- 1. Build the connector -----
Write-Host "== Building DocuSignPowerBI.mez ==" -ForegroundColor Cyan
dotnet msbuild (Join-Path $RepoRoot "DocuSignPowerBI.proj") -t:BuildMez -v:m
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed (exit $LASTEXITCODE)." }
if (-not (Test-Path $MezPath)) { throw "Build reported success but $MezPath is missing." }

# ----- 2. Deploy the connector locally -----
if (-not $SkipDeploy) {
    $connectorDir = "$env:USERPROFILE\Documents\Power BI Desktop\Custom Connectors"
    Write-Host "== Deploying .mez to $connectorDir ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $connectorDir | Out-Null
    Copy-Item $MezPath -Destination $connectorDir -Force
    Write-Host "Deployed. Restart Power BI Desktop to load the new connector." -ForegroundColor Yellow
}

# ----- 3. Verify the exported .pbit files -----
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-Template {
    param([hashtable]$Template)

    $pbitPath = $Template.PbitPath
    Write-Host "== Checking template: $($Template.Name) ==" -ForegroundColor Cyan

    if (-not (Test-Path $pbitPath)) {
        Write-Host @"
Report template not found: $pbitPath

Power BI Desktop is the only tool that can export a .pbit. To create it:
  1. Open powerbi-report\$($Template.Name).pbip in Power BI Desktop.
  2. File -> Export -> Power BI template.
  3. Save as: $pbitPath
Then re-run this script.

"@ -ForegroundColor Red
        throw "Missing template: $($Template.Name).pbit"
    }

    # Staleness: the export must be newer than every report/model source file.
    $newestSource = Get-ChildItem -Recurse -File $Template.SourceDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $pbitItem = Get-Item $pbitPath
    if ($newestSource.LastWriteTime -gt $pbitItem.LastWriteTime) {
        Write-Host ("WARNING: {0} ({1:g}) is older than source file {2} ({3:g})." -f `
            $pbitItem.Name, $pbitItem.LastWriteTime, $newestSource.Name, $newestSource.LastWriteTime) -ForegroundColor Yellow
        Write-Host "Re-export the template from Power BI Desktop if the report or model changed since." -ForegroundColor Yellow
    }

    # Content sanity check: the packaged model must use the parameterized connector call.
    $zip = [System.IO.Compression.ZipFile]::OpenRead($pbitItem.FullName)
    try {
        $schemaEntry = $zip.Entries | Where-Object { $_.FullName -eq "DataModelSchema" }
        if ($null -eq $schemaEntry) { throw "No DataModelSchema inside $pbitPath - not a valid template export?" }
        $reader = New-Object System.IO.StreamReader($schemaEntry.Open(), [System.Text.Encoding]::Unicode)
        try { $schema = $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally {
        $zip.Dispose()
    }
    foreach ($required in @(
        "DocuSignPowerBI.Contents(Environment, AccountId)",
        "IsParameterQuery=true"
    )) {
        if (-not $schema.Contains($required)) {
            throw "Stale or wrong $($Template.Name).pbit: DataModelSchema does not contain '$required'. Re-export from Desktop after Apply changes."
        }
    }
    Write-Host "Template OK: parameterized connector call and parameters present." -ForegroundColor Green
    return $pbitItem
}

$verified = foreach ($t in $Templates) { Test-Template -Template $t }

# ----- 4. Assemble dist\ -----
Write-Host "== Packaging $DistDir ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
Copy-Item $MezPath -Destination (Join-Path $DistDir "DocuSignPowerBI.mez") -Force
foreach ($p in $verified) { Copy-Item $p.FullName -Destination (Join-Path $DistDir $p.Name) -Force }

$installMd = @'
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
'@
Set-Content -Path (Join-Path $DistDir "INSTALL.md") -Value $installMd -Encoding utf8

Get-ChildItem $DistDir | ForEach-Object { Write-Host ("  dist\{0}  ({1:N0} bytes)" -f $_.Name, $_.Length) }
Write-Host "Done. Ship the dist\ folder contents to end users." -ForegroundColor Green
