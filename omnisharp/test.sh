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

mkdir hello
pushd hello
dotnet new console
popd

./omnisharp/run -s "$(readlink -f hello)" > omnisharp.log &
omnisharp_pid=$!

sleep 5

pkill -P $$

# Omnisharp spawns off a number of processes. They all include the
# current directory as a process argument, so use that to identify and
# kill them.
kill $(ps aux | grep "$(pwd)" | grep -v 'grep' | awk '{ print $2 }')

cat omnisharp.log

if grep ERROR omnisharp.log; then
    echo "test failed"
    exit 1
else
    echo "OK"
fi

popd
