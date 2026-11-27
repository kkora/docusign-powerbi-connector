[Version = "1.3.0"]
section DocuSignPowerBI;

// DocuSign Integration Key for a public-client Authorization Code + PKCE application. Preserve this value.
ClientId = "226dd43b-4b8e-488a-9ba8-ac205c100833";

RedirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";
// Origin of RedirectUri. DocuSign's token endpoint requires an Origin header on
// the token exchange matching the redirect's origin when redirect_uri is a
// browser-loaded https:// page (as Power BI's OAuth catcher is) - without it,
// DocuSign rejects the exchange with invalid_grant/origin_required_but_not_included,
// regardless of the Integration Key's configured app type (Native vs SPA).
RedirectOrigin = "https://oauth.powerbi.com";
// adm_store_unified_repo_read is the Navigator (agreement repository) read scope backing the
// Agreements/Parties/CustomField tables. Existing stored credentials keep working for the
// envelope tables but lack this scope until the user clears and re-enters the data source
// credential (re-consent); only the Navigator-backed tables are affected either way.
Scope = "signature extended adm_store_unified_repo_read";

// Bounded retry tuning for HTTP 429 / 5xx responses.
MaxRetryAttempts = 3;
BaseRetryDelaySeconds = 1;
MaxRetryDelaySeconds = 10;

// ===== Row types (unchanged tables keep their exact original shape for backward compatibility) =====

EnvelopesRowType = type table [
    AccountId = nullable text, EnvelopeId = nullable text, EmailSubject = nullable text,
    Status = nullable text, CreatedDateTime = nullable datetime, SentDateTime = nullable datetime,
    CompletedDateTime = nullable datetime, VoidedDateTime = nullable datetime, LastModifiedDateTime = nullable datetime
];

// Extended for F04: adds AccountId, RecipientRole, SentDateTime, DeclinedDateTime, DeclineReason,
// AuthenticationMethod, CompletionHours alongside every original column. Additive only - existing
// columns keep their names/types, so existing reports referencing them are unaffected.
RecipientsRowType = type table [
    AccountId = nullable text, EnvelopeId = nullable text, RecipientId = nullable text, RecipientName = nullable text,
    RecipientEmail = nullable text, RecipientType = nullable text, RecipientRole = nullable text, RoutingOrder = nullable number,
    RecipientStatus = nullable text, SentDateTime = nullable datetime, SignedDateTime = nullable datetime, DeliveredDateTime = nullable datetime,
    DeclinedDateTime = nullable datetime, DeclineReason = nullable text, AuthenticationMethod = nullable text, CompletionHours = nullable number
];

CustomFieldsRowType = type table [
    AccountId = nullable text, EnvelopeId = nullable text, FieldName = nullable text, FieldValue = nullable text,
    FieldType = nullable text, Show = nullable logical, Required = nullable logical
];

// EventDateTime kept as datetimezone (not plain datetime) since this is a new table with no
// backward-compatibility constraint, and audit trails benefit from preserving the original offset
// rather than collapsing every signer's local time to a naive value (see F09).
AuditEventsRowType = type table [
    AccountId = nullable text, EnvelopeId = nullable text, EventDateTime = nullable datetimezone, EventType = nullable text,
    EventDescription = nullable text, UserName = nullable text, UserEmail = nullable text, IPAddress = nullable text,
    Action = nullable text, Result = nullable text
];

// NOTE: DocuSign's GET /templates response does not document a "status" field at all (confirmed
// against the current API reference). Status is still exposed per spec but will always be null
// against a real tenant unless DocuSign adds one - this is a documented limitation, not a bug.
TemplatesRowType = type table [
    AccountId = nullable text, TemplateId = nullable text, TemplateName = nullable text, Description = nullable text,
    CreatedDateTime = nullable datetime, LastModifiedDateTime = nullable datetime, OwnerName = nullable text,
    Shared = nullable logical, Status = nullable text
];

DocumentsRowType = type table [
    AccountId = nullable text, EnvelopeId = nullable text, DocumentId = nullable text, DocumentName = nullable text,
    DocumentType = nullable text, Order = nullable number, Pages = nullable number
];

AccountsRowType = type table [AccountId = nullable text, AccountName = nullable text, IsDefault = nullable logical, Environment = nullable text];

// Navigator (agreement repository) tables. Column names deliberately mirror DocuSign's official
// "PowerBI Agreements Report" template (PascalCase, Agreements keyed on Id) so its measures and
// visuals port with minimal renaming - see AGREEMENTS-REPORT-PLAN.md. The Is*In30days/90days
// flags are 0/1 numbers (not logicals) to match that template's Int64 flag columns.
AgreementsRowType = type table [
    AccountId = nullable text, Id = nullable text, Title = nullable text, FileName = nullable text,
    DocumentId = nullable text, AgreementType = nullable text, Category = nullable text,
    Status = nullable text, ReviewStatus = nullable text, Languages = nullable text,
    SourceName = nullable text, SourceId = nullable text, EnvelopeId = nullable text,
    CreatedDate = nullable datetime, ModifiedDate = nullable datetime,
    EffectiveDate = nullable datetime, ExpirationDate = nullable datetime, ExecutionDate = nullable datetime,
    TermLength = nullable text, TermLengthDays = nullable number,
    RenewalType = nullable text, IsAutoRenewal = nullable logical,
    RenewalTerm = nullable text, RenewalTermDays = nullable number,
    RenewalNoticePeriod = nullable text, RenewalNoticePeriodDays = nullable number,
    RenewalNoticeDate = nullable datetime, RenewalOwner = nullable text,
    TerminationForCauseNoticePeriod = nullable text, TerminationForCauseNoticePeriodDays = nullable number,
    TerminationForConvenienceNoticePeriod = nullable text, TerminationForConvenienceNoticePeriodDays = nullable number,
    TerminationNoticeDueDate = nullable datetime,
    PaymentTerms = nullable text, LatePaymentFee = nullable logical, LatePaymentFeePercent = nullable number,
    LiabilityCapDuration = nullable text, LiabilityCapDurationDays = nullable number,
    LiabilityCapFixedAmount = nullable number, LiabilityCapFixedAmountCurrency = nullable text,
    LiabilityCapMultiplier = nullable number, PriceCapIncreasePercent = nullable number,
    TotalValue = nullable number, TotalValueCurrency = nullable text,
    AnnualContractValue = nullable number, AnnualContractValueCurrency = nullable text,
    Assignment = nullable text, AssignmentChangeOfControl = nullable text, AssignmentTerminationRights = nullable text,
    GoverningLaw = nullable text, Jurisdiction = nullable text,
    NdaType = nullable text, ConfidentialityObligationPeriod = nullable text, ConfidentialityObligationPeriodDays = nullable number,
    IsActive = nullable number,
    IsActiveIn30days = nullable number, IsExpiringIn30days = nullable number, IsRenewingIn30days = nullable number, IsTakingEffectIn30days = nullable number,
    IsActiveIn90days = nullable number, IsExpiringIn90days = nullable number, IsRenewingIn90days = nullable number, IsTakingEffectIn90days = nullable number,
    EffectiveYearNumber = nullable number, ExpirationYearNumber = nullable number, ExecutionYearNumber = nullable number, RenewalNoticeYearNumber = nullable number,
    EffectiveMonthYear = nullable text, ExpirationMonthYear = nullable text
];

AgreementPartiesRowType = type table [
    AccountId = nullable text, AgreementId = nullable text, PartyId = nullable text, PartyName = nullable text
];

AgreementCustomFieldsRowType = type table [
    AccountId = nullable text, AgreementId = nullable text, FieldName = nullable text, FieldValue = nullable text
];

RecipientBuckets = {"signers", "agents", "editors", "intermediaries", "carbonCopies", "certifiedDeliveries", "inPersonSigners", "seals", "witnesses", "notaries"};

// ===== OAuth 2.0 Authorization Code with PKCE (S256) =====

shared DocuSignPowerBI.AuthHost = (environment as text) as text =>
    if environment = "Demo" then "https://account-d.docusign.com"
    else if environment = "Production" then "https://account.docusign.com"
    else error Error.Record("DocuSign.Config", "Unsupported environment '" & environment & "'. Use Demo or Production.", environment);

// DocuSign Navigator (agreement repository) API host - a different host than both the auth
// server and the per-account eSignature base_uri. Live-verified against Demo on 2026-11-26;
// Production is implemented per DocuSign's documented host pattern but untested (same caveat
// as the eSignature Production path).
shared DocuSignPowerBI.NavigatorApiBase = (environment as text) as text =>
    if environment = "Demo" then "https://api-d.docusign.com"
    else if environment = "Production" then "https://api.docusign.com"
    else error Error.Record("DocuSign.Config", "Unsupported environment '" & environment & "'. Use Demo or Production.", environment);

// Function-based data sources only pass the required-parameter value(s) back as
// an opaque dataSourcePath; there is no documented API to deserialize it into a
// record. This performs a defensive substring match and falls back to Demo.
// Only the Demo path (account-d.docusign.com) has been exercised end-to-end;
// Production is implemented identically but UNTESTED against a live tenant
// (see README "Known limitations").
shared DocuSignPowerBI.EnvironmentFromPath = (dataSourcePath as any) as text =>
    let
        asText = try Text.From(dataSourcePath) otherwise "",
        resolved = if Text.Contains(asText, "Production") then "Production" else "Demo"
    in resolved;

shared DocuSignPowerBI.Base64Url = (bytes as binary) as text =>
    Text.Replace(Text.Replace(Text.TrimEnd(Binary.ToText(bytes, BinaryEncoding.Base64), "="), "+", "-"), "/", "_");

// Two GUIDs with dashes removed = 64 hex characters: within RFC 7636's 43-128
// length bound and unreserved [A-Za-z0-9-._~] charset.
shared DocuSignPowerBI.NewVerifier = () as text =>
    Text.Replace(Text.NewGuid(), "-", "") & Text.Replace(Text.NewGuid(), "-", "");

shared DocuSignPowerBI.Challenge = (verifier as text) as text =>
    DocuSignPowerBI.Base64Url(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(verifier, TextEncoding.Ascii)));

shared DocuSignPowerBI.StartLogin = (dataSourcePath, state, display) =>
    let
        environment = DocuSignPowerBI.EnvironmentFromPath(dataSourcePath),
        verifier = DocuSignPowerBI.NewVerifier(),
        challenge = DocuSignPowerBI.Challenge(verifier),
        url = DocuSignPowerBI.AuthHost(environment) & "/oauth/auth?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = ClientId,
            redirect_uri = RedirectUri,
            scope = Scope,
            state = state,
            code_challenge = challenge,
            code_challenge_method = "S256"
        ])
    in [
        LoginUri = url,
        CallbackUri = RedirectUri,
        WindowHeight = 720,
        WindowWidth = 1024,
        Context = [verifier = verifier, environment = environment]
    ];

shared DocuSignPowerBI.FinishLogin = (context, callbackUri, state) =>
    let
        query = Uri.Parts(callbackUri)[Query],
        result =
            if Record.HasFields(query, "error") then
                error Error.Record("DocuSign.OAuth", "DocuSign returned an OAuth error: " & Text.From(Record.FieldOrDefault(query, "error_description", query[error])), query)
            else if Record.FieldOrDefault(query, "state", "") <> state then
                error Error.Record("DocuSign.OAuth", "OAuth state mismatch: the login response did not match the request that initiated it.", null)
            else if not Record.HasFields(query, "code") then
                error Error.Record("DocuSign.OAuth", "DocuSign did not return an authorization code.", query)
            else
                TokenRequest(context[environment], [
                    grant_type = "authorization_code",
                    code = query[code],
                    code_verifier = context[verifier],
                    redirect_uri = RedirectUri
                ])
    in result;

shared DocuSignPowerBI.Refresh = (dataSourcePath, refreshToken) =>
    TokenRequest(DocuSignPowerBI.EnvironmentFromPath(dataSourcePath), [grant_type = "refresh_token", refresh_token = refreshToken]);

TokenRequest = (environment as text, fields as record) as record =>
    let
        response = Web.Contents(DocuSignPowerBI.AuthHost(environment), [
            RelativePath = "oauth/token",
            Content = Text.ToBinary(Uri.BuildQueryString(Record.Combine({fields, [client_id = ClientId]}))),
            Headers = [#"Content-Type" = "application/x-www-form-urlencoded", Accept = "application/json", Origin = RedirectOrigin],
            ManualStatusHandling = {400, 401}
        ]),
        result = DocuSignPowerBI.SafeJsonDocument(response),
        checked =
            if Record.HasFields(result, "error") then
                error Error.Record("DocuSign.OAuth", "DocuSign token endpoint returned an error: " & Text.From(Record.FieldOrDefault(result, "error", "")) & " - " & Text.From(Record.FieldOrDefault(result, "error_description", "")), result)
            else result
    in checked;

// ===== Data Source declaration =====

DocuSignPowerBI = [
    TestConnection = (dataSourcePath) => {"DocuSignPowerBI.Contents", "Demo"},
    Authentication = [
        OAuth = [
            StartLogin = DocuSignPowerBI.StartLogin,
            FinishLogin = DocuSignPowerBI.FinishLogin,
            Refresh = DocuSignPowerBI.Refresh
        ]
    ],
    Label = "DocuSign eSignature"
];

DocuSignPowerBI.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://developers.docusign.com/docs/esign-rest-api/",
    SourceImage = DocuSignPowerBI.Icons,
    SourceTypeImage = DocuSignPowerBI.Icons
];

DocuSignPowerBI.Icons = [
    Icon16 = { Extension.Contents("DocuSignPowerBI16.png"), Extension.Contents("DocuSignPowerBI20.png"), Extension.Contents("DocuSignPowerBI24.png"), Extension.Contents("DocuSignPowerBI32.png") },
    Icon32 = { Extension.Contents("DocuSignPowerBI32.png"), Extension.Contents("DocuSignPowerBI40.png"), Extension.Contents("DocuSignPowerBI48.png"), Extension.Contents("DocuSignPowerBI64.png") }
];

// ===== Main entry point =====
//
// accountId is `optional`, so it does not factor into the Data Source Path (only required
// parameters do) - the connection identity stays `{"environment": ...}` regardless of which
// account a report requests, which is what keeps credentials/gateway config stable across
// different reports (F05/F10).
// Ascribed function type: gives the Get Data dialog a dropdown for environment
// (defaulting to the first listed value, Demo) instead of a free-text box, which
// is what let "demo"/lowercase typos slip through repeatedly during live testing.
DocuSignPowerBIType = type function (
    environment as (type text meta [
        Documentation.FieldCaption = "Environment",
        Documentation.FieldDescription = "DocuSign environment to connect to.",
        Documentation.AllowedValues = {"Demo", "Production"}
    ]),
    optional accountId as (type nullable text meta [
        Documentation.FieldCaption = "Account ID",
        Documentation.FieldDescription = "Explicit DocuSign account id, if you have access to more than one (see the Accounts table). Defaults to your default account if left blank.",
        Documentation.SampleValues = {"12345678-1234-1234-1234-123456789abc"}
    ])
) as table meta [
    Documentation.Name = "DocuSign eSignature",
    Documentation.LongDescription = "Connects to DocuSign eSignature (Envelopes, Recipients, Envelope Status, Envelope Custom Fields, Envelope Audit Events, Templates, Envelope Documents, Accounts) and DocuSign Navigator (Agreements, Parties, CustomField)."
];

[DataSource.Kind = "DocuSignPowerBI", Publish = "DocuSignPowerBI.Publish"]
shared DocuSignPowerBI.Contents = Value.ReplaceType(
    (environment as text, optional accountId as nullable text) as table =>
        DocuSignPowerBIImpl(environment, null, null, accountId),
    DocuSignPowerBIType);

// Unpublished variant that keeps the fromDate/toDate knobs. No Publish attribute, so it never
// appears in Get Data, but it carries the same DataSource.Kind (same credentials, and since the
// dates are optional the Data Source Path is still just `{"environment": ...}`). The integration
// test suite depends on it: the recorded HTTP mocks are keyed on the from_date query parameter,
// so tests steer fixture selection by passing explicit dates.
[DataSource.Kind = "DocuSignPowerBI"]
shared DocuSignPowerBI.ContentsWithDates = DocuSignPowerBIImpl;

DocuSignPowerBIImpl = (environment as text, optional fromDate as nullable text, optional toDate as nullable text, optional accountId as nullable text) as table =>
    let
        _validEnvironment =
            if environment <> "Demo" and environment <> "Production" then
                error Error.Record("DocuSign.Config", "Unsupported environment '" & environment & "'. Use Demo or Production.", environment)
            else environment,
        _fromDate = DocuSignPowerBI.ResolveFromDate(fromDate),
        _toDate = DocuSignPowerBI.ResolveToDate(toDate),
        _dateRangeChecked =
            if _toDate <> null and Date.FromText(_fromDate) > Date.FromText(_toDate) then
                error Error.Record("DocuSign.Config", "fromDate must not be after toDate.", [FromDate = _fromDate, ToDate = _toDate])
            else true,
        token = Extension.CurrentCredential()[access_token],
        userInfo = DocuSignPowerBI.GetUserInfo(_validEnvironment, token),
        accounts = Record.FieldOrDefault(userInfo, "accounts", {}),
        _accountsChecked = if List.IsEmpty(accounts) then error Error.Record("DocuSign.Account", "The authenticated DocuSign user has no accessible accounts.", null) else accounts,
        _requestedAccountId = if accountId = null or Text.Trim(accountId) = "" then null else accountId,
        _matchedAccounts = if _requestedAccountId = null then {} else List.Select(_accountsChecked, each Text.From(Record.FieldOrDefault(_, "account_id", "")) = _requestedAccountId),
        _accountSelectionChecked =
            if _requestedAccountId <> null and List.IsEmpty(_matchedAccounts) then
                error Error.Record("DocuSign.Account", "The requested accountId '" & _requestedAccountId & "' is not accessible to the authenticated user.", _requestedAccountId)
            else true,
        account =
            if _accountSelectionChecked and _requestedAccountId <> null then _matchedAccounts{0}
            else List.First(List.Select(_accountsChecked, each Record.FieldOrDefault(_, "is_default", false) = true), _accountsChecked{0}),
        resolvedAccountId = Record.FieldOrDefault(account, "account_id", null),
        apiBase = Text.TrimEnd(Record.FieldOrDefault(account, "base_uri", ""), "/"),
        rawEnvelopes = if _dateRangeChecked then DocuSignPowerBI.GetEnvelopesRaw(apiBase, resolvedAccountId, token, _fromDate, _toDate) else error Error.Record("DocuSign.Config", "Unreachable.", null),
        // Table.Buffer: envelopesTable feeds five separate downstream builders below: materialize it
        // once rather than risk the engine re-walking the fetch/parse chain per consumer (F08).
        envelopesTable = Table.Buffer(Table.Distinct(DocuSignPowerBI.BuildEnvelopesTable(rawEnvelopes, resolvedAccountId), {"EnvelopeId"})),
        recipientsTable = DocuSignPowerBI.BuildRecipientsTable(apiBase, resolvedAccountId, token, envelopesTable),
        statusTable = DocuSignPowerBI.BuildStatusTable(envelopesTable),
        customFieldsTable = DocuSignPowerBI.BuildCustomFieldsTable(apiBase, resolvedAccountId, token, envelopesTable),
        auditEventsTable = DocuSignPowerBI.BuildAuditEventsTable(apiBase, resolvedAccountId, token, envelopesTable),
        rawTemplates = DocuSignPowerBI.GetTemplatesRaw(apiBase, resolvedAccountId, token),
        templatesTable = DocuSignPowerBI.BuildTemplatesTable(rawTemplates, resolvedAccountId),
        documentsTable = DocuSignPowerBI.BuildDocumentsTable(apiBase, resolvedAccountId, token, envelopesTable),
        accountsTable = DocuSignPowerBI.BuildAccountsTable(_accountsChecked, _validEnvironment),
        // One Navigator fetch feeds all three agreement tables. These bindings are only forced
        // when one of the agreement tables is actually expanded, so accounts without Navigator
        // provisioned (403: EnableNavigatorAPIDataOut) can still load every envelope table.
        rawAgreements = DocuSignPowerBI.GetAgreementsRaw(DocuSignPowerBI.NavigatorApiBase(_validEnvironment), resolvedAccountId, token),
        agreementsTable = DocuSignPowerBI.BuildAgreementsTable(rawAgreements, resolvedAccountId),
        agreementPartiesTable = DocuSignPowerBI.BuildAgreementPartiesTable(rawAgreements, resolvedAccountId),
        agreementCustomFieldsTable = DocuSignPowerBI.BuildAgreementCustomFieldsTable(rawAgreements, resolvedAccountId),
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Envelopes", "Envelopes", envelopesTable, "Table", "Table", true},
                {"Recipients", "Recipients", recipientsTable, "Table", "Table", true},
                {"Envelope Status", "Envelope Status", statusTable, "Table", "Table", true},
                {"Envelope Custom Fields", "Envelope Custom Fields", customFieldsTable, "Table", "Table", true},
                {"Envelope Audit Events", "Envelope Audit Events", auditEventsTable, "Table", "Table", true},
                {"Templates", "Templates", templatesTable, "Table", "Table", true},
                {"Envelope Documents", "Envelope Documents", documentsTable, "Table", "Table", true},
                {"Agreements", "Agreements", agreementsTable, "Table", "Table", true},
                {"Parties", "Parties", agreementPartiesTable, "Table", "Table", true},
                {"CustomField", "CustomField", agreementCustomFieldsTable, "Table", "Table", true},
                {"Accounts", "Accounts", accountsTable, "Table", "Table", true}
            }
        ),
        nav = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in nav;

shared DocuSignPowerBI.ResolveFromDate = (fromDate as nullable text) as text =>
    let
        defaulted = if fromDate = null or Text.Trim(fromDate) = "" then Date.ToText(Date.AddDays(DateTime.Date(DateTime.LocalNow()), -30), "yyyy-MM-dd") else fromDate,
        validated = if (try Date.FromText(defaulted) otherwise null) = null then error Error.Record("DocuSign.Config", "fromDate must be in YYYY-MM-DD format.", defaulted) else defaulted
    in validated;

// toDate has no default: null means "no upper bound", which DocuSign's envelopes endpoint
// interprets as "through now" when to_date is simply omitted from the request.
shared DocuSignPowerBI.ResolveToDate = (toDate as nullable text) as nullable text =>
    if toDate = null or Text.Trim(toDate) = "" then null
    else if (try Date.FromText(toDate) otherwise null) = null then error Error.Record("DocuSign.Config", "toDate must be in YYYY-MM-DD format.", toDate)
    else toDate;

// ===== HTTP plumbing: null-safe JSON, 401 (engine-refresh), 403, 429/5xx bounded retry =====

shared DocuSignPowerBI.SafeJsonDocument = (response as binary) as any =>
    try Json.Document(response) otherwise
        let
            length = Binary.Length(response),
            previewLength = List.Min({length, 300}),
            hexPreview = try Binary.ToText(Binary.Range(response, 0, previewLength), BinaryEncoding.Hex) otherwise "<could not hex-encode>",
            textPreview = try Text.FromBinary(response) otherwise "<not valid text in default encoding>"
        in error Error.Record("DocuSign.InvalidResponse", "DocuSign returned a response that could not be parsed as JSON. Length=" & Text.From(length) & " HexPreview=" & hexPreview, [Length = length, HexPreview = hexPreview, TextPreview = textPreview]);

shared DocuSignPowerBI.SafeInt = (value as any) as number =>
    if value = null then 0
    else
        let parsed = try Number.FromText(Text.From(value)) otherwise null
        in if parsed = null then 0 else Number.RoundDown(parsed);

shared DocuSignPowerBI.SafeNumber = (value as any) as nullable number =>
    if value = null then null else try Number.FromText(Text.From(value)) otherwise null;

// DocuSign returns several booleans (show/required/shared) as either a literal JSON boolean or a
// "true"/"false" string depending on endpoint; handle both without erroring on either.
shared DocuSignPowerBI.SafeBool = (value as any) as nullable logical =>
    if value = null then null
    else if value = true or value = false then value
    else
        let t = try Text.Lower(Text.From(value)) otherwise null
        in if t = "true" then true else if t = "false" then false else null;

shared DocuSignPowerBI.ToDateTime = (value as any) as nullable datetime =>
    if value = null then null
    else
        let
            text = try Text.From(value) otherwise null,
            parsed =
                if text = null or Text.Trim(text) = "" then null
                else
                    let zoned = try DateTimeZone.FromText(text) otherwise null
                    in if zoned <> null then DateTimeZone.RemoveZone(zoned) else (try DateTime.FromText(text) otherwise null)
        in parsed;

// Zone-preserving counterpart to ToDateTime, used only by new tables (Audit Events) where there is
// no pre-existing naive-datetime column to stay compatible with (F09).
shared DocuSignPowerBI.ToDateTimeZone = (value as any) as nullable datetimezone =>
    if value = null then null
    else
        let
            text = try Text.From(value) otherwise null,
            parsed = if text = null or Text.Trim(text) = "" then null else (try DateTimeZone.FromText(text) otherwise null)
        in parsed;

shared DocuSignPowerBI.StatusEquals = (status as nullable text, target as text) as logical =>
    status <> null and Text.Lower(status) = target;

// 401 is intentionally left out of ManualStatusHandling: the Power Query OAuth
// engine recognizes an unhandled 401, calls Refresh, and transparently retries
// the request once. Handling it manually here would bypass that built-in flow.
shared DocuSignPowerBI.HttpGetWithRetry = (base as text, path as text, token as text, query as nullable record, attempt as number) as any =>
    let
        response = Web.Contents(base, [
            RelativePath = path,
            Query = if query = null then [] else query,
            Headers = [Authorization = "Bearer " & token, Accept = "application/json"],
            ManualStatusHandling = {403, 429, 500, 502, 503, 504},
            ManualCredentials = true
        ]),
        metadata = Value.Metadata(response),
        status = metadata[Response.Status]?,
        result =
            if status = null or status = 200 or status = 201 then
                DocuSignPowerBI.SafeJsonDocument(response)
            else if status = 403 then
                error Error.Record("DocuSign.Forbidden", "DocuSign denied access (HTTP 403). Verify the OAuth scopes (signature extended adm_store_unified_repo_read) and the account's API permissions. For the Agreements/Parties/CustomField tables the account additionally needs DocuSign Navigator provisioned (plan item EnableNavigatorAPIDataOut), and a credential saved before this connector version must be cleared and re-entered to pick up the Navigator scope.", status)
            else if (status = 429 or status >= 500) and attempt < MaxRetryAttempts then
                let
                    headers = metadata[Headers]?,
                    retryAfterRaw = if headers = null then null else Record.FieldOrDefault(headers, "Retry-After", null),
                    retryAfterSeconds = if retryAfterRaw = null then null else (try Number.FromText(Text.From(retryAfterRaw)) otherwise null),
                    baseDelay = if retryAfterSeconds = null then BaseRetryDelaySeconds else List.Max({retryAfterSeconds, BaseRetryDelaySeconds}),
                    waitSeconds = List.Min({baseDelay * Number.Power(2, attempt), MaxRetryDelaySeconds})
                in Function.InvokeAfter(() => DocuSignPowerBI.HttpGetWithRetry(base, path, token, query, attempt + 1), #duration(0, 0, 0, waitSeconds))
            else
                error Error.Record("DocuSign.HttpError", "DocuSign API request failed with HTTP " & Text.From(status) & " after " & Text.From(attempt) & " retry attempt(s).", [Status = status, Path = path])
    in result;

shared DocuSignPowerBI.GetUserInfo = (environment as text, token as text) as record =>
    DocuSignPowerBI.HttpGetWithRetry(DocuSignPowerBI.AuthHost(environment), "oauth/userinfo", token, null, 0);

// ===== Envelopes: pagination via resultSetSize/totalSetSize/endPosition, optional to_date (F02) =====

shared DocuSignPowerBI.GetEnvelopesRaw = (base as text, accountId as text, token as text, fromDate as text, optional toDate as nullable text) as list =>
    let
        path = "restapi/v2.1/accounts/" & accountId & "/envelopes",
        pageSize = 100,
        FetchPage = (startPosition as number) as record =>
            let
                baseQuery = [from_date = fromDate, start_position = Text.From(startPosition), count = Text.From(pageSize)],
                fullQuery = if toDate <> null then Record.Combine({baseQuery, [to_date = toDate]}) else baseQuery
            in DocuSignPowerBI.HttpGetWithRetry(base, path, token, fullQuery, 0),
        pages = List.Generate(
            () => [response = FetchPage(0), hasMore = true],
            each [hasMore],
            each
                let
                    resultSetSize = DocuSignPowerBI.SafeInt(Record.FieldOrDefault([response], "resultSetSize", 0)),
                    totalSetSize = DocuSignPowerBI.SafeInt(Record.FieldOrDefault([response], "totalSetSize", 0)),
                    endPosition = DocuSignPowerBI.SafeInt(Record.FieldOrDefault([response], "endPosition", -1)),
                    more = resultSetSize > 0 and (endPosition + 1) < totalSetSize
                in [
                    response = if more then FetchPage(endPosition + 1) else [envelopes = {}],
                    hasMore = more
                ],
            each Record.FieldOrDefault([response], "envelopes", {})
        )
    in List.Combine(pages);

shared DocuSignPowerBI.BuildEnvelopesTable = (rawEnvelopes as list, accountId as nullable text) as table =>
    let
        records = List.Transform(rawEnvelopes, (e) =>
            [
                AccountId = accountId,
                EnvelopeId = Record.FieldOrDefault(e, "envelopeId", null),
                EmailSubject = Record.FieldOrDefault(e, "emailSubject", null),
                Status = Record.FieldOrDefault(e, "status", null),
                CreatedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(e, "createdDateTime", null)),
                SentDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(e, "sentDateTime", null)),
                CompletedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(e, "completedDateTime", null)),
                VoidedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(e, "voidedDateTime", null)),
                LastModifiedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(e, "lastModifiedDateTime", null))
            ])
    in
        Table.FromRecords(records, EnvelopesRowType, MissingField.UseNull);

// ===== Recipients: fan out per envelope, flatten every DocuSign recipient bucket (extended for F04) =====

// Pure transform: flattens one envelope's raw /recipients JSON record (as returned by DocuSign)
// across every recipient bucket into a flat row list. No I/O, so this is directly unit-testable
// with hand-built fixture records. `accountId` is optional to preserve the original 2-argument
// call shape used by earlier tests and callers.
shared DocuSignPowerBI.FlattenRecipients = (raw as record, envelopeId as text, optional accountId as nullable text) as list =>
    List.Combine(List.Transform(RecipientBuckets, (bucket) =>
        List.Transform(Record.FieldOrDefault(raw, bucket, {}), (person) =>
            let
                sentDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(person, "sentDateTime", null)),
                signedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(person, "signedDateTime", null))
            in [
                AccountId = accountId,
                EnvelopeId = envelopeId,
                RecipientId = Record.FieldOrDefault(person, "recipientId", null),
                RecipientName = Record.FieldOrDefault(person, "name", null),
                RecipientEmail = Record.FieldOrDefault(person, "email", null),
                RecipientType = bucket,
                RecipientRole = Record.FieldOrDefault(person, "roleName", null),
                RoutingOrder = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(person, "routingOrder", null)),
                RecipientStatus = Record.FieldOrDefault(person, "status", null),
                SentDateTime = sentDateTime,
                SignedDateTime = signedDateTime,
                DeliveredDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(person, "deliveredDateTime", null)),
                DeclinedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(person, "declinedDateTime", null)),
                DeclineReason = Record.FieldOrDefault(person, "declineReason", null),
                AuthenticationMethod = Record.FieldOrDefault(person, "authenticationMethod", null),
                CompletionHours =
                    if sentDateTime <> null and signedDateTime <> null and signedDateTime >= sentDateTime
                    then Duration.TotalHours(signedDateTime - sentDateTime)
                    else null
            ])));

shared DocuSignPowerBI.BuildRecipientsTable = (base as text, accountId as text, token as text, envelopes as table) as table =>
    let
        ids = if Table.HasColumns(envelopes, "EnvelopeId") then List.RemoveNulls(Table.Column(envelopes, "EnvelopeId")) else {},
        rows = List.Combine(List.Transform(ids, (envelopeId) =>
            let
                raw = DocuSignPowerBI.HttpGetWithRetry(base, "restapi/v2.1/accounts/" & accountId & "/envelopes/" & envelopeId & "/recipients", token, null, 0)
            in DocuSignPowerBI.FlattenRecipients(raw, envelopeId, accountId)))
    in
        Table.FromRecords(rows, RecipientsRowType, MissingField.UseNull);

// ===== Envelope Status: current-status snapshot derived from Envelopes, no extra calls =====

shared DocuSignPowerBI.BuildStatusTable = (envelopes as table) as table =>
    let
        base = Table.SelectColumns(envelopes, {"EnvelopeId", "Status", "SentDateTime", "CompletedDateTime"}, MissingField.UseNull),
        withCompleted = Table.AddColumn(base, "IsCompleted", each DocuSignPowerBI.StatusEquals([Status], "completed"), type logical),
        withDeclined = Table.AddColumn(withCompleted, "IsDeclined", each DocuSignPowerBI.StatusEquals([Status], "declined"), type logical),
        withVoided = Table.AddColumn(withDeclined, "IsVoided", each DocuSignPowerBI.StatusEquals([Status], "voided"), type logical),
        withPending = Table.AddColumn(withVoided, "IsPending", each not ([IsCompleted] or [IsDeclined] or [IsVoided]), type logical),
        withHours = Table.AddColumn(withPending, "CompletionHours", each
            if [SentDateTime] <> null and [CompletedDateTime] <> null and [CompletedDateTime] >= [SentDateTime]
            then Duration.TotalHours([CompletedDateTime] - [SentDateTime])
            else null, type nullable number),
        result = Table.SelectColumns(withHours, {"EnvelopeId", "Status", "IsCompleted", "IsPending", "IsDeclined", "IsVoided", "SentDateTime", "CompletedDateTime", "CompletionHours"})
    in result;

// ===== Envelope Custom Fields (F01) =====

// Pure transform: flattens one envelope's raw /custom_fields JSON record into a flat row list.
shared DocuSignPowerBI.FlattenCustomFields = (raw as record, accountId as nullable text, envelopeId as text) as list =>
    let
        textFields = List.Transform(Record.FieldOrDefault(raw, "textCustomFields", {}), (f) =>
            [
                AccountId = accountId, EnvelopeId = envelopeId,
                FieldName = Record.FieldOrDefault(f, "name", null),
                FieldValue = Record.FieldOrDefault(f, "value", null),
                FieldType = "text",
                Show = DocuSignPowerBI.SafeBool(Record.FieldOrDefault(f, "show", null)),
                Required = DocuSignPowerBI.SafeBool(Record.FieldOrDefault(f, "required", null))
            ]),
        listFields = List.Transform(Record.FieldOrDefault(raw, "listCustomFields", {}), (f) =>
            [
                AccountId = accountId, EnvelopeId = envelopeId,
                FieldName = Record.FieldOrDefault(f, "name", null),
                FieldValue = Record.FieldOrDefault(f, "value", null),
                FieldType = "list",
                Show = DocuSignPowerBI.SafeBool(Record.FieldOrDefault(f, "show", null)),
                Required = DocuSignPowerBI.SafeBool(Record.FieldOrDefault(f, "required", null))
            ])
    in textFields & listFields;

shared DocuSignPowerBI.BuildCustomFieldsTable = (base as text, accountId as text, token as text, envelopes as table) as table =>
    let
        ids = if Table.HasColumns(envelopes, "EnvelopeId") then List.RemoveNulls(Table.Column(envelopes, "EnvelopeId")) else {},
        rows = List.Combine(List.Transform(ids, (envelopeId) =>
            let
                raw = DocuSignPowerBI.HttpGetWithRetry(base, "restapi/v2.1/accounts/" & accountId & "/envelopes/" & envelopeId & "/custom_fields", token, null, 0)
            in DocuSignPowerBI.FlattenCustomFields(raw, accountId, envelopeId))),
        asTable = Table.FromRecords(rows, CustomFieldsRowType, MissingField.UseNull)
    in
        Table.Distinct(asTable, {"EnvelopeId", "FieldName"});

// ===== Envelope Audit Events (F03) =====
//
// DocuSign's audit_events response has no fixed per-event schema: each event is a generic
// {name, value} list ("eventFields"), and the actual name keys vary by event type / API version
// (confirmed values from DocuSign's own developer blog include "UserName", "logTime", "Action";
// others like IP address / description are not consistently documented). GetEventField below tries
// several plausible aliases in priority order and falls back to null rather than guessing wrong -
// this is a known area that needs validation against a live tenant (see README).
shared DocuSignPowerBI.GetEventField = (fields as list, candidates as list) as nullable text =>
    let
        tryOne = (name as text) as nullable text =>
            let matches = List.Select(fields, each Record.FieldOrDefault(_, "name", null) = name)
            in if List.IsEmpty(matches) then null else (let v = Record.FieldOrDefault(matches{0}, "value", null) in if v = null then null else Text.From(v)),
        found = List.Select(List.Transform(candidates, each tryOne(_)), each _ <> null)
    in if List.IsEmpty(found) then null else found{0};

shared DocuSignPowerBI.FlattenAuditEvents = (raw as record, accountId as nullable text, envelopeId as text) as list =>
    List.Transform(Record.FieldOrDefault(raw, "auditEvents", {}), (e) =>
        let fields = Record.FieldOrDefault(e, "eventFields", {})
        in [
            AccountId = accountId,
            EnvelopeId = envelopeId,
            EventDateTime = DocuSignPowerBI.ToDateTimeZone(DocuSignPowerBI.GetEventField(fields, {"EventDateTime", "logTime", "Date"})),
            EventType = DocuSignPowerBI.GetEventField(fields, {"EventType", "Action", "EventName"}),
            EventDescription = DocuSignPowerBI.GetEventField(fields, {"EventDescription", "Description"}),
            UserName = DocuSignPowerBI.GetEventField(fields, {"UserName", "User Name", "Full Name"}),
            UserEmail = DocuSignPowerBI.GetEventField(fields, {"Email", "UserEmail", "Email Address"}),
            IPAddress = DocuSignPowerBI.GetEventField(fields, {"IP Address", "IPAddress", "ip"}),
            Action = DocuSignPowerBI.GetEventField(fields, {"Action", "EventType"}),
            Result = DocuSignPowerBI.GetEventField(fields, {"Result", "Status"})
        ]);

shared DocuSignPowerBI.BuildAuditEventsTable = (base as text, accountId as text, token as text, envelopes as table) as table =>
    let
        ids = if Table.HasColumns(envelopes, "EnvelopeId") then List.RemoveNulls(Table.Column(envelopes, "EnvelopeId")) else {},
        rows = List.Combine(List.Transform(ids, (envelopeId) =>
            let
                raw = DocuSignPowerBI.HttpGetWithRetry(base, "restapi/v2.1/accounts/" & accountId & "/envelopes/" & envelopeId & "/audit_events", token, null, 0)
            in DocuSignPowerBI.FlattenAuditEvents(raw, accountId, envelopeId))),
        asTable = Table.FromRecords(rows, AuditEventsRowType, MissingField.UseNull)
    in
        Table.Distinct(asTable);

// ===== Templates (F06) =====
//
// DocuSign's templates list response uses the same resultSetSize/totalSetSize/endPosition
// pagination shape as envelopes, but the array field is "envelopeTemplates" and the created-date
// field is "created" (not "createdDateTime" like envelopes) - both confirmed against the current
// API reference. "status" is not part of this endpoint's schema at all (see TemplatesRowType note).
shared DocuSignPowerBI.GetTemplatesRaw = (base as text, accountId as text, token as text) as list =>
    let
        path = "restapi/v2.1/accounts/" & accountId & "/templates",
        pageSize = 100,
        FetchPage = (startPosition as number) as record =>
            DocuSignPowerBI.HttpGetWithRetry(base, path, token, [start_position = Text.From(startPosition), count = Text.From(pageSize)], 0),
        pages = List.Generate(
            () => [response = FetchPage(0), hasMore = true],
            each [hasMore],
            each
                let
                    resultSetSize = DocuSignPowerBI.SafeInt(Record.FieldOrDefault([response], "resultSetSize", 0)),
                    totalSetSize = DocuSignPowerBI.SafeInt(Record.FieldOrDefault([response], "totalSetSize", 0)),
                    endPosition = DocuSignPowerBI.SafeInt(Record.FieldOrDefault([response], "endPosition", -1)),
                    more = resultSetSize > 0 and (endPosition + 1) < totalSetSize
                in [
                    response = if more then FetchPage(endPosition + 1) else [envelopeTemplates = {}],
                    hasMore = more
                ],
            each Record.FieldOrDefault([response], "envelopeTemplates", {})
        )
    in List.Combine(pages);

shared DocuSignPowerBI.BuildTemplatesTable = (rawTemplates as list, accountId as nullable text) as table =>
    let
        records = List.Transform(rawTemplates, (t) =>
            let owner = Record.FieldOrDefault(t, "owner", null)
            in [
                AccountId = accountId,
                TemplateId = Record.FieldOrDefault(t, "templateId", null),
                TemplateName = Record.FieldOrDefault(t, "name", null),
                Description = Record.FieldOrDefault(t, "description", null),
                CreatedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(t, "created", Record.FieldOrDefault(t, "createdDateTime", null))),
                LastModifiedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(t, "lastModifiedDateTime", null)),
                OwnerName = if owner = null then null else Record.FieldOrDefault(owner, "userName", null),
                Shared = DocuSignPowerBI.SafeBool(Record.FieldOrDefault(t, "shared", null)),
                Status = Record.FieldOrDefault(t, "status", null)
            ])
    in
        Table.FromRecords(records, TemplatesRowType, MissingField.UseNull);

// ===== Envelope Documents (F07) - metadata only, no binary content ever requested =====

shared DocuSignPowerBI.FlattenDocuments = (raw as record, accountId as nullable text, envelopeId as text) as list =>
    List.Transform(Record.FieldOrDefault(raw, "envelopeDocuments", {}), (d) =>
        [
            AccountId = accountId,
            EnvelopeId = envelopeId,
            DocumentId = Record.FieldOrDefault(d, "documentId", null),
            DocumentName = Record.FieldOrDefault(d, "name", null),
            DocumentType = Record.FieldOrDefault(d, "type", null),
            Order = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(d, "order", null)),
            Pages = List.Count(Record.FieldOrDefault(d, "pages", {}))
        ]);

shared DocuSignPowerBI.BuildDocumentsTable = (base as text, accountId as text, token as text, envelopes as table) as table =>
    let
        ids = if Table.HasColumns(envelopes, "EnvelopeId") then List.RemoveNulls(Table.Column(envelopes, "EnvelopeId")) else {},
        rows = List.Combine(List.Transform(ids, (envelopeId) =>
            let
                raw = DocuSignPowerBI.HttpGetWithRetry(base, "restapi/v2.1/accounts/" & accountId & "/envelopes/" & envelopeId & "/documents", token, null, 0)
            in DocuSignPowerBI.FlattenDocuments(raw, accountId, envelopeId)))
    in
        Table.FromRecords(rows, DocumentsRowType, MissingField.UseNull);

// ===== Accounts (F05) - no extra API call, derived from the already-fetched /oauth/userinfo accounts list =====

shared DocuSignPowerBI.BuildAccountsTable = (accounts as list, environment as text) as table =>
    let
        records = List.Transform(accounts, (a) =>
            [
                AccountId = Record.FieldOrDefault(a, "account_id", null),
                AccountName = Record.FieldOrDefault(a, "account_name", null),
                IsDefault = Record.FieldOrDefault(a, "is_default", false) = true,
                Environment = environment
            ])
    in
        Table.FromRecords(records, AccountsRowType, MissingField.UseNull);

// ===== DocuSign Navigator: Agreements / Parties / CustomField (see AGREEMENTS-REPORT-PLAN.md) =====

// ISO-8601 duration (e.g. "P1Y", "P60D", "P12M", "P1Y6M") to an approximate day count, matching
// the official Agreements template's *Days companion columns. Y=365, M=30, W=7, D=1; a time part
// after "T" is ignored (sub-day precision is meaningless for contract terms). Unparseable or
// empty values yield null rather than erroring.
shared DocuSignPowerBI.DurationToDays = (value as any) as nullable number =>
    let
        t = if value = null then null else (try Text.Upper(Text.Trim(Text.From(value))) otherwise null),
        result =
            if t = null or not Text.StartsWith(t, "P") then null
            else
                let
                    body = Text.Range(Text.Split(t, "T"){0}, 1),
                    acc = List.Accumulate(Text.ToList(body), [num = "", days = 0, valid = body <> ""], (s, c) =>
                        if not s[valid] then s
                        else if (c >= "0" and c <= "9") or c = "." then [num = s[num] & c, days = s[days], valid = true]
                        else
                            let
                                n = try Number.FromText(s[num]) otherwise null,
                                mult = if c = "Y" then 365 else if c = "M" then 30 else if c = "W" then 7 else if c = "D" then 1 else null
                            in
                                if n = null or mult = null then [num = "", days = 0, valid = false]
                                else [num = "", days = s[days] + (n * mult), valid = true])
                in if acc[valid] and acc[num] = "" then acc[days] else null
    in result;

// Pagination follows the response's own _links.next.href (ctoken-based) rather than computing
// offsets. Only the ctoken is lifted from that href and the request is rebuilt with a fixed
// [limit, ctoken] parameter order: the href is relative, omits the "/v1" prefix, and passing
// its parsed query record straight back through Web.Contents does not guarantee parameter
// order - which breaks exact-URL matching in PQTest's HTTP mocks.
shared DocuSignPowerBI.GetAgreementsRaw = (navigatorBase as text, accountId as text, token as text) as list =>
    let
        path = "v1/accounts/" & accountId & "/agreements",
        FetchPage = (ctoken as nullable text) as record =>
            DocuSignPowerBI.HttpGetWithRetry(
                navigatorBase, path, token,
                if ctoken = null then [limit = "100"] else [limit = "100", ctoken = ctoken], 0),
        NextCtoken = (response as record) as nullable text =>
            let
                links = Record.FieldOrDefault(response, "_links", null),
                next = if links = null then null else Record.FieldOrDefault(links, "next", null),
                href = if next = null then null else Record.FieldOrDefault(next, "href", null),
                query = if href = null then null else (try Uri.Parts("https://placeholder.invalid" & href)[Query] otherwise null)
            in if query = null then null else Record.FieldOrDefault(query, "ctoken", null),
        pages = List.Generate(
            () => [response = FetchPage(null), hasMore = true],
            each [hasMore],
            each
                let ctoken = NextCtoken([response])
                in [
                    response = if ctoken <> null then FetchPage(ctoken) else [data = {}],
                    hasMore = ctoken <> null
                ],
            each Record.FieldOrDefault([response], "data", {})
        )
    in List.Combine(pages);

// Pure transform. `asOfDate` exists so the 0/1 window flags (IsExpiringIn90days etc.) are
// deterministic under test; production callers omit it and get today. Flag semantics:
//   IsActive            - effective on/before asOf and not yet expired (open-ended counts as active).
//   IsActiveInNdays     - active at some point within the next N days (already active, or taking
//                         effect inside the window, and not expired before asOf).
//   IsExpiringInNdays   - expiration date falls inside [asOf, asOf+N].
//   IsRenewingInNdays   - renewal notice date falls inside the window; always 0 for FIXED_TERM
//                         agreements (Navigator emits a renewal_notice_date equal to the
//                         expiration date even when there is no renewal to act on).
//   IsTakingEffectInNdays - effective date falls inside the window.
shared DocuSignPowerBI.BuildAgreementsTable = (rawAgreements as list, accountId as nullable text, optional asOfDate as nullable date) as table =>
    let
        asOf = if asOfDate <> null then asOfDate else DateTime.Date(DateTime.LocalNow()),
        InWindow = (d as nullable datetime, daysAhead as number) as number =>
            if d <> null and DateTime.Date(d) >= asOf and DateTime.Date(d) <= Date.AddDays(asOf, daysAhead) then 1 else 0,
        MonthYear = (d as nullable datetime) as nullable text =>
            if d = null then null else Date.ToText(DateTime.Date(d), "MMM yyyy"),
        YearNumber = (d as nullable datetime) as nullable number =>
            if d = null then null else Date.Year(DateTime.Date(d)),
        records = List.Transform(rawAgreements, (a) =>
            let
                // FieldOrDefault only substitutes when the field is absent; an explicit JSON null
                // still comes through as null, so re-default to an empty record/list here.
                pRaw = Record.FieldOrDefault(a, "provisions", null),
                p = if pRaw = null then [] else pRaw,
                metaRaw = Record.FieldOrDefault(a, "metadata", null),
                metaRec = if metaRaw = null then [] else metaRaw,
                effective = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(p, "effective_date", null)),
                expiration = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(p, "expiration_date", null)),
                execution = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(p, "execution_date", null)),
                renewalType = Record.FieldOrDefault(p, "renewal_type", null),
                rawRenewalNoticeDate = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(p, "renewal_notice_date", null)),
                renewalNoticeDate = if renewalType = "FIXED_TERM" then null else rawRenewalNoticeDate,
                terminationConvenience = Record.FieldOrDefault(p, "termination_period_for_convenience", null),
                terminationConvenienceDays = DocuSignPowerBI.DurationToDays(terminationConvenience),
                languagesRaw = Record.FieldOrDefault(a, "languages", null),
                languages = if languagesRaw = null then {} else languagesRaw,
                isActiveNow = effective <> null and DateTime.Date(effective) <= asOf and (expiration = null or DateTime.Date(expiration) >= asOf),
                ActiveWithin = (daysAhead as number) as number =>
                    if effective <> null
                        and DateTime.Date(effective) <= Date.AddDays(asOf, daysAhead)
                        and (expiration = null or DateTime.Date(expiration) >= asOf)
                    then 1 else 0
            in [
                AccountId = accountId,
                Id = Record.FieldOrDefault(a, "id", null),
                Title = Record.FieldOrDefault(a, "title", null),
                FileName = Record.FieldOrDefault(a, "file_name", null),
                DocumentId = Record.FieldOrDefault(a, "document_id", null),
                AgreementType = Record.FieldOrDefault(a, "type", null),
                Category = Record.FieldOrDefault(a, "category", null),
                Status = Record.FieldOrDefault(a, "status", null),
                ReviewStatus = Record.FieldOrDefault(a, "review_status", null),
                Languages = if List.IsEmpty(languages) then null else Text.Combine(List.Transform(languages, each Text.From(_)), ", "),
                SourceName = Record.FieldOrDefault(a, "source_name", null),
                SourceId = Record.FieldOrDefault(a, "source_id", null),
                EnvelopeId = Record.FieldOrDefault(a, "envelope_id", null),
                CreatedDate = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(metaRec, "created_at", null)),
                ModifiedDate = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(metaRec, "modified_at", null)),
                EffectiveDate = effective,
                ExpirationDate = expiration,
                ExecutionDate = execution,
                TermLength = Record.FieldOrDefault(p, "term_length", null),
                TermLengthDays = DocuSignPowerBI.DurationToDays(Record.FieldOrDefault(p, "term_length", null)),
                RenewalType = renewalType,
                IsAutoRenewal = if renewalType = null then null else renewalType = "AUTO_RENEW",
                RenewalTerm = Record.FieldOrDefault(p, "auto_renewal_term_length", null),
                RenewalTermDays = DocuSignPowerBI.DurationToDays(Record.FieldOrDefault(p, "auto_renewal_term_length", null)),
                RenewalNoticePeriod = Record.FieldOrDefault(p, "renewal_notice_period", null),
                RenewalNoticePeriodDays = DocuSignPowerBI.DurationToDays(Record.FieldOrDefault(p, "renewal_notice_period", null)),
                RenewalNoticeDate = renewalNoticeDate,
                RenewalOwner = Record.FieldOrDefault(p, "renewal_owner", null),
                TerminationForCauseNoticePeriod = Record.FieldOrDefault(p, "termination_period_for_cause", null),
                TerminationForCauseNoticePeriodDays = DocuSignPowerBI.DurationToDays(Record.FieldOrDefault(p, "termination_period_for_cause", null)),
                TerminationForConvenienceNoticePeriod = terminationConvenience,
                TerminationForConvenienceNoticePeriodDays = terminationConvenienceDays,
                TerminationNoticeDueDate =
                    if expiration <> null and terminationConvenienceDays <> null
                    then Date.AddDays(expiration, -terminationConvenienceDays)
                    else null,
                PaymentTerms = Record.FieldOrDefault(p, "payment_terms_due_date", null),
                LatePaymentFee = DocuSignPowerBI.SafeBool(Record.FieldOrDefault(p, "can_charge_late_payment_fees", null)),
                LatePaymentFeePercent = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(p, "late_payment_fee_percent", null)),
                LiabilityCapDuration = Record.FieldOrDefault(p, "liability_cap_duration", null),
                LiabilityCapDurationDays = DocuSignPowerBI.DurationToDays(Record.FieldOrDefault(p, "liability_cap_duration", null)),
                LiabilityCapFixedAmount = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(p, "liability_cap_fixed_amount", null)),
                LiabilityCapFixedAmountCurrency = Record.FieldOrDefault(p, "liability_cap_fixed_amount_currency_code", null),
                LiabilityCapMultiplier = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(p, "liability_cap_multiplier", null)),
                PriceCapIncreasePercent = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(p, "price_cap_percent_increase", null)),
                TotalValue = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(p, "total_agreement_value", null)),
                TotalValueCurrency = Record.FieldOrDefault(p, "total_agreement_value_currency_code", null),
                AnnualContractValue = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(p, "annual_agreement_value", null)),
                AnnualContractValueCurrency = Record.FieldOrDefault(p, "annual_agreement_value_currency_code", null),
                Assignment = Record.FieldOrDefault(p, "assignment_type", null),
                AssignmentChangeOfControl = Record.FieldOrDefault(p, "assignment_change_of_control", null),
                AssignmentTerminationRights = Record.FieldOrDefault(p, "assignment_termination_rights", null),
                GoverningLaw = Record.FieldOrDefault(p, "governing_law", null),
                Jurisdiction = Record.FieldOrDefault(p, "jurisdiction", null),
                NdaType = Record.FieldOrDefault(p, "nda_type", null),
                ConfidentialityObligationPeriod = Record.FieldOrDefault(p, "confidentiality_obligation_period", null),
                ConfidentialityObligationPeriodDays = DocuSignPowerBI.DurationToDays(Record.FieldOrDefault(p, "confidentiality_obligation_period", null)),
                IsActive = if isActiveNow then 1 else 0,
                IsActiveIn30days = ActiveWithin(30),
                IsExpiringIn30days = InWindow(expiration, 30),
                IsRenewingIn30days = InWindow(renewalNoticeDate, 30),
                IsTakingEffectIn30days = InWindow(effective, 30),
                IsActiveIn90days = ActiveWithin(90),
                IsExpiringIn90days = InWindow(expiration, 90),
                IsRenewingIn90days = InWindow(renewalNoticeDate, 90),
                IsTakingEffectIn90days = InWindow(effective, 90),
                EffectiveYearNumber = YearNumber(effective),
                ExpirationYearNumber = YearNumber(expiration),
                ExecutionYearNumber = YearNumber(execution),
                RenewalNoticeYearNumber = YearNumber(renewalNoticeDate),
                EffectiveMonthYear = MonthYear(effective),
                ExpirationMonthYear = MonthYear(expiration)
            ])
    in
        Table.FromRecords(records, AgreementsRowType, MissingField.UseNull);

// Pure transform: one row per party per agreement. The live list payload carries parties inline
// as [{id, name_in_agreement}] - no role/side/email at this level (confirmed 2026-11-26).
shared DocuSignPowerBI.FlattenAgreementParties = (rawAgreements as list, accountId as nullable text) as list =>
    List.Combine(List.Transform(rawAgreements, (a) =>
        let partiesRaw = Record.FieldOrDefault(a, "parties", null)
        in List.Transform(if partiesRaw = null then {} else partiesRaw, (party) =>
            [
                AccountId = accountId,
                AgreementId = Record.FieldOrDefault(a, "id", null),
                PartyId = Record.FieldOrDefault(party, "id", null),
                PartyName = Record.FieldOrDefault(party, "name_in_agreement", null)
            ])));

shared DocuSignPowerBI.BuildAgreementPartiesTable = (rawAgreements as list, accountId as nullable text) as table =>
    Table.FromRecords(DocuSignPowerBI.FlattenAgreementParties(rawAgreements, accountId), AgreementPartiesRowType, MissingField.UseNull);

// Pure transform: unpivots each agreement's custom_provisions record into one row per field.
// Values are stringified (custom provisions are free-typed); empty/missing records yield no rows.
shared DocuSignPowerBI.FlattenAgreementCustomFields = (rawAgreements as list, accountId as nullable text) as list =>
    List.Combine(List.Transform(rawAgreements, (a) =>
        let
            cpRaw = Record.FieldOrDefault(a, "custom_provisions", null),
            cp = if cpRaw = null then [] else cpRaw
        in List.Transform(Record.FieldNames(cp), (fieldName) =>
            let v = Record.Field(cp, fieldName)
            in [
                AccountId = accountId,
                AgreementId = Record.FieldOrDefault(a, "id", null),
                FieldName = fieldName,
                FieldValue = if v = null then null else (try Text.From(v) otherwise null)
            ])));

shared DocuSignPowerBI.BuildAgreementCustomFieldsTable = (rawAgreements as list, accountId as nullable text) as table =>
    Table.FromRecords(DocuSignPowerBI.FlattenAgreementCustomFields(rawAgreements, accountId), AgreementCustomFieldsRowType, MissingField.UseNull);

// ===== Navigation table helper (standard Microsoft DataConnectors sample helper) =====

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta
        [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            Preview.DelayColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
