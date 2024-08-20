using System.Security.Cryptography;
using System.Text;
using System.IO.Compression;

byte[] bytes = Encoding.UTF8.GetBytes("some bytes");

#if NO_DEPS

// No dependencies.

#elif DEP_CRYPTO

using (SHA256 mySHA256 = SHA256.Create())
{
    mySHA256.ComputeHash(bytes);
}

#elif DEP_ZLIB

using (var stream = new ZLibStream(new MemoryStream(), CompressionMode.Compress, leaveOpen: false))
{
    stream.Write(bytes);
}

#elif DEP_BROTLI

using (var stream = new BrotliStream(new MemoryStream(), CompressionMode.Compress, leaveOpen: false))
{
    stream.Write(bytes);
}

#else

#error "A preprocessor macro must be set to control the app dependencies."

#endif

Console.WriteLine("Success");