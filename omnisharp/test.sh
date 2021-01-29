#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

set -x

rm -rf workdir
mkdir workdir
pushd workdir

runtime_id="$(../../runtime-id --portable)"

wget --no-verbose "https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-${runtime_id}.tar.gz"

mkdir omnisharp
pushd omnisharp
tar xf "../omnisharp-${runtime_id}.tar.gz"
popd

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
