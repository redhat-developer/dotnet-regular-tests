#!/usr/bin/env bash

# Verify that the bundled SDK tools can execute.

set -euo pipefail
IFS=$'\n\t'
set -x

# Maps a tool name to some output that is expected to be in the output when invoked with '--help'.
declare -A tools=(
  [dev-certs]="Usage: dotnet dev-certs"
  [format]="Formats code"
  [user-jwts]="Usage: dotnet user-jwts"
  [user-secrets]="Usage: dotnet user-secrets"
  [watch]="dotnet watch"
)

failed=0

for tool in "${!tools[@]}"; do
  expected="${tools[$tool]}"

  # Ignore the exit code because 'dotnet user-secrets' has a non-zero exit for '--help'.
  output=$(dotnet "${tool}" --help 2>&1) || true

  if echo "${output}" | grep -q "${expected}"; then
    echo "PASS: dotnet ${tool} --help"
  else
    echo "FAIL: dotnet ${tool} --help did not contain '${expected}'"
    echo "Output was: ${output}"
    failed=1
  fi
done

exit "${failed}"
