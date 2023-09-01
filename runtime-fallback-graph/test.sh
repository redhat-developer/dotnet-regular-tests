#!/usr/bin/env bash

# Check runtime fallback graphs are present in the shared framework

set -euo pipefail
set -x

dotnet_dir="$(../dotnet-directory)"
portable_rid="$(../runtime-id --portable)"
non_portable_rid="$(../runtime-id)"

# print for  debugging
find "${dotnet_dir}" -iname Microsoft.NETCore.App.deps.json

while IFS= read -r -d '' file; do
    jq '.runtimes' "$file"
    length=$(jq '.runtimes | length' "$file")
    if [[ $length == 0 ]]; then
        echo "Missing .runtimes section in $file"
        exit 1
    fi
    # quoting here is a bit strange, but it's basically ".runtimes[\"" "$non_portable_rid" "\"] ..." without spaces
    length=$(jq ".runtimes[\"""$non_portable_rid""\"] | length" "$file")
    if [[ $length == 0 ]]; then
        echo "Missing runtimes[$non_portable_rid] section in $file"
        exit 1
    fi
    fallback_graph=$(jq ".runtimes[\"""$non_portable_rid""\"]" "$file")
    echo "$fallback_graph" | grep "$portable_rid"
    echo "$fallback_graph" | grep "linux"
    echo "$fallback_graph" | grep "unix"
    echo "$fallback_graph" | grep "base"
done < <(find "${dotnet_dir}" -iname Microsoft.NETCore.App.deps.json -print0)
