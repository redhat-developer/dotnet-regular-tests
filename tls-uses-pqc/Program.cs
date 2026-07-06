// This test verifies that OpenSSL TLS uses PQC key exchange by default.
// It performs a standard TLS handshake and then checks that a PQC group was negotiated.

using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

SetOpenSSLImportResolver();

// Create a self-signed certificate.
using var key = ECDsa.Create();
var certReq = new CertificateRequest("CN=localhost", key, HashAlgorithmName.SHA256);
using var cert = certReq.CreateSelfSigned(DateTimeOffset.UtcNow.AddMinutes(-1), DateTimeOffset.UtcNow.AddYears(1));

// Set up a loopback TCP connection.
var listener = new TcpListener(IPAddress.Loopback, 0);
listener.Start();
int port = ((IPEndPoint)listener.LocalEndpoint).Port;

// Server side: accept and authenticate as TLS server.
var serverTask = Task.Run(async () =>
{
    using var serverClient = await listener.AcceptTcpClientAsync();
    await using var serverSsl = new SslStream(serverClient.GetStream(), false);
    await serverSsl.AuthenticateAsServerAsync(cert);
    return GetNegotiatedGroupName(serverSsl);
});

// Client side: connect and authenticate as TLS client.
using var client = new TcpClient();
await client.ConnectAsync(IPAddress.Loopback, port);
await using var clientSsl = new SslStream(client.GetStream(), false, (sender, certificate, chain, errors) => true /* accept cert */);
await clientSsl.AuthenticateAsClientAsync("localhost");

string? clientGroup = GetNegotiatedGroupName(clientSsl);
string? serverGroup = await serverTask;
listener.Stop();

Console.WriteLine($"Client negotiated group: {clientGroup}");
Console.WriteLine($"Server negotiated group: {serverGroup}");

// Verify PQC was used: the group name should contain "MLKEM".
bool clientPqc = clientGroup != null && clientGroup.Contains("MLKEM", StringComparison.OrdinalIgnoreCase);
bool serverPqc = serverGroup != null && serverGroup.Contains("MLKEM", StringComparison.OrdinalIgnoreCase);

if (clientPqc && serverPqc)
{
    Console.WriteLine("PASS: PQC key exchange negotiated.");
    return 0;
}

Console.WriteLine($"FAIL: Expected PQC key exchange group containing 'MLKEM', got client: '{clientGroup}', server: '{serverGroup}'");
return 1;

// Use OpenSSL interop to get the negotiated key exchange group (SslStream doesn't expose this information).
static void SetOpenSSLImportResolver()
{
    // Use the latest OpenSSL version on the system.
    NativeLibrary.SetDllImportResolver(Assembly.GetExecutingAssembly(), (name, assembly, searchPath) =>
    {
        if (name == "libssl")
        {
            if (NativeLibrary.TryLoad("libssl.so.4", assembly, searchPath, out var h) ||
                NativeLibrary.TryLoad("libssl.so.3", assembly, searchPath, out h))
            {
                return h;
            }
            throw new NotSupportedException($"Cannot resolve {name}.");
        }
        return IntPtr.Zero; // Use the default resolution logic.
    });
}

static string? GetNegotiatedGroupName(SslStream sslStream)
{
    var secCtxField = typeof(SslStream).GetField("_securityContext", BindingFlags.NonPublic | BindingFlags.Instance)!;
    var safeSslHandle = (SafeHandle)secCtxField.GetValue(sslStream)!;
    bool added = false;
    safeSslHandle.DangerousAddRef(ref added);
    try
    {
        IntPtr namePtr = SSL_get0_group_name(safeSslHandle.DangerousGetHandle());
        return namePtr == IntPtr.Zero ? null : Marshal.PtrToStringAnsi(namePtr);
    }
    finally
    {
        if (added) safeSslHandle.DangerousRelease();
    }
}

[DllImport("libssl")]
static extern IntPtr SSL_get0_group_name(IntPtr ssl);
