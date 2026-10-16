#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

dotnet_dir=$(dirname "$(readlink -f "$(command -v dotnet)")")
echo "Found .NET at $dotnet_dir"

errors=0

# The SharedFramework SDK intentionally generates each runtime pack's framework
# .deps.json and .runtimeconfig.json at runtimes/<rid>/lib/<tfm>.
# See https://github.com/dotnet/arcade/pull/5714
# Allow only those known files in that layout; other JSON files in packs are unexpected.
bad_json_files=()
while IFS= read -r -d '' json_file; do
    relative_path=${json_file#"$dotnet_dir/packs/"}
    if [[ ! $relative_path =~ ^Microsoft\.NETCore\.App\.Runtime(\.NativeAOT)?\.[^/]+/[^/]+/runtimes/[^/]+/lib/net[^/]+/Microsoft\.NETCore\.App\.(deps|runtimeconfig)\.json$ &&
          ! $relative_path =~ ^Microsoft\.AspNetCore\.App\.Runtime\.[^/]+/[^/]+/runtimes/[^/]+/lib/net[^/]+/Microsoft\.AspNetCore\.App\.(deps|runtimeconfig)\.json$ ]]; then
        bad_json_files+=("$json_file")
    fi
done < <(find "$dotnet_dir/packs" -iname '*.json' -print0)

if [[ ${#bad_json_files[@]} -gt 0 ]]; then
    echo "error: found unexpected json files in $dotnet_dir/packs"
    printf '%s\n' "${bad_json_files[@]}"
    errors=1
fi

debug_lines=$(find "$dotnet_dir/packs" -iname 'Debug' | wc -l)
if [[ $debug_lines -gt 0 ]]; then
    echo "error: found some Debug files in $dotnet_dir/packs"
    find "$dotnet_dir/packs" -iname 'Debug'
    errors=1
fi

if [[ $errors -gt 0 ]]; then
    exit 1
fi
