using System;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using Xunit;

namespace DotNetCoreVersionApis
{
    public class VersionTest
    {
        [Fact]
        public void EnvironmentVersion()
        {
            var version = Environment.Version;
            Console.WriteLine($"Environment.Version: {version}");
            Assert.InRange(version.Major, 3, 5);
        }

        [Fact]
        public void RuntimeInformationFrameworkDescription()
        {
            var description = RuntimeInformation.FrameworkDescription;
            Console.WriteLine($"RuntimeInformation.FrameworkDescription: {description}");
            Assert.StartsWith(".NET", description);
        }

        [Theory]
        [InlineData("coreclr", typeof(object))]
        [InlineData("corefx", typeof(Uri))]
        public void CommitHashesAreAvailable(string repo, Type type)
        {
            Console.WriteLine($"Testing commit hashes for {repo}");

            var attributes = (AssemblyInformationalVersionAttribute[])type.Assembly.GetCustomAttributes(typeof(AssemblyInformationalVersionAttribute),false);
            var versionAttribute = attributes[0];
            Console.WriteLine($"AssemblyInformationVersionAttribute: {versionAttribute.InformationalVersion}");

            string[] versionParts = versionAttribute.InformationalVersion.Split("+");
            Assert.Equal(2, versionParts.Length);

            string fullVersion = versionParts[0];
            string plainVersion = fullVersion.Split("-")[0];

            Assert.Matches(new Regex("\\d+(\\.\\d)+"), plainVersion);

            bool okay = Version.TryParse(plainVersion, out Version parsedVersion);
            Assert.True(okay);
            Assert.InRange(parsedVersion.Major, 3, 5);

            var commitId = versionParts[1];
            Regex commitRegex = new Regex("[0-9a-fA-F]{40}");

            Assert.Matches(commitRegex, commitId);
        }
    }
}
