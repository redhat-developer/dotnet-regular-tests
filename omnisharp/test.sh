#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

set -x

rm -rf workdir
mkdir workdir
pushd workdir

runtime_id="$(../../runtime-id --portable)"

omnisharp_urls=(
    "https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-${runtime_id}-net6.0.tar.gz"
    "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.38.2/omnisharp-${runtime_id}.tar.gz"
    "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.37.17/omnisharp-${runtime_id}.tar.gz"
)

IFS='.-' read -ra version_split <<< "$1"

if [[ "${version_split[0]}" == "7" ]]; then
    echo "warning: OmniSharp is known to be broken for .NET 7. Skipping."
    exit 0
fi

function run_omnisharp_against_projects
{
    for project in blazorserver blazorwasm classlib console mstest mvc nunit web webapp webapi worker xunit ; do

        rm -rf hello-$project
        mkdir hello-$project
        pushd hello-$project
        dotnet new $project
        popd

        "$@" "$(readlink -f hello-$project)" > omnisharp.log &

        sleep 5

        pkill -P $$

        # Omnisharp can spawn off a number of processes. If so, they
        # will include the current directory as a process argument, so
        # use that to identify and kill them.
        pgrep -if omnisharp || true
        mapfile -t to_kill < <(pgrep -f "$(pwd)")
        if [[ "${#to_kill[@]}" -gt 0 ]] ; then
            kill "${to_kill[@]}"
        fi

        cat omnisharp.log

        if grep ERROR omnisharp.log; then
            echo "test failed"
            exit 1
        else
            echo "OK"
        fi
    done
}

function ldd-okay
{
    file=$1
    if [[ "$(ldd "$file" 2>&1 >/dev/null | wc -l )" -gt 0 ]]; then
        return 1
    fi
    if ldd "$file" 2>&1 | grep -F 'not found'; then
        return 1
    fi
    return 0
}

for download_url in "${omnisharp_urls[@]}"; do
    tarball=$(basename "$download_url")
    rm -f "$tarball"
    rm -rf omnisharp

    if [[ $(uname -m) == "aarch64" ]] && [[ "$download_url" = *"/v1.37.17/"* ]]; then
        echo "OmniSharp v1.37.17 is not available for arm64/aarch64"
        continue
    fi

    if [[ "${version_split[0]}" -lt 6 ]] && [[ "$download_url" = *"net6.0"* ]]; then
        echo "Skipping .NET 6 build of OmniSharp on .NET ${version_split[0]}.${version_split[1]}"
        continue
    fi

    wget --no-verbose "$download_url"

    mkdir omnisharp
    pushd omnisharp
    tar xf "../$tarball"
    if [ -f "omnisharp/bin/mono" ]; then
        if ! ldd-okay omnisharp/bin/mono; then
            echo "This version of mono is incompatible. Skipping."
            continue
        fi
        run_omnisharp_against_projects omnisharp/bin/mono
    elif [ -f "run" ]; then
        if ! ldd-okay bin/mono; then
            echo "This version of mono is incompatible. Skipping."
            continue
        fi
        run_omnisharp_against_projects ./run
    elif [ -f "OmniSharp" ]; then
        # This uses the system .NET installation, and has no bundled/required
        # mono or other libraries
        run_omnisharp_against_projects ./OmniSharp
    else
        echo "Unable to find Omnisharp"
        find . | sort -u
        false
    fi
    popd
done
