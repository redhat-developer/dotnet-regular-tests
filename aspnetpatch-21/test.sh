#!/bin/bash

set -e
set -x

# Ensure we have an up-to-date value for latest_aspnet_package.
dotnet_version=$(dotnet --version)
dotnet_version_patch=${dotnet_version##*.}
latest_known_patch=401
if [[ "$dotnet_version_patch" -le "$latest_known_patch" ]]; then
  latest_aspnet_package=2.1.3
else
  echo "Unknown dotnet version ($dotnet_version), please update latest_known_patch and latest_aspnet_package."
  exit 1
fi

# On RHEL, older sdks are aware of the latest ASP.NET Core version
# by setting LatestPatchVersionForAspNetCore{App,All}2_1 in the scl.
# On other OSes, only the latest sdk is aware of the latest ASP.NET Core version.
sdks=$(dotnet --list-sdks | awk '{print $1}' | sort -ur)
if [[ `grep "Red Hat Enterprise Linux" /etc/redhat-release` ]]; then
  if [ "$LatestPatchVersionForAspNetCoreApp2_1" != "$latest_aspnet_package" ]; then
    echo "LatestPatchVersionForAspNetCoreApp2_1 is not set to the latest ASP.NET Core version."
    exit 1
  fi
  if [ "$LatestPatchVersionForAspNetCoreAll2_1" != "$latest_aspnet_package" ]; then
    echo "LatestPatchVersionForAspNetCoreAll2_1 is not set to the latest ASP.NET Core version."
    exit 1
  fi
else
  sdks=(${sdks[0]})
fi

test_folder=testapp

function create_project_for_sdk_and_package()
{
  local sdk=$1
  local package=$2

  # create folder
  rm -rf $test_folder
  mkdir $test_folder

  # global.json file
  cat >$test_folder/global.json <<EOF
{
  "sdk": {
    "version": "$sdk"
  }
}
EOF

  # csproj file
  cat >$test_folder/testapp.csproj <<EOF
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>netcoreapp2.1</TargetFramework>
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

# Verify each sdk uses the latest ASP.NET Core App/All package
for sdk in "$sdks"; do
  for package in Microsoft.AspNetCore.App Microsoft.AspNetCore.All; do

    # create project folder
    create_project_for_sdk_and_package $sdk $package

    # publish application
    cd $test_folder
    dotnet publish -o out

    # read the package version
    package_version=$(cat out/*.deps.json | jq -r '.targets[".NETCoreApp,Version=v2.1"]["testapp/1.0.0"].dependencies["'$package'"]')

    # cleanup folder
    cd ..
    rm -rf $test_folder

    # check package version
    if [ "$package_version" == "$latest_aspnet_package" ]; then
      echo -e "\n==================="
      echo "SDK $sdk uses latest $package PASS"
      echo -e "===================\n"
    else
      echo "SDK $sdk uses latest $package FAIL"
      exit 1
    fi

  done # package
done # sdk

# Verify we can override the version used by the SDK using an envvar.
for sdk in "$sdks"; do
  for package in Microsoft.AspNetCore.App Microsoft.AspNetCore.All; do

    # create project folder
    create_project_for_sdk_and_package $sdk $package

    # restore application
    cd $test_folder
    restore_return=0
    if [ "$package" == "Microsoft.AspNetCore.App" ]; then
      LatestPatchVersionForAspNetCoreApp2_1=9.9.9 dotnet restore || restore_return=$? && true
    else # Microsoft.AspNetCore.All
      LatestPatchVersionForAspNetCoreAll2_1=9.9.9 dotnet restore || restore_return=$? && true
    fi

    # cleanup folder
    cd ..
    rm -rf $test_folder

    # verify restore failed
    if [ "$restore_return" -ne "0" ]; then
      echo -e "\n==================="
      echo "SDK $sdk reads $package version from environment PASS"
      echo -e "===================\n"
    else
      echo "SDK $sdk reads $package version from environment FAIL"
      exit 1
    fi

  done # package
done # sdk
