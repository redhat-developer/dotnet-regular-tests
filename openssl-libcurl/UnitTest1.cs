using System;
using Xunit;
using System.Net.Http;

namespace openssl_libcurl
{
    public class UnitTest1
    {
        [Fact]
        public void Test1()
        {
            HttpClient hc = new HttpClient(new HttpClientHandler { ClientCertificateOptions = ClientCertificateOption.Automatic });
            Assert.NotEmpty(hc.GetStringAsync("https://httpbin.org/ip").GetAwaiter().GetResult());
        }
    }
}
