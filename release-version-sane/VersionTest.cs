using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Linq;
using System.Threading.Tasks;
using System.Diagnostics;
using Xunit;

namespace ReleaseVersionSane
{
    public class VersionTest
    {
        [Fact]
        public async Task VersionIsSane()
        {
            var upstream = new UpstreamRelease();
            var currentRuntimeVersion = GetRuntimeVersion();
            var currentSdkVersion = GetSdkVersion();

            string majorMinor = $"{currentRuntimeVersion.Major}.{currentRuntimeVersion.Minor}";
            (List<string> publicSdkVersions, string publicRuntimeVersion) = await upstream.GetLatestRelease(new HttpClient(), majorMinor);

            bool currentVersionNewerThanPublic = false;

            if (publicRuntimeVersion != currentRuntimeVersion.ToString())
            {
                currentRuntimeVersion = new Version(currentRuntimeVersion.Major,
                                                    currentRuntimeVersion.Minor,
                                                    currentRuntimeVersion.Build - 1);
                Assert.Equal(currentRuntimeVersion.ToString(), publicRuntimeVersion);
                currentVersionNewerThanPublic = true;
            }

            if (currentVersionNewerThanPublic)
            {
                currentSdkVersion = new Version(currentSdkVersion.Major,
                                                currentSdkVersion.Minor,
                                                currentSdkVersion.Build - 1);
            }

            bool sdkMatched = false;
            foreach (var sdk in publicSdkVersions)
            {
                if (sdk == currentSdkVersion.ToString())
                {
                    sdkMatched = true;
                    break;
                }
            }

            Assert.True(sdkMatched);
        }

        private Version GetRuntimeVersion()
        {
            int exitCode = RunProcessAndGetOutput(new string[] { "dotnet" , "--list-runtimes" }, out string result);
            if (exitCode != 0)
            {
                return null;
            }

            return new Version(result
                              .Split(Environment.NewLine)
                              .Where(line => line.StartsWith("Microsoft.NETCore.App "))
                              .Select(line => line.Split(' ')[1])
                              .First());

        }

        private Version GetSdkVersion()
        {
            int exitCode = RunProcessAndGetOutput(new string[] { "dotnet" , "--list-sdks" }, out string result);
            if (exitCode != 0)
            {
                return null;
            }

            return new Version(result
                              .Split(Environment.NewLine)
                              .Select(line => line.Split(' ')[0])
                              .First());

        }


        private static int RunProcessAndGetOutput(string[] processAndArguments, out string standardOutput)
        {
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = processAndArguments[0];
            startInfo.Arguments = string.Join(" ", processAndArguments.Skip(1));
            startInfo.RedirectStandardOutput = true;

            using (Process p = Process.Start(startInfo))
            {
                p.WaitForExit();
                using (StreamReader r = p.StandardOutput)
                {
                    standardOutput = r.ReadToEnd();
                }
                return p.ExitCode;
            }
        }

    }
}
