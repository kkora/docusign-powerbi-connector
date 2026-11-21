[Version = "1.0.0"]
section DocuSignPowerBI.Test.Unit;

// Independently computed with: printf '%s' <verifier> | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '='
fixedVerifier = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
expectedChallenge = "zwBxoIOtPkc0nS4_vIltB6DVBYCzNcN-OX1Akb-OcTs";

verifierA = DocuSignPowerBI.NewVerifier();
verifierB = DocuSignPowerBI.NewVerifier();

loginDemo = DocuSignPowerBI.StartLogin("Demo", "state-123", null);
loginProd = DocuSignPowerBI.StartLogin("Production", "state-456", null);

finishStateMismatch = try DocuSignPowerBI.FinishLogin([verifier = "v", environment = "Demo"], "https://oauth.powerbi.com/views/oauthredirect.html?code=abc&state=WRONG", "expected-state");
finishNoCode = try DocuSignPowerBI.FinishLogin([verifier = "v", environment = "Demo"], "https://oauth.powerbi.com/views/oauthredirect.html?state=expected-state", "expected-state");
finishOAuthError = try DocuSignPowerBI.FinishLogin([verifier = "v", environment = "Demo"], "https://oauth.powerbi.com/views/oauthredirect.html?error=access_denied&state=expected-state", "expected-state");

shared DocuSignPowerBI.Test.Unit = PQTest(
    [Owner = "automation", Traits = [Category = "Unit-Auth"]],
    {
        // AUTH-02: PKCE S256 challenge generation.
        Fact("AUTH-02 PKCE challenge matches an independently computed SHA256 base64url vector", expectedChallenge, DocuSignPowerBI.Challenge(fixedVerifier)),
        Fact("AUTH-02 PKCE verifier length is within RFC 7636 bounds (43-128)", true, Text.Length(verifierA) >= 43 and Text.Length(verifierA) <= 128),
        Fact("AUTH-02 PKCE verifier only uses the RFC 7636 unreserved charset", true, Text.Trim(verifierA, Text.ToList("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")) = ""),

        // AUTH-03: verifier/challenge matching.
        Fact("AUTH-03 challenge generation is deterministic for the same verifier", DocuSignPowerBI.Challenge(verifierA), DocuSignPowerBI.Challenge(verifierA)),
        Fact("AUTH-03 distinct verifiers produce distinct challenges", true, DocuSignPowerBI.Challenge(verifierA) <> DocuSignPowerBI.Challenge(verifierB)),

        // AUTH-01: authorization URL construction.
        Fact("AUTH-01 Demo authorization URL targets the Demo auth host", true, Text.StartsWith(loginDemo[LoginUri], "https://account-d.docusign.com/oauth/auth?")),
        Fact("AUTH-01 Production authorization URL targets the Production auth host", true, Text.StartsWith(loginProd[LoginUri], "https://account.docusign.com/oauth/auth?")),
        Fact("AUTH-01 authorization URL requests S256 PKCE", true, Text.Contains(loginDemo[LoginUri], "code_challenge_method=S256")),
        Fact("AUTH-01 authorization URL carries a code_challenge parameter", true, Text.Contains(loginDemo[LoginUri], "code_challenge=")),
        Fact("AUTH-01 authorization URL carries the caller-supplied state", true, Text.Contains(loginDemo[LoginUri], "state=state-123")),
        Fact("AUTH-01 CallbackUri is the registered Power BI OAuth redirect", "https://oauth.powerbi.com/views/oauthredirect.html", loginDemo[CallbackUri]),

        // AUTH-04: OAuth state validation.
        Fact("AUTH-04 mismatched state is rejected", true, finishStateMismatch[HasError]),
        Fact("AUTH-04 mismatched state error message names the mismatch", true, Text.Contains(finishStateMismatch[Error][Message], "state mismatch")),
        Fact("AUTH-04 missing authorization code is rejected", true, finishNoCode[HasError]),
        Fact("AUTH-04 upstream OAuth error (access_denied) is surfaced, not swallowed", true, finishOAuthError[HasError]),

        // AUTH-10: no secret leakage via the public M surface - StartLogin's context carries only the PKCE verifier and environment tag, never a client secret or token.
        Fact("AUTH-10 StartLogin context exposes only the PKCE verifier and environment", {"environment", "verifier"}, List.Sort(Record.FieldNames(loginDemo[Context])))
    });
