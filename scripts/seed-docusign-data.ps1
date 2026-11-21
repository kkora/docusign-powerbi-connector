<#
.SYNOPSIS
  Seeds a DocuSign Demo account with one template and three test envelopes
  (completed, pending, voided) so there's varied data to see through the
  DocuSignPowerBI Power BI connector.

.DESCRIPTION
  Run this yourself, locally. It opens your system browser for a real OAuth
  PKCE login (your DocuSign credentials never leave your machine / are never
  seen by this script, by Claude, or by anyone else) and uses only the public
  Integration Key - no client secret involved, matching the connector's
  public-client design.

.PREREQUISITE
  In DocuSign Admin, on the "Docusign Power Bi Connector" Integration Key,
  add a second Redirect URI (in addition to the Power BI one):
      http://localhost:8912/
  App Type should be "Native OS Application" with
  "Authorization Code Grant with Proof Key for Code Exchange (PKCE)".

.PARAMETER SignerEmail
  Your own email address - used as the signer/recipient on all three test
  envelopes, so you can sign the "completed" one yourself in the browser.

.PARAMETER SignerName
  Your display name as it should appear on the signed document.

.EXAMPLE
  .\seed-docusign-data.ps1 -SignerEmail "you@yourcompany.com" -SignerName "Kanchan Kora"
#>

param(
    [Parameter(Mandatory = $true)][string]$SignerEmail,
    [Parameter(Mandatory = $true)][string]$SignerName,
    [string]$ClientId = "226dd43b-4b8e-488a-9ba8-ac205c100833",
    [string]$AuthHost = "https://account-d.docusign.com",
    [int]$CallbackPort = 8912
)

$ErrorActionPreference = "Stop"
$RedirectUri = "http://localhost:$CallbackPort/"

function New-PkcePair {
    $bytes = New-Object byte[] 64
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $verifier = ([Convert]::ToBase64String($bytes)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($verifier))
    $challenge = ([Convert]::ToBase64String($hash)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    return @{ Verifier = $verifier; Challenge = $challenge }
}

function Start-InteractiveLogin {
    param([string]$ClientId, [string]$AuthHost, [string]$RedirectUri, [hashtable]$Pkce)

    $state = [Guid]::NewGuid().ToString("N")
    $authUrl = "$AuthHost/oauth/auth?" + (
        @(
            "response_type=code"
            "client_id=$ClientId"
            "redirect_uri=$([Uri]::EscapeDataString($RedirectUri))"
            "scope=$([Uri]::EscapeDataString('signature extended'))"
            "state=$state"
            "code_challenge=$($Pkce.Challenge)"
            "code_challenge_method=S256"
        ) -join "&"
    )

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($RedirectUri)
    $listener.Start()

    Write-Host "Opening your browser to log in to DocuSign..." -ForegroundColor Cyan
    Start-Process $authUrl

    Write-Host "Waiting for you to log in and approve access (listening on $RedirectUri)..." -ForegroundColor Cyan
    $context = $listener.GetContext()
    $query = [System.Web.HttpUtility]::ParseQueryString($context.Request.Url.Query)

    $responseHtml = "<html><body><h2>Login captured. You can close this tab and return to the terminal.</h2></body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
    $context.Response.ContentLength64 = $buffer.Length
    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $context.Response.OutputStream.Close()
    $listener.Stop()

    if ($query["error"]) {
        throw "DocuSign returned an OAuth error: $($query['error']) - $($query['error_description'])"
    }
    if ($query["state"] -ne $state) {
        throw "OAuth state mismatch - aborting."
    }

    return $query["code"]
}

Add-Type -AssemblyName System.Web

Write-Host "=== Step 1: OAuth login (your credentials, your browser) ===" -ForegroundColor Yellow
$pkce = New-PkcePair
$code = Start-InteractiveLogin -ClientId $ClientId -AuthHost $AuthHost -RedirectUri $RedirectUri -Pkce $pkce

Write-Host "=== Step 2: Exchanging code for an access token (no client secret) ===" -ForegroundColor Yellow
$tokenBody = @{
    grant_type    = "authorization_code"
    code          = $code
    code_verifier = $pkce.Verifier
    redirect_uri  = $RedirectUri
    client_id     = $ClientId
}
$token = Invoke-RestMethod -Method Post -Uri "$AuthHost/oauth/token" -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
$accessToken = $token.access_token
$headers = @{ Authorization = "Bearer $accessToken" }

Write-Host "=== Step 3: Account discovery ===" -ForegroundColor Yellow
$userInfo = Invoke-RestMethod -Method Get -Uri "$AuthHost/oauth/userinfo" -Headers $headers
$account = $userInfo.accounts | Where-Object { $_.is_default } | Select-Object -First 1
if (-not $account) { $account = $userInfo.accounts[0] }
$accountId = $account.account_id
$apiBase = $account.base_uri.TrimEnd("/") + "/restapi/v2.1/accounts/$accountId"
Write-Host "Using account $accountId at $($account.base_uri)" -ForegroundColor Green

Write-Host "=== Step 4: Creating a reusable template ===" -ForegroundColor Yellow
$docText = @"
POWER BI TEST DOCUMENT

This is a generated test document used to seed sample data for the
DocuSignPowerBI Power BI connector.

Signer: $SignerName

Please sign below:
/sig1/
"@
$docBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($docText))

$templateBody = @{
    name        = "PBI Test Template"
    description = "Seed template for Power BI connector testing"
    documents   = @(
        @{ documentId = "1"; name = "PBI Test Document.txt"; fileExtension = "txt"; documentBase64 = $docBase64 }
    )
    recipients  = @{
        signers = @(
            @{
                roleName     = "signer1"
                recipientId  = "1"
                routingOrder = "1"
                tabs         = @{
                    signHereTabs = @(
                        @{ anchorString = "/sig1/"; anchorUnits = "pixels"; anchorXOffset = "0"; anchorYOffset = "0" }
                    )
                }
            }
        )
    }
    status      = "created"
} | ConvertTo-Json -Depth 10

$template = Invoke-RestMethod -Method Post -Uri "$apiBase/templates" -Headers $headers -Body $templateBody -ContentType "application/json"
$templateId = $template.templateId
Write-Host "Template created: $templateId" -ForegroundColor Green

function New-EnvelopeFromTemplate {
    param([string]$Status, [string]$EmailSubjectSuffix, [switch]$Embedded)

    $clientUserId = if ($Embedded) { "1001" } else { $null }
    $signerRole = @{
        roleName   = "signer1"
        name       = $SignerName
        email      = $SignerEmail
    }
    if ($clientUserId) { $signerRole["clientUserId"] = $clientUserId }

    $envelopeBody = @{
        templateId      = $templateId
        templateRoles   = @($signerRole)
        status          = $Status
        emailSubject    = "PBI Test Envelope - $EmailSubjectSuffix"
    } | ConvertTo-Json -Depth 10

    $envelope = Invoke-RestMethod -Method Post -Uri "$apiBase/envelopes" -Headers $headers -Body $envelopeBody -ContentType "application/json"

    if ($Embedded) {
        $viewBody = @{
            returnUrl     = "https://www.docusign.com"
            authenticationMethod = "none"
            email         = $SignerEmail
            userName      = $SignerName
            clientUserId  = $clientUserId
        } | ConvertTo-Json
        $view = Invoke-RestMethod -Method Post -Uri "$apiBase/envelopes/$($envelope.envelopeId)/views/recipient" -Headers $headers -Body $viewBody -ContentType "application/json"
        return @{ EnvelopeId = $envelope.envelopeId; SigningUrl = $view.url }
    }
    return @{ EnvelopeId = $envelope.envelopeId; SigningUrl = $null }
}

Write-Host "=== Step 5: Creating envelope #1 - to be signed now (will become 'completed') ===" -ForegroundColor Yellow
$completedEnvelope = New-EnvelopeFromTemplate -Status "sent" -EmailSubjectSuffix "Completed" -Embedded
Write-Host "Opening the signing ceremony in your browser - please click through and sign it." -ForegroundColor Cyan
Start-Process $completedEnvelope.SigningUrl
Write-Host "Press Enter once you've finished signing in the browser..." -ForegroundColor Cyan
Read-Host | Out-Null

Write-Host "=== Step 6: Creating envelope #2 - left as 'sent' (stays pending) ===" -ForegroundColor Yellow
$pendingEnvelope = New-EnvelopeFromTemplate -Status "sent" -EmailSubjectSuffix "Pending"
Write-Host "Envelope created and sent: $($pendingEnvelope.EnvelopeId) (check your inbox - leave it unsigned)" -ForegroundColor Green

Write-Host "=== Step 7: Creating envelope #3 and voiding it ===" -ForegroundColor Yellow
$voidEnvelope = New-EnvelopeFromTemplate -Status "sent" -EmailSubjectSuffix "Voided"
$voidBody = @{ status = "voided"; voidedReason = "Test void for Power BI validation" } | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$apiBase/envelopes/$($voidEnvelope.EnvelopeId)" -Headers $headers -Body $voidBody -ContentType "application/json" | Out-Null
Write-Host "Envelope voided: $($voidEnvelope.EnvelopeId)" -ForegroundColor Green

Write-Host ""
Write-Host "Done. You now have 3 test envelopes (completed/pending/voided) in account $accountId." -ForegroundColor Green
Write-Host "Open Power BI Desktop and connect / refresh to see them." -ForegroundColor Green
