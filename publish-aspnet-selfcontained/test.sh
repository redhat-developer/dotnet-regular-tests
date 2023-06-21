#!/usr/bin/env bash

set -euo pipefail
set -x

runtime_id="$(../runtime-id)"

url="http://localhost:5000"

dir=web
output_dir=output
rm -rf "$dir" "$output_dir"
dotnet new web -o "$dir"
dotnet publish --sc -r "$runtime_id" -o "$output_dir" "$dir" 

ASPNETCORE_URLS="$url" "./$output_dir/web" &
run_pid=$!
trap "kill $run_pid && wait $run_pid" EXIT

sleep 5

if ! curl "$url"; then
  echo 'FAIL: ASP.NET app failed to respond'
  exit 2
fi

echo "PASS"