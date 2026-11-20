#!/usr/bin/env bash

# Verify that the runtime writes a crash dump when an ASP.NET Core
# application crashes.
#
# The dump is requested through the runtime's documented configuration
# (DOTNET_DbgEnableMiniDump and friends) and written by whichever dump
# implementation the runtime ships.

# Enable "unofficial bash strict mode"
set -euo pipefail
IFS=$'\n\t'
set -x

dotnet new web --no-restore --force

# Crash the application once it is fully started. Environment.FailFast takes
# the runtime's abort path, which writes the dump before the process exits.
cat > Program.cs <<'EOF'
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello World!");

app.Lifetime.ApplicationStarted.Register(() => Environment.FailFast("runtime-crash-dumps test"));

app.Run();
EOF

# Do not kick off compiler servers that hang around after a build
dotnet build -p:UseRazorBuildServer=false -p:UseSharedCompilation=false /p:UsingMicrosoftNETSdkRazor=false /p:ScopedCssEnabled=false /m:1

app_dll=$(find bin/Debug -name 'runtime-crash-dumps.dll' -print -quit)
test -f "${app_dll}"

rm -f coredump.*

# Ask the runtime to write a crash dump when the application crashes.
export DOTNET_DbgEnableMiniDump=1
export DOTNET_DbgMiniDumpType=1
export DOTNET_DbgMiniDumpName="$(pwd)/coredump.%p"

# The application aborts, so a non-zero exit code is expected. The timeout
# prevents a hang if the crash (or the dump) never happens.
set +e
timeout 120s dotnet "${app_dll}" --urls http://127.0.0.1:0 > app.log 2>&1
app_result=$?
set -e
cat app.log

if [ ${app_result} -eq 0 ]; then
    echo "FAIL: application exited successfully instead of crashing"
    exit 1
fi

mapfile -t dump_files < <(ls coredump.* 2>/dev/null || true)
if [ "${#dump_files[@]}" -ne 1 ]; then
    echo "FAIL: expected one crash dump file, found ${#dump_files[@]}"
    exit 1
fi
dump_file=${dump_files[0]}

test -s "${dump_file}"
file "${dump_file}"
file "${dump_file}" | grep -F "core file"

echo "PASS: runtime created ${dump_file}"
