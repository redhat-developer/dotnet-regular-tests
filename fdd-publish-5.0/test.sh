#!/usr/bin/bash

set +x

# create csproj
  cat <<EOF >fdd-publish.csproj
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>netcoreapp5.0</TargetFramework>
  </PropertyGroup>
</Project>
EOF

  # nuget.config  - clear nuget source
  cat <<EOF >nuget.config
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
  </packageSources>
</configuration>
EOF

dotnet publish