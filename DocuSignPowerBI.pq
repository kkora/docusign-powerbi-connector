section DocuSignPowerBI;

// Set this to the Integration Key of a DocuSign public-client application.
//ClientId = "REPLACE_WITH_DOCUSIGN_INTEGRATION_KEY";
ClientId = "5869c14c-ebf6-465d-b940-2ad76d259d56";

RedirectUri = "https://oauth.powerbi.com/views/oauthredirect.html";
Scope = "signature extended";

AuthHost = (environment as text) as text =>
    if environment = "Demo" then "https://account-d.docusign.com"
    else "https://account.docusign.com";

BaseUri = (environment as text) as text =>
    if environment = "Demo" then "https://demo.docusign.net"
    else error "Production API base URI must be supplied from DocuSign UserInfo; use Demo until production host support is configured.";

Base64Url = (bytes as binary) as text =>
    Text.Replace(Text.Replace(Text.TrimEnd(Binary.ToText(bytes, BinaryEncoding.Base64), "="), "+", "-"), "/", "_");

// PKCE verifier: GUIDs provide 256 bits of random material and URL-safe characters.
NewVerifier = () as text => Text.Replace(Text.NewGuid(), "-", "") & Text.Replace(Text.NewGuid(), "-", "");

StartLogin = (dataSourcePath, state, display) =>
    let
        verifier = NewVerifier(),
        challenge = Base64Url(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(verifier, TextEncoding.Ascii))),
        url = AuthHost("Demo") & "/oauth/auth?" & Uri.BuildQueryString([
            response_type = "code", client_id = ClientId, redirect_uri = RedirectUri,
            scope = Scope, state = state, code_challenge = challenge,
            code_challenge_method = "S256"
        ])
    in [LoginUri = url, CallbackUri = RedirectUri, WindowHeight = 720,
        WindowWidth = 1024, Context = [verifier = verifier]];

FinishLogin = (context, callbackUri, state) =>
    let
        query = Uri.Parts(callbackUri)[Query],
        result = if Record.HasFields(query, "error") then
            error Error.Record("DocuSign OAuth", Text.From(query[error]), query)
        else if Record.FieldOrDefault(query, "state", "") <> state then
            error "OAuth state mismatch"
        else TokenRequest([grant_type = "authorization_code", code = query[code],
            code_verifier = context[verifier], redirect_uri = RedirectUri])
    in result;

Refresh = (dataSourcePath, refreshToken) =>
    TokenRequest([grant_type = "refresh_token", refresh_token = refreshToken]);

TokenRequest = (fields as record) as record =>
    let
        response = Web.Contents(AuthHost("Demo"), [
            RelativePath = "oauth/token",
            Content = Text.ToBinary(Uri.BuildQueryString(Record.Combine({fields, [client_id = ClientId]}))),
            Headers = [#"Content-Type" = "application/x-www-form-urlencoded", Accept = "application/json"],
            ManualCredentials = true
        ]),
        result = Json.Document(response)
    in result;

DocuSignPowerBI = [
    TestConnection = (dataSourcePath) => {"DocuSignPowerBI.Contents", "Demo", "2026-01-01"},
    Authentication = [OAuth = [StartLogin = StartLogin, FinishLogin = FinishLogin, Refresh = Refresh]],
    Label = "DocuSign eSignature"
];

DocuSignPowerBI.Publish = [Beta = true, Category = "Online Services",
    ButtonText = {"DocuSign eSignature", "DocuSign envelopes and recipients"},
    LearnMoreUrl = "https://developers.docusign.com/docs/esign-rest-api/"];

[DataSource.Kind = "DocuSignPowerBI", Publish = "DocuSignPowerBI.Publish"]
shared DocuSignPowerBI.Contents = (environment as text, fromDate as text) as table =>
    let
        _env = if environment <> "Demo" then error "This build supports Demo only" else environment,
        _date = if (try Date.FromText(fromDate) otherwise null) = null then error "Use YYYY-MM-DD" else fromDate,
        token = Extension.CurrentCredential()[access_token],
        userInfo = Json.Document(Web.Contents(AuthHost(_env), [RelativePath = "oauth/userinfo",
            Headers = [Authorization = "Bearer " & token], ManualCredentials = true])),
        accounts = userInfo[accounts],
        account = List.First(List.Select(accounts, each Record.FieldOrDefault(_, "is_default", false) = true), accounts{0}),
        accountId = account[account_id],
        apiBase = Text.TrimEnd(account[base_uri], "/"),
        envelopes = GetEnvelopes(apiBase, accountId, token, _date),
        recipients = GetRecipients(apiBase, accountId, token, envelopes),
        statuses = Table.SelectColumns(envelopes, {"envelopeId", "status", "statusChangedDateTime", "sentDateTime", "completedDateTime", "voidedDateTime", "declinedDateTime"}, MissingField.UseNull),
        nav = #table(type table [Name = text, Data = table], {
            {"Envelopes", envelopes}, {"Recipients", recipients}, {"Envelope Status", statuses}
        })
    in nav;

ApiGet = (base as text, path as text, token as text, optional query as nullable record) as record =>
    Json.Document(Web.Contents(base, [RelativePath = path,
        Query = if query = null then [] else query,
        Headers = [Authorization = "Bearer " & token, Accept = "application/json"],
        ManualCredentials = true]));

GetEnvelopes = (base as text, account as text, token as text, fromDate as text) as table =>
    let
        path = "restapi/v2.1/accounts/" & account & "/envelopes",
        pages = List.Generate(
            () => [position = 0, response = ApiGet(base, path, token,
                [from_date = fromDate, start_position = "0", count = "100"])],
            each [response] <> null,
            each let
                batch = Record.FieldOrDefault([response], "envelopes", {}),
                nextPos = [position] + List.Count(batch),
                hasMore = Record.FieldOrDefault([response], "nextUri", null) <> null
                    and List.Count(batch) > 0
            in [position = nextPos,
                response = if hasMore then ApiGet(base, path, token,
                    [from_date = fromDate, start_position = Text.From(nextPos), count = "100"])
                    else null],
            each Record.FieldOrDefault([response], "envelopes", {})
        ),
        records = List.Combine(pages),
        result = if List.IsEmpty(records) then #table({"envelopeId", "status"}, {})
            else Table.FromRecords(records, null, MissingField.UseNull)
    in result;

GetRecipients = (base as text, account as text, token as text, envelopes as table) as table =>
    let
        ids = if Table.HasColumns(envelopes, "envelopeId") then
            List.RemoveNulls(Table.Column(envelopes, "envelopeId")) else {},
        rows = List.Combine(List.Transform(ids, (id) =>
            let
                r = ApiGet(base, "restapi/v2.1/accounts/" & account & "/envelopes/" & id & "/recipients", token),
                types = {"signers", "carbonCopies", "certifiedDeliveries", "agents", "editors", "intermediaries", "inPersonSigners"},
                items = List.Combine(List.Transform(types, (t) =>
                    List.Transform(Record.FieldOrDefault(r, t, {}), (person) =>
                        Record.Combine({person, [envelopeId = id, recipientType = t]}))))
            in items)),
        result = if List.IsEmpty(rows) then #table({"envelopeId", "recipientType", "name", "email", "status"}, {})
            else Table.FromRecords(rows, null, MissingField.UseNull)
    in result;
