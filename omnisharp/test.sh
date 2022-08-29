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

IFS='.' read -ra version_split <<< "$1"

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
        pgrep -if omnisharp
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

for download_url in "${omnisharp_urls[@]}"; do
    tarball=$(basename "$download_url")
    rm -f "$tarball"
    rm -rf omnisharp
    wget --no-verbose "$download_url"

    if [[ "${version_split[0]}" -lt 6 ]] && [[ "$download_url" = *"net6.0"* ]]; then
        echo "Skipping .NET 6 build of OmniSharp on .NET ${version_split[0]}.${version_split[1]}"
        continue
    fi

    mkdir omnisharp
    pushd omnisharp
    tar xf "../$tarball"
    if [ -f "omnisharp/bin/mono" ]; then
        if [[ "$(ldd omnisharp/bin/mono 2>&1 >/dev/null | wc -l )" -gt 0 ]]; then
            echo "This version of mono is incompatible. Skipping."
            continue
        fi
        run_omnisharp_against_projects omnisharp/bin/mono
    elif [ -f "run" ]; then
        if [[ "$(ldd bin/mono 2>&1 >/dev/null | wc -l )" -gt 0 ]]; then
            echo "This version of mono is incompatible. Skipping."
            continue
        fi
        run_omnisharp_against_projects ./run
    elif [ -f "OmniSharp" ]; then
        run_omnisharp_against_projects ./OmniSharp
    else
        echo "Unable to find Omnisharp"
        find . | sort -u
        false
    fi
    popd
done
