#!/bin/bash

set -euo pipefail

# Check Microsoft.AspNetCore.App's version matches that of Microsoft.NETCore.App

runtime_version=$(dotnet --info  | grep '  Microsoft.NETCore.App' | awk '{ print $2 }' | sort -rh | head -1)
echo "Latest runtime version: $runtime_version"

runtime_version_major_minor=$(echo "$runtime_version" | cut -d'.' -f-2)
echo "Latest runtime major/mior version: $runtime_version_major_minor"

aspnetcore_runtime_version=$(dotnet --info  | grep '  Microsoft.AspNetCore.App' | awk '{ print $2 }' | sort -rh | head -1)
echo "Latest ASP.NET Core runtime version: $aspnetcore_runtime_version"

# If these are pre-release versions, they need normalization
if [[ $runtime_version == *preview* ]] || [[ $runtime_version == *rc* ]] ; then
    runtime_version=$(echo $runtime_version | sed -E 's#(preview[0-9]*|rc[0-9]*).*#\1#')
    aspnetcore_runtime_version=$(echo $aspnetcore_runtime_version | sed -E 's#(preview[0-9]*|rc[0-9]*).*#\1#')
fi

if [[ $runtime_version == $aspnetcore_runtime_version ]]; then
    echo "Runtime version $runtime_version and ASP.NET Core version $aspnetcore_runtime_version match."
    echo OK
else
    echo "error: Runtime version $runtime_version and ASP.NET Core version $aspnetcore_runtime_version don't match."
    exit 1
fi
