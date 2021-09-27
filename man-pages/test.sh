#!/bin/bash

set -euo pipefail

helpPages=$(dotnet --help | grep -A 999 'SDK commands' | grep '^  ' | awk '{ print $1 }')
manPages=$(rpm -qd $(rpm -qa | grep 'dotnet') | grep 'man1/dotnet-')

failed=0
for page in $helpPages; do
    if echo "$manPages" | grep "dotnet-$page"; then
        true
    else
        echo "error: Man page for dotnet-$page not found: FAIL"
        failed=1
    fi
done

if [[ $failed == 0 ]]; then
    echo "All the man pages were found: PASS"
else
    echo "FAIL: some man pages are missing"
fi

exit $failed
