#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

# Clear nuget sources to use the bundled runtime.
cat > nuget.config <<EOF
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
  </packageSources>
</configuration>
EOF

runtime_id="$(../runtime-id --sdk)"

url="http://localhost:5000"

dir=web
output_dir=output
rm -rf "$dir" "$output_dir"
dotnet new web --no-restore -o "$dir"
dotnet publish --sc -r "$runtime_id" -o "$output_dir" /p:UsingMicrosoftNETSdkRazor=false /p:ScopedCssEnabled=false "$dir"

ASPNETCORE_URLS="$url" "./$output_dir/web" &
run_pid=$!
trap "kill $run_pid && wait $run_pid" EXIT


if ! ../run-until-success-with-backoff curl "$url" ; then
  echo 'FAIL: ASP.NET app failed to respond'
  exit 2
fi

echo "PASS"
