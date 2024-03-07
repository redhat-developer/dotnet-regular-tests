using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

bool sha1RsaSignatureOnLastElementInChain = false;

HttpClientHandler handler = new HttpClientHandler { 
    CheckCertificateRevocationList = true,
    ServerCertificateCustomValidationCallback = ServerCertificateCustomValidation, 
};

using HttpClient client = new HttpClient(handler);

try
{
    HttpResponseMessage response = await client.GetAsync("https://redhat.com");

    string responseBody = await response.Content.ReadAsStringAsync();
    if (!sha1RsaSignatureOnLastElementInChain)
    {
        Console.WriteLine("FAIL");
        Console.WriteLine("The certificate chain that is validated is no longer using an RSA1 signature.");
        Console.WriteLine("The test must be updated to use a different host.");
        return 1;
    }
    Console.WriteLine("PASS");
    return 0;
}
catch (Exception e)
{
    Console.WriteLine("\nException Caught!");
    Console.WriteLine(e);
}

Console.WriteLine("FAIL");
return 1;

bool ServerCertificateCustomValidation(HttpRequestMessage requestMessage, X509Certificate2? certificate, X509Chain? chain, SslPolicyErrors sslErrors)
{
    foreach (var element in chain!.ChainElements)
    {
        var cert = element.Certificate;
        Console.WriteLine($"{cert.SubjectName.Name} {cert.SignatureAlgorithm.FriendlyName}");
    }
    if ( chain.ChainElements.Last().Certificate.SignatureAlgorithm.FriendlyName != "sha1RSA" )
    {
        sha1RsaSignatureOnLastElementInChain = true;
    }

    Console.WriteLine($"Errors: {sslErrors}");
    return sslErrors == SslPolicyErrors.None;
}