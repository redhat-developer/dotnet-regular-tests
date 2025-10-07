#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

helpPages=$(dotnet --help | grep -A 999 'SDK commands' | grep -E -B 999 'Common options|Additional commands' | awk 'NR>1 {print $1}' | head -n-2)

RUNTIME_ID=$(../runtime-id)
case $RUNTIME_ID in
    alpine*)
        manPages=$(apk info -L dotnet-doc)
        ;;
    *)
        manPages=$(rpm -qd $(rpm -qa | grep 'dotnet') | grep 'man1/dotnet-')
        ;;
esac

function man_page_exists {
    local man_page=$1
    echo "$manPages" | grep "$man_page"
}

failed=0
for page in $helpPages; do

    found=0

    if man_page_exists "dotnet-$page"; then
        found=1
    fi

    # In .NET 10, the command is shown as 'solution'. sln is a working alias,
    # like older versions of .NET.  However, the man page is name 'sln'.
    if [[ $found == 0 ]] && [[ "$page" == solution ]]; then
        new_page=sln
        if man_page_exists "dotnet-$new_page"; then
            found=1
        fi
    fi

    # In man pages provided by .NET 10 (but visible to a .NET 8 or 9 SDK),
    # some commands like 'list' and 'remove' have a man page only present for
    # the longer form of the command such as 'dotnet package list'.
    if [[ $found == 0 ]] && { [[ "$page" == "add" ]] || [[ "$page" == "list" ]] || [[ "$page" == "remove" ]]; } ; then
        if man_page_exists "dotnet-package-$page"; then
            found=1
        fi
    fi

    if [[ $found == 0 ]]; then
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
