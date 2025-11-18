using Microsoft.AspNetCore.Authentication.Negotiate;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using System;

var builder = WebApplication.CreateBuilder(args);

// Configure Kerberos/Negotiate authentication
builder.Services.AddAuthentication(NegotiateDefaults.AuthenticationScheme)
    .AddNegotiate();

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", (HttpContext context) =>
{
    var user = context.User.Identity;
    if (user?.IsAuthenticated == true)
    {
        Console.WriteLine($"[SERVER] Authenticated user: {user.Name}");
        return Results.Ok(new
        {
            authenticated = true,
            username = user.Name,
            authenticationType = user.AuthenticationType,
            message = "Kerberos authentication successful"
        });
    }
    else
    {
        Console.WriteLine("[SERVER] User not authenticated");
        return Results.Unauthorized();
    }
});

// Read configuration from environment
var port = Environment.GetEnvironmentVariable("SERVER_PORT") ?? "5000";
var keytabPath = Environment.GetEnvironmentVariable("KRB5_KTNAME");

if (string.IsNullOrEmpty(keytabPath))
{
    Console.WriteLine("error: KRB5_KTNAME environment variable not set");
    Environment.Exit(1);
}

Console.WriteLine($"[SERVER] Starting on port {port}");
Console.WriteLine($"[SERVER] Using keytab: {keytabPath}");

app.Urls.Add($"http://localhost:{port}");
app.Run();
