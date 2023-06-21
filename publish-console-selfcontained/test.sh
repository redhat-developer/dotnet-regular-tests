#!/usr/bin/env bash

set -euo pipefail
set -x

runtime_id="$(../runtime-id)"

dir=console
output_dir=output
rm -rf "$dir" "$output_dir"
dotnet new console -o "$dir"
dotnet publish --sc -r "$runtime_id" -o "$output_dir" "$dir" 
"./$output_dir/console"

echo "PASS"