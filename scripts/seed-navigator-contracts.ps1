<#
.SYNOPSIS
  Generates three contract .docx files (NDA, MSA, office lease) with rich
  extractable terms, for manual upload into DocuSign Navigator's Upload Center
  to seed the Agreements/Parties data behind AgreementsReport.pbip.

.DESCRIPTION
  Navigator's public API is read-only (adm_store_unified_repo_read), so seeding
  is a manual upload: run this, then in the Demo account (njeda) open
  Agreements -> + upload and select the three files from
  Downloads\navigator-seed. AI extraction takes a few minutes per document.
  The three contracts intentionally differ (auto-renew MSA, option-to-renew
  lease expiring soon, fixed-term mutual NDA) so status/renewal/expiration
  visuals all get non-trivial data. See AGREEMENTS-REPORT-PLAN.md.

  Output folder: Downloads\navigator-seed (overwrites existing files).
#>
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }

function New-SimpleDocx {
    param([string]$Path, [string[]]$Paragraphs)

    $paraXml = ($Paragraphs | ForEach-Object {
        if ($_ -eq "") { "<w:p/>" }
        else { "<w:p><w:r><w:t xml:space=""preserve"">$(Esc $_)</w:t></w:r></w:p>" }
    }) -join ""

    $documentXml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" +
        "<w:document xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">" +
        "<w:body>$paraXml</w:body></w:document>"

    $contentTypes = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" +
        "<Types xmlns=""http://schemas.openxmlformats.org/package/2006/content-types"">" +
        "<Default Extension=""rels"" ContentType=""application/vnd.openxmlformats-package.relationships+xml""/>" +
        "<Default Extension=""xml"" ContentType=""application/xml""/>" +
        "<Override PartName=""/word/document.xml"" ContentType=""application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml""/>" +
        "</Types>"

    $rels = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" +
        "<Relationships xmlns=""http://schemas.openxmlformats.org/package/2006/relationships"">" +
        "<Relationship Id=""rId1"" Type=""http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"" Target=""word/document.xml""/>" +
        "</Relationships>"

    if (Test-Path $Path) { Remove-Item $Path -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($entry in @(
            @{ Name = "[Content_Types].xml"; Content = $contentTypes },
            @{ Name = "_rels/.rels";         Content = $rels },
            @{ Name = "word/document.xml";   Content = $documentXml }
        )) {
            $e = $zip.CreateEntry($entry.Name)
            $w = New-Object System.IO.StreamWriter($e.Open(), (New-Object System.Text.UTF8Encoding($false)))
            $w.Write($entry.Content); $w.Dispose()
        }
    } finally { $zip.Dispose() }
}

$out = "C:\Users\kkora\Downloads\navigator-seed"
New-Item -ItemType Directory -Force $out | Out-Null

# ---- 1. NDA: effective/expiration, confidentiality duration, governing law ----
New-SimpleDocx -Path "$out\Mutual NDA - NJEDA and Garden State Analytics.docx" -Paragraphs @(
    "MUTUAL NON-DISCLOSURE AGREEMENT",
    "",
    "This Mutual Non-Disclosure Agreement (the ""Agreement"") is entered into and effective as of January 15, 2026 (the ""Effective Date""), by and between:",
    "New Jersey Economic Development Authority (""NJEDA""), a public body corporate and politic, with offices at 36 West State Street, Trenton, NJ 08625; and",
    "Garden State Analytics LLC (""GSA""), a New Jersey limited liability company, with offices at 101 Hudson Street, Jersey City, NJ 07302.",
    "",
    "1. PURPOSE. The parties wish to explore a business intelligence reporting engagement and may disclose Confidential Information to each other.",
    "2. TERM. This Agreement commences on the Effective Date and expires on January 14, 2028, unless terminated earlier.",
    "3. CONFIDENTIALITY PERIOD. Each party's confidentiality obligations shall survive for a period of five (5) years from the date of disclosure.",
    "4. TERMINATION. Either party may terminate this Agreement for convenience upon thirty (30) days prior written notice to the other party.",
    "5. GOVERNING LAW. This Agreement shall be governed by and construed in accordance with the laws of the State of New Jersey, and the parties consent to the exclusive jurisdiction and venue of the state and federal courts located in Mercer County, New Jersey.",
    "6. NDA TYPE. This is a mutual non-disclosure agreement; both parties may disclose and receive Confidential Information.",
    "",
    "IN WITNESS WHEREOF, the parties have executed this Agreement as of the Execution Date of January 10, 2026.",
    "NJEDA: Kanchan Kora, Director of Analytics",
    "Garden State Analytics LLC: Jay Carmona, Managing Partner"
)

# ---- 2. MSA: total value, payment terms, auto-renewal, liability cap, late fee ----
New-SimpleDocx -Path "$out\Master Services Agreement - NJEDA and BrightPath Consulting.docx" -Paragraphs @(
    "MASTER SERVICES AGREEMENT",
    "",
    "This Master Services Agreement (""Agreement"") is made and entered into effective as of March 1, 2026 (the ""Effective Date"") by and between:",
    "New Jersey Economic Development Authority (""Client""), 36 West State Street, Trenton, NJ 08625; and",
    "BrightPath Consulting Inc. (""Provider""), a Delaware corporation, 500 Market Street, Philadelphia, PA 19106.",
    "",
    "1. SERVICES. Provider shall perform data engineering and reporting services as described in applicable Statements of Work.",
    "2. TERM AND RENEWAL. The initial term of this Agreement is one (1) year from the Effective Date, expiring on February 28, 2027. This Agreement shall automatically renew for successive one (1) year renewal terms unless either party provides written notice of non-renewal at least sixty (60) days prior to the end of the then-current term.",
    "3. FEES AND CONTRACT VALUE. The total contract value for the initial term is $240,000.00 USD, with an annual contract value of $240,000.00 USD payable in equal monthly installments of $20,000.00.",
    "4. PAYMENT TERMS. Client shall pay all undisputed invoices within Net 30 days of receipt. A late payment fee of 1.5% per month applies to overdue amounts.",
    "5. PRICE INCREASES. Provider may increase fees upon renewal by no more than 5% per year.",
    "6. LIABILITY CAP. Each party's aggregate liability under this Agreement shall not exceed the total fees paid in the twelve (12) months preceding the claim.",
    "7. TERMINATION. Client may terminate this Agreement for convenience upon forty-five (45) days written notice. Either party may terminate for material breach upon fifteen (15) days written notice and failure to cure.",
    "8. ASSIGNMENT. Neither party may assign this Agreement without the prior written consent of the other, except to a successor in a merger or acquisition of all or substantially all assets, in which case termination rights apply.",
    "9. GOVERNING LAW. This Agreement is governed by the laws of the State of New Jersey.",
    "",
    "Executed on February 20, 2026.",
    "NJEDA: Kanchan Kora, Director of Analytics",
    "BrightPath Consulting Inc.: Morgan Ellis, Chief Executive Officer"
)

# ---- 3. Office Lease: expiring soon, renewal notice, payment terms, value ----
New-SimpleDocx -Path "$out\Office Lease Agreement - Trenton Commerce Center.docx" -Paragraphs @(
    "COMMERCIAL OFFICE LEASE AGREEMENT",
    "",
    "This Commercial Office Lease Agreement (""Lease"") is entered into effective as of March 1, 2024 (the ""Effective Date"") by and between:",
    "Trenton Commerce Center Partners LP (""Landlord""), 20 Commerce Drive, Trenton, NJ 08611; and",
    "New Jersey Economic Development Authority (""Tenant""), 36 West State Street, Trenton, NJ 08625.",
    "",
    "1. PREMISES. Landlord leases to Tenant approximately 4,200 rentable square feet on the third floor of the building located at 20 Commerce Drive, Trenton, New Jersey.",
    "2. TERM. The lease term is three (3) years, commencing March 1, 2024 and expiring February 28, 2027.",
    "3. RENEWAL OPTION. Tenant may renew this Lease for one (1) additional term of two (2) years by providing written notice to Landlord no later than ninety (90) days prior to the expiration of the initial term. This Lease does not renew automatically.",
    "4. RENT AND VALUE. Base rent is $8,750.00 per month, for a total contract value of $315,000.00 USD over the initial term. Rent is due on the first day of each month; payment terms are Net 10. A late payment fee of 5% applies to rent received more than five days late.",
    "5. SECURITY DEPOSIT. Tenant has deposited $17,500.00 as a lease deposit.",
    "6. TERMINATION. Landlord may terminate for cause upon thirty (30) days written notice of an uncured default. Tenant may not terminate for convenience during the initial term.",
    "7. GOVERNING LAW AND VENUE. This Lease is governed by the laws of the State of New Jersey; venue lies in Mercer County, New Jersey.",
    "",
    "Executed on February 15, 2024.",
    "Trenton Commerce Center Partners LP: Dana Whitfield, General Partner",
    "NJEDA: Kanchan Kora, Authorized Signatory"
)

Get-ChildItem $out | Select-Object Name, Length

