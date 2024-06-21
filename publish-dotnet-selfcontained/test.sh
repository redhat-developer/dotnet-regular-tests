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

dir=console
output_dir=output
rm -rf "$dir" "$output_dir"
dotnet new console -o "$dir"
dotnet publish --sc -r "$runtime_id" -o "$output_dir" "$dir" 
"./$output_dir/console"

echo "PASS"
