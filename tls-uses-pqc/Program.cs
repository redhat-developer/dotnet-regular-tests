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
    NativeLibrary.SetDllImportResolver(Assembly.GetExecutingAssembly(), (name, assembly, searchPath) =>
    {
        Console.WriteLine($"Resolving {name}...");

        if (name == "libssl")
        {
            // The runtime can pick a libssl version based on the build
            // configuration (portable vs non-portable) and/or version-priority
            // and/or user-overrides. Instead of hardcoding or guessing, find
            // the version of libssl.so already loaded into the current
            // process. By the time this runs, we have already used TLS
            // operations like SslStream(), so some version of libssl must be
            // already loaded on *nix.
            var procSelfMaps = File.ReadAllText("/proc/self/maps");
            var libsslPath = procSelfMaps.Split(new string[]{ Environment.NewLine }, StringSplitOptions.None)
                             .Select(line => line.Split(' ').LastOrDefault()?.Trim())
                             .FirstOrDefault(path => !string.IsNullOrEmpty(path) && path.Contains("libssl.so"));

            if (!string.IsNullOrEmpty(libsslPath) &&
                NativeLibrary.TryLoad(libsslPath, assembly, searchPath, out var h))
            {
                return h;
            }

            Console.WriteLine($"error: Cannot resolve {name}.");
            Console.WriteLine();
            Console.WriteLine("Mapped files:");
            Console.WriteLine(procSelfMaps);
            Console.WriteLine();
            Console.WriteLine("libssl files in /usr/lib*:");
            try
            {
                foreach (var dir in Directory.GetDirectories("/usr", "lib*"))
                {
                    foreach (var file in Directory.GetFiles(dir, "libssl*"))
                    {
                        var info = new FileInfo(file);
                        if (info.LinkTarget != null)
                        {
                            string suffix = info.Exists ? "" : " (broken)";
                            Console.WriteLine($"  {file} -> {info.LinkTarget}{suffix}");
                        }
                        else
                        {
                            Console.WriteLine($"  {file}");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  (enumeration failed: {ex.Message})");
            }

            // On Mono, throwing an exception here gets swallowed, so do an application exit instead.
            Environment.Exit(1);
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
