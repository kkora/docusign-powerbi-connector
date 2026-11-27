<#
.SYNOPSIS
  Generates contract .docx files with rich extractable terms, for manual upload
  into DocuSign Navigator's Upload Center to seed the Agreements/Parties data
  behind AgreementsReport.pbip.

.DESCRIPTION
  Navigator's public API is read-only (adm_store_unified_repo_read), so seeding
  is a manual upload: run this, then in the Demo account (njeda) open
  Agreements -> + upload and select the generated files. AI extraction takes a
  few minutes per document. See AGREEMENTS-REPORT-PLAN.md.

  Two batches:
  - Downloads\navigator-seed\         : the original 3 contracts (NDA/MSA/lease)
                                        already uploaded on 2026-11-26.
  - Downloads\navigator-seed\batch2\  : 12 further contracts spanning expired /
                                        active / expiring-in-30d / expiring-in-90d /
                                        taking-effect-soon, AUTO_RENEW vs
                                        RENEW_OPTION vs FIXED_TERM, values from
                                        $36k to $420k, and 10 distinct
                                        counterparties - so the report's KPI,
                                        renewal-pipeline, and timeline visuals
                                        get a realistic distribution.

  Date anchors assume "today" is late Nov 2026 (e.g. the expiring-in-30-days
  contracts end mid-Dec 2026 - early Jan 2027); shift dates if reseeding much later.

  Output folders are created as needed; existing files are overwritten.
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

# ===================== Batch 2: 12 varied contracts =====================
# Composed via a shared section builder so each spec stays readable. Every
# contract names NJEDA plus one distinct counterparty, and the date/renewal/
# value spread is deliberate (see .DESCRIPTION).

$out2 = Join-Path $out "batch2"
New-Item -ItemType Directory -Force $out2 | Out-Null

function New-ContractDocx {
    param([string]$FileName, [string]$Title, [string]$Intro, [string[]]$Clauses, [string]$Closing, [string[]]$Signatures)
    New-SimpleDocx -Path (Join-Path $out2 $FileName) -Paragraphs (@($Title, "", $Intro, "") + $Clauses + @("", $Closing) + $Signatures)
}

New-ContractDocx -FileName "SOW - Data Platform Implementation - BrightPath Consulting.docx" `
    -Title "STATEMENT OF WORK NO. 2 - DATA PLATFORM IMPLEMENTATION" `
    -Intro "This Statement of Work (""SOW"") is entered into effective as of June 1, 2026 (the ""Effective Date"") by and between New Jersey Economic Development Authority (""Client""), 36 West State Street, Trenton, NJ 08625, and BrightPath Consulting Inc. (""Provider""), 500 Market Street, Philadelphia, PA 19106, under the parties' Master Services Agreement." `
    -Clauses @(
        "1. SERVICES. Provider shall implement Client's cloud data platform, including ingestion pipelines, a reporting warehouse, and Power BI deployment support.",
        "2. TERM. This SOW commences on the Effective Date and expires on December 19, 2026. This SOW does not renew; the term is fixed.",
        "3. FEES. The total contract value for this SOW is $180,000.00 USD, invoiced monthly on a time-and-materials basis.",
        "4. PAYMENT TERMS. Client shall pay undisputed invoices within Net 30 days of receipt.",
        "5. TERMINATION. Client may terminate this SOW for convenience upon fifteen (15) days written notice.",
        "6. GOVERNING LAW. This SOW is governed by the laws of the State of New Jersey.") `
    -Closing "Executed on May 20, 2026." `
    -Signatures @("NJEDA: Kanchan Kora, Director of Analytics", "BrightPath Consulting Inc.: Morgan Ellis, Chief Executive Officer")

New-ContractDocx -FileName "SaaS Subscription Agreement - CloudLedger Financials.docx" `
    -Title "SOFTWARE-AS-A-SERVICE SUBSCRIPTION AGREEMENT" `
    -Intro "This SaaS Subscription Agreement is entered into effective as of February 1, 2026 (the ""Effective Date"") by and between CloudLedger Financials Inc. (""Vendor""), a Delaware corporation, 200 Continental Drive, Newark, DE 19713, and New Jersey Economic Development Authority (""Customer""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. SUBSCRIPTION. Vendor grants Customer a subscription to the CloudLedger financial reporting platform for up to 150 named users.",
        "2. TERM AND RENEWAL. The initial subscription term runs from the Effective Date through January 31, 2027. The subscription automatically renews for successive one (1) year terms unless either party gives written notice of non-renewal at least thirty (30) days before the end of the then-current term.",
        "3. FEES. The annual contract value is $96,000.00 USD, payable annually in advance.",
        "4. PAYMENT TERMS. Invoices are due Net 15. A late payment fee of 1.5% per month applies to overdue balances.",
        "5. PRICE INCREASES. Renewal pricing may increase by no more than 7% per renewal term.",
        "6. LIABILITY CAP. Each party's aggregate liability is capped at the fees paid in the twelve (12) months preceding the claim.",
        "7. TERMINATION. Either party may terminate for material breach upon thirty (30) days written notice and failure to cure.",
        "8. GOVERNING LAW. This Agreement is governed by the laws of the State of Delaware.") `
    -Closing "Executed on January 22, 2026." `
    -Signatures @("CloudLedger Financials Inc.: Priya Raman, VP Sales", "NJEDA: Kanchan Kora, Director of Analytics")

New-ContractDocx -FileName "Equipment Maintenance Agreement - Liberty HVAC Services.docx" `
    -Title "EQUIPMENT MAINTENANCE AND SERVICE AGREEMENT" `
    -Intro "This Equipment Maintenance and Service Agreement is entered into effective as of April 1, 2025 (the ""Effective Date"") by and between Liberty HVAC Services LLC (""Contractor""), 88 Industrial Parkway, Camden, NJ 08102, and New Jersey Economic Development Authority (""Owner""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. SERVICES. Contractor shall provide quarterly preventive maintenance and on-call repair services for Owner's HVAC systems at 36 West State Street.",
        "2. TERM AND RENEWAL. The initial term is three (3) years, expiring March 31, 2028. This Agreement automatically renews for successive one (1) year terms unless either party provides written notice of non-renewal at least ninety (90) days prior to expiration.",
        "3. FEES. The annual contract value is $36,000.00 USD, billed quarterly.",
        "4. PAYMENT TERMS. Invoices are payable Net 45.",
        "5. TERMINATION. Owner may terminate for convenience on sixty (60) days written notice; either party may terminate for cause on fifteen (15) days notice.",
        "6. GOVERNING LAW. This Agreement is governed by the laws of the State of New Jersey.") `
    -Closing "Executed on March 18, 2025." `
    -Signatures @("Liberty HVAC Services LLC: Tom Okafor, Operations Director", "NJEDA: Kanchan Kora, Authorized Signatory")

New-ContractDocx -FileName "Supply Agreement - Pinelands Paper Company.docx" `
    -Title "SUPPLY AGREEMENT" `
    -Intro "This Supply Agreement was entered into effective as of January 1, 2024 (the ""Effective Date"") by and between Pinelands Paper Company (""Supplier""), 410 Mill Road, Hammonton, NJ 08037, and New Jersey Economic Development Authority (""Buyer""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. SUPPLY. Supplier shall supply office paper and printed materials per Buyer's purchase orders.",
        "2. TERM. The term ran from the Effective Date through December 31, 2025, with no renewal. The agreement has a fixed two (2) year term.",
        "3. VALUE. The total contract value is $120,000.00 USD over the term.",
        "4. PAYMENT TERMS. Invoices are payable Net 60.",
        "5. TERMINATION. Either party could terminate for convenience on thirty (30) days written notice.",
        "6. GOVERNING LAW. This Agreement is governed by the laws of the Commonwealth of Pennsylvania.") `
    -Closing "Executed on December 12, 2023." `
    -Signatures @("Pinelands Paper Company: Ruth Delgado, Sales Manager", "NJEDA: Kanchan Kora, Procurement Lead")

New-ContractDocx -FileName "Consulting Agreement - Meridian Grant Advisors.docx" `
    -Title "CONSULTING AGREEMENT" `
    -Intro "This Consulting Agreement was entered into effective as of September 15, 2025 (the ""Effective Date"") by and between Meridian Grant Advisors LLC (""Consultant""), 1180 Avenue of the Americas, New York, NY 10036, and New Jersey Economic Development Authority (""Client""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. SERVICES. Consultant advised Client on federal grant program compliance and reporting.",
        "2. TERM AND RENEWAL. The term ran one (1) year from the Effective Date, expiring September 14, 2026. Client held an option to renew for one additional year by written notice at least sixty (60) days before expiration; the option was not exercised.",
        "3. FEES. The total contract value is $75,000.00 USD.",
        "4. PAYMENT TERMS. Invoices were payable Net 30.",
        "5. TERMINATION. Either party could terminate for convenience on thirty (30) days written notice.",
        "6. GOVERNING LAW. This Agreement is governed by the laws of the State of New York.") `
    -Closing "Executed on September 2, 2025." `
    -Signatures @("Meridian Grant Advisors LLC: Daniel Katz, Managing Director", "NJEDA: Kanchan Kora, Director of Analytics")

New-ContractDocx -FileName "Software License Agreement - MapWorks GIS.docx" `
    -Title "ENTERPRISE SOFTWARE LICENSE AGREEMENT" `
    -Intro "This Enterprise Software License Agreement is entered into effective as of January 1, 2026 (the ""Effective Date"") by and between MapWorks GIS Corporation (""Licensor""), 55 Technology Drive, Edison, NJ 08837, and New Jersey Economic Development Authority (""Licensee""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. LICENSE. Licensor grants Licensee an enterprise license to the MapWorks GIS mapping suite for internal use.",
        "2. TERM AND RENEWAL. The initial term is three (3) years, expiring December 31, 2028. The license automatically renews for successive one (1) year terms unless either party provides notice of non-renewal at least sixty (60) days before expiration.",
        "3. FEES. The annual contract value is $54,000.00 USD.",
        "4. PAYMENT TERMS. Invoices are payable Net 30.",
        "5. LIABILITY CAP. Licensor's aggregate liability shall not exceed the license fees paid during the twelve (12) months preceding the claim.",
        "6. ASSIGNMENT. Neither party may assign this Agreement without prior written consent, except to a successor in interest upon a change of control.",
        "7. GOVERNING LAW. This Agreement is governed by the laws of the State of New Jersey.") `
    -Closing "Executed on December 10, 2025." `
    -Signatures @("MapWorks GIS Corporation: Elena Sorokina, Chief Revenue Officer", "NJEDA: Kanchan Kora, Director of Analytics")

New-ContractDocx -FileName "Mutual NDA - Delaware River Logistics.docx" `
    -Title "MUTUAL NON-DISCLOSURE AGREEMENT" `
    -Intro "This Mutual Non-Disclosure Agreement is entered into effective as of October 1, 2026 (the ""Effective Date"") by and between Delaware River Logistics Corp (""DRL""), 7 Port Terminal Boulevard, Camden, NJ 08104, and New Jersey Economic Development Authority (""NJEDA""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. PURPOSE. The parties are evaluating a port-modernization financing program and may exchange Confidential Information.",
        "2. TERM. This Agreement expires September 30, 2028; it has a fixed two (2) year term and does not renew.",
        "3. CONFIDENTIALITY PERIOD. Confidentiality obligations survive for three (3) years from each disclosure.",
        "4. NDA TYPE. This is a mutual non-disclosure agreement.",
        "5. TERMINATION. Either party may terminate for convenience on thirty (30) days written notice.",
        "6. GOVERNING LAW AND VENUE. Governed by the laws of the State of New Jersey; venue in Camden County, New Jersey.") `
    -Closing "Executed on September 25, 2026." `
    -Signatures @("Delaware River Logistics Corp: Hector Alvarez, General Counsel", "NJEDA: Kanchan Kora, Authorized Signatory")

New-ContractDocx -FileName "Unilateral NDA - Beacon Capital Partners.docx" `
    -Title "NON-DISCLOSURE AGREEMENT (UNILATERAL)" `
    -Intro "This Non-Disclosure Agreement is entered into effective as of November 1, 2026 (the ""Effective Date"") by and between New Jersey Economic Development Authority (""Disclosing Party""), 36 West State Street, Trenton, NJ 08625, and Beacon Capital Partners LP (""Receiving Party""), 320 Park Avenue, New York, NY 10022." `
    -Clauses @(
        "1. PURPOSE. Disclosing Party will share non-public bond program data with Receiving Party for diligence purposes only.",
        "2. TERM. This Agreement expires October 31, 2027; the one (1) year term is fixed and does not renew.",
        "3. CONFIDENTIALITY PERIOD. Receiving Party's obligations survive for two (2) years from disclosure.",
        "4. NDA TYPE. This is a unilateral (one-way) non-disclosure agreement; only NJEDA discloses Confidential Information.",
        "5. GOVERNING LAW. Governed by the laws of the State of New York.") `
    -Closing "Executed on October 28, 2026." `
    -Signatures @("NJEDA: Kanchan Kora, Authorized Signatory", "Beacon Capital Partners LP: Sofia Marchetti, Partner")

New-ContractDocx -FileName "Marketing Services Agreement - Shoreline Creative.docx" `
    -Title "MARKETING SERVICES AGREEMENT" `
    -Intro "This Marketing Services Agreement is entered into and becomes effective as of December 15, 2026 (the ""Effective Date"") by and between Shoreline Creative Group LLC (""Agency""), 12 Ocean Avenue, Asbury Park, NJ 07712, and New Jersey Economic Development Authority (""Client""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. SERVICES. Agency shall provide campaign strategy, design, and digital advertising management for Client's small-business programs.",
        "2. TERM AND RENEWAL. The initial term runs from the Effective Date through December 14, 2027, and automatically renews for successive one (1) year terms unless either party gives notice of non-renewal at least forty-five (45) days before the end of the then-current term.",
        "3. FEES. The annual contract value is $48,000.00 USD, billed monthly.",
        "4. PAYMENT TERMS. Invoices are payable Net 30.",
        "5. TERMINATION. Client may terminate for convenience on thirty (30) days written notice.",
        "6. GOVERNING LAW. Governed by the laws of the State of New Jersey.") `
    -Closing "Executed on November 20, 2026." `
    -Signatures @("Shoreline Creative Group LLC: Jamie Park, Principal", "NJEDA: Kanchan Kora, Communications Director")

New-ContractDocx -FileName "Facilities Lease - Newark Innovation Hub.docx" `
    -Title "COMMERCIAL FACILITIES LEASE AGREEMENT" `
    -Intro "This Commercial Facilities Lease Agreement is entered into effective as of June 1, 2023 (the ""Effective Date"") by and between Newark Innovation Hub LLC (""Landlord""), 550 Broad Street, Newark, NJ 07102, and New Jersey Economic Development Authority (""Tenant""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. PREMISES. Landlord leases to Tenant approximately 6,000 rentable square feet of program space at 550 Broad Street, Newark, New Jersey.",
        "2. TERM. The lease term expires December 31, 2026.",
        "3. RENEWAL OPTION. Tenant may renew for one (1) additional three (3) year term by written notice no later than ninety (90) days before expiration of the initial term. The lease does not renew automatically.",
        "4. RENT AND VALUE. Base rent totals $420,000.00 USD over the initial term, payable monthly; payment terms are Net 10. A late payment fee of 5% applies to rent more than five days late.",
        "5. TERMINATION. Landlord may terminate for cause on thirty (30) days written notice of an uncured default.",
        "6. GOVERNING LAW AND VENUE. Governed by the laws of the State of New Jersey; venue in Essex County, New Jersey.") `
    -Closing "Executed on May 12, 2023." `
    -Signatures @("Newark Innovation Hub LLC: Andre Thompson, Managing Member", "NJEDA: Kanchan Kora, Authorized Signatory")

New-ContractDocx -FileName "Payroll Services Agreement - GardenState Payroll.docx" `
    -Title "PAYROLL PROCESSING SERVICES AGREEMENT" `
    -Intro "This Payroll Processing Services Agreement is entered into effective as of January 1, 2025 (the ""Effective Date"") by and between GardenState Payroll Solutions Inc. (""Processor""), 300 Carnegie Center, Princeton, NJ 08540, and New Jersey Economic Development Authority (""Client""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. SERVICES. Processor shall provide payroll processing, tax filing, and year-end reporting services.",
        "2. TERM. The term runs from the Effective Date through December 31, 2027; the three (3) year term is fixed and does not renew automatically.",
        "3. FEES. The annual contract value is $66,000.00 USD.",
        "4. PAYMENT TERMS. Invoices are payable Net 30.",
        "5. TERMINATION. Client may terminate for convenience on thirty (30) days written notice; either party may terminate for cause on fifteen (15) days notice and failure to cure.",
        "6. GOVERNING LAW. Governed by the laws of the State of New Jersey.") `
    -Closing "Executed on December 19, 2024." `
    -Signatures @("GardenState Payroll Solutions Inc.: Maria Villanueva, Account Executive", "NJEDA: Kanchan Kora, Finance Director")

New-ContractDocx -FileName "Staffing Agreement - Capital Temp Services.docx" `
    -Title "TEMPORARY STAFFING SERVICES AGREEMENT" `
    -Intro "This Temporary Staffing Services Agreement is entered into effective as of May 1, 2026 (the ""Effective Date"") by and between Capital Temp Services LLC (""Agency""), 25 State Route 33, Hamilton Township, NJ 08619, and New Jersey Economic Development Authority (""Client""), 36 West State Street, Trenton, NJ 08625." `
    -Clauses @(
        "1. SERVICES. Agency shall supply temporary administrative and program-support staff on request.",
        "2. TERM AND RENEWAL. The initial term runs from the Effective Date through April 30, 2027, and automatically renews for successive six (6) month terms unless either party gives notice of non-renewal at least thirty (30) days before the end of the then-current term.",
        "3. VALUE. Estimated total contract value is $250,000.00 USD based on forecast usage.",
        "4. PAYMENT TERMS. Invoices are payable Net 30. A late payment fee of 1% per month applies to overdue amounts.",
        "5. LIABILITY CAP. Agency's aggregate liability is capped at a fixed amount of $500,000.00 USD.",
        "6. TERMINATION. Client may terminate for convenience on fifteen (15) days written notice.",
        "7. GOVERNING LAW. Governed by the laws of the State of New Jersey.") `
    -Closing "Executed on April 14, 2026." `
    -Signatures @("Capital Temp Services LLC: Robert Chen, Branch Manager", "NJEDA: Kanchan Kora, Operations Manager")

"--- original batch (already uploaded 2026-11-26) ---"
Get-ChildItem $out -File | Select-Object Name, Length
"--- batch2 (upload these) ---"
Get-ChildItem $out2 -File | Select-Object Name, Length

