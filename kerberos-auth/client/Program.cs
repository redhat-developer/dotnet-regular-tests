using System;
using System.Net;
using System.Net.Http;
using System.Text.Json;

// Read configuration from environment
var serverUrl = Environment.GetEnvironmentVariable("SERVER_URL");
if (string.IsNullOrEmpty(serverUrl))
{
    Console.WriteLine("error: SERVER_URL environment variable not set");
    Environment.Exit(1);
    return;
}

Console.WriteLine($"[CLIENT] Connecting to: {serverUrl}");

// Create HttpClient with default credentials (uses Kerberos)
var handler = new HttpClientHandler
{
    UseDefaultCredentials = true,
    Credentials = CredentialCache.DefaultCredentials
};

using var client = new HttpClient(handler);

try
{
    var response = await client.GetAsync(serverUrl);

    Console.WriteLine($"[CLIENT] Response status: {response.StatusCode}");

    if (response.IsSuccessStatusCode)
    {
        var content = await response.Content.ReadAsStringAsync();
        Console.WriteLine($"[CLIENT] Response: {content}");

        // Parse JSON to verify authentication
        var jsonDoc = JsonDocument.Parse(content);
        if (jsonDoc.RootElement.TryGetProperty("authenticated", out var authProp) &&
            authProp.GetBoolean())
        {
            Console.WriteLine("[CLIENT] SUCCESS: Kerberos authentication verified");
            Environment.Exit(0);
        }
        else
        {
            Console.WriteLine("[CLIENT] FAIL: Response does not indicate authentication");
            Environment.Exit(1);
        }
    }
    else
    {
        Console.WriteLine($"[CLIENT] FAIL: HTTP {response.StatusCode}");
        var content = await response.Content.ReadAsStringAsync();
        Console.WriteLine($"[CLIENT] Response body: {content}");
        Environment.Exit(1);
    }
}
catch (Exception ex)
{
    Console.WriteLine($"[CLIENT] error: {ex.Message}");
    Console.WriteLine($"[CLIENT] Stack trace: {ex.StackTrace}");
    Environment.Exit(1);
}
