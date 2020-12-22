using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace ReleaseVersionSane
{
    public class UpstreamRelease
    {
        private readonly Uri RELEASE_INDEX = new Uri("https://raw.githubusercontent.com/dotnet/core/master/release-notes/releases-index.json");

        public async Task<(List<string> sdks, string runtime)> GetLatestRelease(HttpClient client, string majorMinor)
        {
            var releaseIndexRawJson = await client.GetStringAsync(RELEASE_INDEX);
            var releaseInfoChannelJsonUrl = GetReleaseInfoChannelUrl(releaseIndexRawJson, majorMinor);
            if (releaseInfoChannelJsonUrl == null)
            {
                return (null, null);
            }

            var releaseInfoChannelRawJson = await client.GetStringAsync(releaseInfoChannelJsonUrl);
            return GetLatestVersion(releaseInfoChannelRawJson);
        }

        private (List<string> sdks, string runtime) GetLatestVersion(string releaseRawJson)
        {
            dynamic releaseChannel = JsonConvert.DeserializeObject(releaseRawJson);

            string runtime = null;
            var sdks = new List<string>();
            var latestDate = new DateTime(2000, 1, 1);

            foreach (var release in releaseChannel["releases"])
            {
                if (!DateTime.TryParse((string)release["release-date"], out DateTime releaseDate))
                {
                    continue;
                }

                if (releaseDate > latestDate)
                {
                    latestDate = releaseDate;
                    runtime = release["runtime"]["version"];
                    sdks = new List<string>();
                    foreach (var sdk in release["sdks"])
                    {
                        sdks.Add((string)sdk["version"]);
                    }
                }
            }

            return (sdks, runtime);
        }

        private Uri GetReleaseInfoChannelUrl(string releaseIndexRawJson, string majorMinor)
        {
            dynamic releaseIndex = JsonConvert.DeserializeObject(releaseIndexRawJson);

            string releaseChannelJsonUrl = null;
            foreach (var release in releaseIndex["releases-index"])
            {
                if (release["channel-version"] == majorMinor)
                {
                    releaseChannelJsonUrl = release["releases.json"];
                    break;
                }
            }

            return new Uri(releaseChannelJsonUrl);
        }

    }
}
