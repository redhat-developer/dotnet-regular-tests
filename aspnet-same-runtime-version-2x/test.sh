#!/bin/bash

set -euo pipefail

# There's always a version of Microsoft.AspNetCore.App for each
# version of Microsoft.NetCore.App. Make sure this is true for us too.

runtime_version=$(dotnet --info  | grep '  Microsoft.NETCore.App' | awk '{ print $2 }' | sort -rh | head -1)
echo "Latest runtime version: $runtime_version"

runtime_version_major_minor=$(echo "$runtime_version" | cut -d'.' -f-2)
echo "Latest runtime major/mior version: $runtime_version_major_minor"

test_folder=testapp

function create_project_for_package()
{
  local package=$1

  # create folder
  rm -rf $test_folder
  mkdir $test_folder

  # csproj file
  cat >$test_folder/testapp.csproj <<EOF
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>netcoreapp${runtime_version_major_minor}</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="$package" />
  </ItemGroup>
</Project>
EOF

  # Program.cs file
  cat >$test_folder/Program.cs <<EOF
namespace testapp
{
    public class Program
    {
        public static void Main(string[] args) { }
    }
}
EOF
}

# Verify a matching version of ASP.NET Core App/All is used

#for package in Microsoft.AspNetCore.App Microsoft.AspNetCore.All; do
#We don't have .All leading to releases so this always fails.
for package in Microsoft.AspNetCore.App; do
  # create project folder
  create_project_for_package $package

  # publish application
  pushd $test_folder
  dotnet publish -o out

  # read the package version
  package_version=$(cat out/*.deps.json | jq -r '.targets[".NETCoreApp,Version=v'$runtime_version_major_minor'"]["testapp/1.0.0"].dependencies["'$package'"]')

  # cleanup folder
  popd
  rm -rf $test_folder

  # check package version
  if [[ "$package_version" == "$runtime_version" ]]; then
    echo -e "\n==================="
    echo "Runtime $runtime_version matches $package version $package_version PASS"
    echo -e "===================\n"
  else
    echo "error: Runtime $runtime_version does not match $package $package_version FAIL"
    exit 1
  fi

done # package
