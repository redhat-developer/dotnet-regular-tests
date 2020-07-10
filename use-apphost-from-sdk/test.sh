#!/usr/bin/bash

set -euo pipefail
IFS=$'\n\t'

rm -rf console
mkdir console
pushd console

# Verify that the apphost from the SDK is usable and nuget is not
# needed for building a HelloWorld console application.

cat > nuget.config <<EOF
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
  </packageSources>
</configuration>
EOF

dotnet new console
dotnet build --no-restore
netcoreapp=( bin/Debug/net* )
"${netcoreapp[0]}"/console

popd
