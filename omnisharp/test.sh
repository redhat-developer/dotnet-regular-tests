#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

set -x

rm -rf workdir
mkdir workdir
pushd workdir

runtime_id="$(../../runtime-id --portable)"

# disabled for alpine
[ -z "${runtime_id##*musl*}" ] && { echo No musl release of omnisharp, disabled; exit 0; }

wget --no-verbose "https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-${runtime_id}.tar.gz"

mkdir omnisharp
pushd omnisharp
tar xf "../omnisharp-${runtime_id}.tar.gz"
popd

if [[ "$(ldd omnisharp/bin/mono 2>&1 >/dev/null | wc -l )" -gt 0 ]]; then
    echo "This version of mono is incompatible. Falling back."
    rm -r "omnisharp-${runtime_id}.tar.gz"
    rm -r omnisharp

    wget --no-verbose "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.37.17/omnisharp-${runtime_id}.tar.gz"

    mkdir omnisharp
    pushd omnisharp
    tar xf "../omnisharp-${runtime_id}.tar.gz"
    popd

    if [[ "$(ldd omnisharp/bin/mono 2>&1 >/dev/null | wc -l )" -gt 0 ]]; then
        echo "error: Can't find a compatible version of mono. Please update the test."
        exit 100
    fi
fi


for project in blazorserver blazorwasm classlib console mstest mvc nunit web webapp webapi worker xunit ; do

    mkdir hello-$project
    pushd hello-$project
    dotnet new $project
    popd

    ./omnisharp/run -s "$(readlink -f hello-$project)" > omnisharp.log &

    sleep 5

    pkill -P $$

    # Omnisharp spawns off a number of processes. They all include the
    # current directory as a process argument, so use that to identify and
    # kill them.
    pgrep -f "$(pwd)"

    kill "$(pgrep -f "$(pwd)")"

    cat omnisharp.log

    if grep ERROR omnisharp.log; then
        echo "test failed"
        exit 1
    else
        echo "OK"
    fi

done

popd
