// This file contains your Data Connector logic
[Version = "1.0.0"]
section DocuSignPowerBI;

[DataSource.Kind="DocuSignPowerBI", Publish="DocuSignPowerBI.Publish"]
shared DocuSignPowerBI.Contents = (optional message as text) =>
    let
        _message = if (message <> null) then message else "(no message)",
        a = "Hello from DocuSignPowerBI: " & _message
    in
        a;

// Data Source Kind description
DocuSignPowerBI = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Anonymous = []
    ]
];

// Data Source UI publishing description
DocuSignPowerBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = DocuSignPowerBI.Icons,
    SourceTypeImage = DocuSignPowerBI.Icons
];

DocuSignPowerBI.Icons = [
    Icon16 = { Extension.Contents("DocuSignPowerBI16.png"), Extension.Contents("DocuSignPowerBI20.png"), Extension.Contents("DocuSignPowerBI24.png"), Extension.Contents("DocuSignPowerBI32.png") },
    Icon32 = { Extension.Contents("DocuSignPowerBI32.png"), Extension.Contents("DocuSignPowerBI40.png"), Extension.Contents("DocuSignPowerBI48.png"), Extension.Contents("DocuSignPowerBI64.png") }
];
