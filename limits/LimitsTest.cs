using System.Diagnostics;
using System.Globalization;
using Xunit;

namespace Limit;

public class LimitsTest
{
    [Fact]
    public void FileDescriptorLimitIsAtMax()
    {
        int softLimit = int.Parse(RunAndGetProcessOutput("ulimit", new List<string> { "-Sn" }), CultureInfo.InvariantCulture);
        int hardLimit = int.Parse(RunAndGetProcessOutput("ulimit", new List<string> { "-Hn" }), CultureInfo.InvariantCulture);

        Assert.True(hardLimit == softLimit, $"File descriptor soft limit ({softLimit}) should be the same as the hard limit ({hardLimit}).");
    }

    private static string RunAndGetProcessOutput(string name, List<string> args)
    {
        ProcessStartInfo psi = new()
        {
            FileName = name,
            RedirectStandardOutput = true,
        };
        foreach (string arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        Process? p = Process.Start(psi);
        if (p is not null)
        {
            p.WaitForExit();
            return p.StandardOutput.ReadToEnd();
        }
        else
        {
            throw new InvalidOperationException();
        }
    }
}
