[Version = "1.0.0"]
section DocuSignPowerBI.Test.Integration.OAuthExchange;

// AUTH-05: a valid authorization code exchange against the Demo token endpoint.
validExchange = DocuSignPowerBI.FinishLogin(
    [verifier = "test-verifier", environment = "Demo"],
    "https://oauth.powerbi.com/views/oauthredirect.html?code=good-code&state=xyz",
    "xyz");

// AUTH-06: an invalid authorization code. Routed to the Production token endpoint mock (400
// invalid_grant) purely as a mock-routing device, since the HTTP mock matcher cannot distinguish
// requests by body/grant value - only by method/URL/headers. This does not claim Production OAuth
// itself has been live-tested; see README "Known limitations".
invalidCodeExchange = try DocuSignPowerBI.FinishLogin(
    [verifier = "test-verifier", environment = "Production"],
    "https://oauth.powerbi.com/views/oauthredirect.html?code=bad-code&state=xyz",
    "xyz");

// AUTH-07: refreshing an access token against the Demo token endpoint.
refreshResult = DocuSignPowerBI.Refresh("Demo", "some-refresh-token");

// AUTH-08: a revoked/invalid refresh token, routed to the Production token endpoint mock (400 invalid_grant) for the same reason as AUTH-06.
revokedRefreshResult = try DocuSignPowerBI.Refresh("Production", "revoked-refresh-token");

shared DocuSignPowerBI.Test.Integration.OAuthExchange = PQTest(
    [Owner = "automation", Traits = [Category = "Integration-OAuth"]],
    {
        Fact("AUTH-05 a valid authorization code exchange returns an access token", "NEWACCESSTOKEN", validExchange[access_token]),
        Fact("AUTH-05 a valid authorization code exchange returns a refresh token", "NEWREFRESHTOKEN", validExchange[refresh_token]),
        Fact("AUTH-06 an invalid authorization code surfaces the token endpoint's error, not a crash", true, invalidCodeExchange[HasError]),

        Fact("AUTH-07 refreshing an access token returns a new access token", "NEWACCESSTOKEN", refreshResult[access_token]),
        Fact("AUTH-08 a revoked refresh token surfaces the token endpoint's invalid_grant error", true, revokedRefreshResult[HasError])
    });
