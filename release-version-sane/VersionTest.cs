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
            (List<string> publicSdkVersionsRaw, string publicRuntimeVersionRaw) = await upstream.GetLatestRelease(new HttpClient(), majorMinor);
            List<Version> publicSdkVersions = publicSdkVersionsRaw.Select(v => Normalize(v)).ToList();
            Version publicRuntimeVersion = Normalize(publicRuntimeVersionRaw);

            bool currentVersionNewerThanPublic = false;
            if ((publicRuntimeVersion != currentRuntimeVersion) && (currentRuntimeVersion.Build > 0))
            {
                currentRuntimeVersion = new Version(currentRuntimeVersion.Major,
                                                    currentRuntimeVersion.Minor,
                                                    currentRuntimeVersion.Build - 1);
                Assert.Equal(currentRuntimeVersion, publicRuntimeVersion);
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
                if (sdk == currentSdkVersion)
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

            return Normalize(result
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

            return Normalize(result
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

        /// Normalize a version and remove parts that make it invalid. This includes 'preview' and 'rc' tags
        public static Version Normalize(string version)
        {
             return new Version(version.Split('-')[0]);
        }
    }
}
