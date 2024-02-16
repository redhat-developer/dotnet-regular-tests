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
            // This test is meant for release pipelines and verifies the version being built
            // either matches the upstream 'major.minor.patch' or 'major.minor.(patch + 1)'.

            string runtimeVersionRaw = GetRuntimeVersion();
            string sdkVersionRaw = GetSdkVersion();
            Version runtimeVersion = Normalize(runtimeVersionRaw);
            Version sdkVersion = Normalize(sdkVersionRaw);

            string majorMinor = $"{runtimeVersion.Major}.{runtimeVersion.Minor}";
            var upstream = new UpstreamRelease();
            (List<string> publicSdkVersionsRaw, string publicRuntimeVersionRaw) = await upstream.GetLatestRelease(new HttpClient(), majorMinor);
            List<Version> publicSdkVersions = publicSdkVersionsRaw.Select(v => Normalize(v)).ToList();
            Version publicRuntimeVersion = Normalize(publicRuntimeVersionRaw);

            Version publicRuntimeVersionNextPatch = new Version(publicRuntimeVersion.Major,
                                                                publicRuntimeVersion.Minor,
                                                                publicRuntimeVersion.Build + 1);
            bool matchesUpstream = runtimeVersion.Equals(publicRuntimeVersion);
            bool matchesUpstreamNext = runtimeVersion.Equals(publicRuntimeVersionNextPatch);
            Version expectedPublicSdkVersion = null;
            if (matchesUpstream)
            {
                expectedPublicSdkVersion = sdkVersion;
            }
            else if (matchesUpstreamNext)
            {
                expectedPublicSdkVersion = new Version(sdkVersion.Major,
                                                       sdkVersion.Minor,
                                                       sdkVersion.Build - 1);
            }

            Assert.True(matchesUpstream || matchesUpstreamNext, $"{runtimeVersionRaw} is not expected with public version {publicRuntimeVersionRaw}");
            Assert.NotNull(expectedPublicSdkVersion);
            Assert.Contains(expectedPublicSdkVersion, publicSdkVersions);
        }

        private string GetRuntimeVersion()
        {
            int exitCode = RunProcessAndGetOutput(new string[] { "dotnet" , "--list-runtimes" }, out string result);
            if (exitCode != 0)
            {
                return null;
            }

            return result.Split(Environment.NewLine)
                         .Where(line => line.StartsWith("Microsoft.NETCore.App "))
                         .Select(line => line.Split(' ')[1])
                         .First();
        }

        private string GetSdkVersion()
        {
            int exitCode = RunProcessAndGetOutput(new string[] { "dotnet" , "--list-sdks" }, out string result);
            if (exitCode != 0)
            {
                return null;
            }

            return result
                    .Split(Environment.NewLine)
                    .Select(line => line.Split(' ')[0])
                    .First();
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
