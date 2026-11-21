[Version = "1.1.0"]
section DocuSignPowerBI;

// DocuSign Integration Key for a public-client Authorization Code + PKCE application. Preserve this value.
ClientId = "5869c14c-ebf6-465d-b940-2ad76d259d56";

RedirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";
Scope = "signature extended";

// Bounded retry tuning for HTTP 429 / 5xx responses.
MaxRetryAttempts = 3;
BaseRetryDelaySeconds = 1;
MaxRetryDelaySeconds = 10;

EnvelopesRowType = type table [
    AccountId = nullable text, EnvelopeId = nullable text, EmailSubject = nullable text,
    Status = nullable text, CreatedDateTime = nullable datetime, SentDateTime = nullable datetime,
    CompletedDateTime = nullable datetime, VoidedDateTime = nullable datetime, LastModifiedDateTime = nullable datetime
];

RecipientsRowType = type table [
    EnvelopeId = nullable text, RecipientId = nullable text, RecipientName = nullable text,
    RecipientEmail = nullable text, RecipientType = nullable text, RoutingOrder = nullable number,
    RecipientStatus = nullable text, SignedDateTime = nullable datetime, DeliveredDateTime = nullable datetime
];

RecipientBuckets = {"signers", "agents", "editors", "intermediaries", "carbonCopies", "certifiedDeliveries", "inPersonSigners", "seals", "witnesses", "notaries"};

// ===== OAuth 2.0 Authorization Code with PKCE (S256) =====

shared DocuSignPowerBI.AuthHost = (environment as text) as text =>
    if environment = "Demo" then "https://account-d.docusign.com"
    else if environment = "Production" then "https://account.docusign.com"
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
            Headers = [#"Content-Type" = "application/x-www-form-urlencoded", Accept = "application/json"]
        ]),
        result = DocuSignPowerBI.SafeJsonDocument(response)
    in result;

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

[DataSource.Kind = "DocuSignPowerBI", Publish = "DocuSignPowerBI.Publish"]
shared DocuSignPowerBI.Contents = (environment as text, optional fromDate as nullable text) as table =>
    let
        _validEnvironment =
            if environment <> "Demo" and environment <> "Production" then
                error Error.Record("DocuSign.Config", "Unsupported environment '" & environment & "'. Use Demo or Production.", environment)
            else environment,
        _fromDate = DocuSignPowerBI.ResolveFromDate(fromDate),
        token = Extension.CurrentCredential()[access_token],
        userInfo = DocuSignPowerBI.GetUserInfo(_validEnvironment, token),
        accounts = Record.FieldOrDefault(userInfo, "accounts", {}),
        _accountsChecked = if List.IsEmpty(accounts) then error Error.Record("DocuSign.Account", "The authenticated DocuSign user has no accessible accounts.", null) else accounts,
        account = List.First(List.Select(_accountsChecked, each Record.FieldOrDefault(_, "is_default", false) = true), _accountsChecked{0}),
        accountId = Record.FieldOrDefault(account, "account_id", null),
        apiBase = Text.TrimEnd(Record.FieldOrDefault(account, "base_uri", ""), "/"),
        rawEnvelopes = DocuSignPowerBI.GetEnvelopesRaw(apiBase, accountId, token, _fromDate),
        envelopesTable = Table.Distinct(DocuSignPowerBI.BuildEnvelopesTable(rawEnvelopes, accountId), {"EnvelopeId"}),
        recipientsTable = DocuSignPowerBI.BuildRecipientsTable(apiBase, accountId, token, envelopesTable),
        statusTable = DocuSignPowerBI.BuildStatusTable(envelopesTable),
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Envelopes", "Envelopes", envelopesTable, "Table", "Table", true},
                {"Recipients", "Recipients", recipientsTable, "Table", "Table", true},
                {"Envelope Status", "Envelope Status", statusTable, "Table", "Table", true}
            }
        ),
        nav = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in nav;

shared DocuSignPowerBI.ResolveFromDate = (fromDate as nullable text) as text =>
    let
        defaulted = if fromDate = null or Text.Trim(fromDate) = "" then Date.ToText(Date.AddDays(DateTime.Date(DateTime.LocalNow()), -30), "yyyy-MM-dd") else fromDate,
        validated = if (try Date.FromText(defaulted) otherwise null) = null then error Error.Record("DocuSign.Config", "fromDate must be in YYYY-MM-DD format.", defaulted) else defaulted
    in validated;

// ===== HTTP plumbing: null-safe JSON, 401 (engine-refresh), 403, 429/5xx bounded retry =====

shared DocuSignPowerBI.SafeJsonDocument = (response as binary) as any =>
    try Json.Document(response) otherwise error Error.Record("DocuSign.InvalidResponse", "DocuSign returned a response that could not be parsed as JSON.", null);

shared DocuSignPowerBI.SafeInt = (value as any) as number =>
    if value = null then 0
    else
        let parsed = try Number.FromText(Text.From(value)) otherwise null
        in if parsed = null then 0 else Number.RoundDown(parsed);

shared DocuSignPowerBI.SafeNumber = (value as any) as nullable number =>
    if value = null then null else try Number.FromText(Text.From(value)) otherwise null;

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
                error Error.Record("DocuSign.Forbidden", "DocuSign denied access (HTTP 403). Verify the OAuth scopes (signature extended) and the account's API permissions.", status)
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

// ===== Envelopes: pagination via resultSetSize/totalSetSize/endPosition =====

shared DocuSignPowerBI.GetEnvelopesRaw = (base as text, accountId as text, token as text, fromDate as text) as list =>
    let
        path = "restapi/v2.1/accounts/" & accountId & "/envelopes",
        pageSize = 100,
        FetchPage = (startPosition as number) as record =>
            DocuSignPowerBI.HttpGetWithRetry(base, path, token,
                [from_date = fromDate, start_position = Text.From(startPosition), count = Text.From(pageSize)], 0),
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

// ===== Recipients: fan out per envelope, flatten every DocuSign recipient bucket =====

// Pure transform: flattens one envelope's raw /recipients JSON record (as returned
// by DocuSign) across every recipient bucket into a flat row list. No I/O, so this
// is directly unit-testable with hand-built fixture records.
shared DocuSignPowerBI.FlattenRecipients = (raw as record, envelopeId as text) as list =>
    List.Combine(List.Transform(RecipientBuckets, (bucket) =>
        List.Transform(Record.FieldOrDefault(raw, bucket, {}), (person) =>
            [
                EnvelopeId = envelopeId,
                RecipientId = Record.FieldOrDefault(person, "recipientId", null),
                RecipientName = Record.FieldOrDefault(person, "name", null),
                RecipientEmail = Record.FieldOrDefault(person, "email", null),
                RecipientType = bucket,
                RoutingOrder = DocuSignPowerBI.SafeNumber(Record.FieldOrDefault(person, "routingOrder", null)),
                RecipientStatus = Record.FieldOrDefault(person, "status", null),
                SignedDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(person, "signedDateTime", null)),
                DeliveredDateTime = DocuSignPowerBI.ToDateTime(Record.FieldOrDefault(person, "deliveredDateTime", null))
            ])));

shared DocuSignPowerBI.BuildRecipientsTable = (base as text, accountId as text, token as text, envelopes as table) as table =>
    let
        ids = if Table.HasColumns(envelopes, "EnvelopeId") then List.RemoveNulls(Table.Column(envelopes, "EnvelopeId")) else {},
        rows = List.Combine(List.Transform(ids, (envelopeId) =>
            let
                raw = DocuSignPowerBI.HttpGetWithRetry(base, "restapi/v2.1/accounts/" & accountId & "/envelopes/" & envelopeId & "/recipients", token, null, 0)
            in DocuSignPowerBI.FlattenRecipients(raw, envelopeId)))
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

// ===== Navigator helper (standard Microsoft DataConnectors sample helper) =====

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
