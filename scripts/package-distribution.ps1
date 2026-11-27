<#
.SYNOPSIS
    Builds the DocuSignPowerBI connector, deploys it locally, and packages the
    end-user distribution (connector .mez + report template .pbit + install guide)
    into the dist\ folder.

.DESCRIPTION
    Steps:
      1. Build  - compiles DocuSignPowerBI.mez via dotnet msbuild.
      2. Deploy - copies the .mez into this machine's Power BI Desktop
                  Custom Connectors folder (skip with -SkipDeploy).
      3. Pbit   - verifies the exported report template exists, is newer than the
                  report/model sources, and actually contains the parameterized
                  2-argument connector call (catches a stale export).
      4. Package- assembles dist\ with the .mez, .pbit, and a generated INSTALL.md.

    The .pbit itself must be exported manually first - Power BI Desktop is the only
    tool that can produce one:
        open powerbi-report\DocuSignReport.pbip in Desktop
        -> File -> Export -> Power BI template
        -> save as powerbi-report\Templates\DocuSignReport.pbit
    (Leave the template description blank or describe the report; do NOT enter data.)

.EXAMPLE
    .\package-distribution.ps1
.EXAMPLE
    .\package-distribution.ps1 -SkipDeploy
#>
param(
    # Path to the .pbit exported from Power BI Desktop.
    [string]$PbitPath = "",
    # Skip copying the .mez to this machine's Custom Connectors folder.
    [switch]$SkipDeploy,
    # Output folder for the distribution package.
    [string]$DistDir = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
if ($PbitPath -eq "") { $PbitPath = Join-Path $RepoRoot "powerbi-report\Templates\DocuSignReport.pbit" }
if ($DistDir -eq "") { $DistDir = Join-Path $RepoRoot "dist" }
$MezPath = Join-Path $RepoRoot "bin\AnyCPU\Debug\DocuSignPowerBI.mez"

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

# ----- 3. Verify the exported .pbit -----
Write-Host "== Checking report template ==" -ForegroundColor Cyan
if (-not (Test-Path $PbitPath)) {
    Write-Host @"
Report template not found: $PbitPath

Power BI Desktop is the only tool that can export a .pbit. To create it:
  1. Open powerbi-report\DocuSignReport.pbip in Power BI Desktop.
  2. File -> Export -> Power BI template.
  3. Save as: $PbitPath
Then re-run this script.

"@ -ForegroundColor Red
    exit 1
}

# Staleness: the export must be newer than every report/model source file.
$sourceDirs = @(
    (Join-Path $RepoRoot "powerbi-report\DocuSignReport.SemanticModel"),
    (Join-Path $RepoRoot "powerbi-report\DocuSignReport.Report")
)
$newestSource = Get-ChildItem -Recurse -File $sourceDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$pbitItem = Get-Item $PbitPath
if ($newestSource.LastWriteTime -gt $pbitItem.LastWriteTime) {
    Write-Host ("WARNING: {0} ({1:g}) is older than source file {2} ({3:g})." -f `
        $pbitItem.Name, $pbitItem.LastWriteTime, $newestSource.Name, $newestSource.LastWriteTime) -ForegroundColor Yellow
    Write-Host "Re-export the template from Power BI Desktop if the report or model changed since." -ForegroundColor Yellow
}

# Content sanity check: the packaged model must use the parameterized connector call.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($pbitItem.FullName)
try {
    $schemaEntry = $zip.Entries | Where-Object { $_.FullName -eq "DataModelSchema" }
    if ($null -eq $schemaEntry) { throw "No DataModelSchema inside $PbitPath - not a valid template export?" }
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
        throw "Stale or wrong .pbit: DataModelSchema does not contain '$required'. Re-export from Desktop after Apply changes."
    }
}
Write-Host "Template OK: parameterized connector call and parameters present." -ForegroundColor Green

# ----- 4. Assemble dist\ -----
Write-Host "== Packaging $DistDir ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
Copy-Item $MezPath -Destination (Join-Path $DistDir "DocuSignPowerBI.mez") -Force
Copy-Item $pbitItem.FullName -Destination (Join-Path $DistDir "DocuSignReport.pbit") -Force

$installMd = @'
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
'@
Set-Content -Path (Join-Path $DistDir "INSTALL.md") -Value $installMd -Encoding utf8

Get-ChildItem $DistDir | ForEach-Object { Write-Host ("  dist\{0}  ({1:N0} bytes)" -f $_.Name, $_.Length) }
Write-Host "Done. Ship the dist\ folder contents to end users." -ForegroundColor Green
