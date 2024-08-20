#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

RID_ARG="/p:RuntimeIdentifier=$(../runtime-id --sdk)"

# Depending on the code used by the program, different native libraries are needed.
# We compile different programs to test if those native libraries are found.
# Some native libraries (like libunwind and rapidjson) are always needed. Consequently, each program check those.

for DEPENDENCY in NO_DEPS DEP_CRYPTO DEP_ZLIB DEP_BROTLI
do
    echo "Testing NativeAOT with $DEPENDENCY"

    rm -rf bin obj

    # Publish the app.
    if ! dotnet publish $RID_ARG /p:DefineConstants=$DEPENDENCY /p:PublishAot=true; then
        echo "FAIL: failed to publish application using NativeAot."
        exit 1
    fi

    # Verify the published output contains a single file.
    PUBLISHED_FILE_COUNT=$(ls ./bin/*/net*/*/publish | grep -v console.dbg | wc -l)
    if [ "$PUBLISHED_FILE_COUNT" != "1" ]; then
        echo "FAIL: published NativeAot app contains more than 1 file."
        exit 1
    fi

    # Verify the application runs.
    APP_OUTPUT="$(./bin/*/net*/*/publish/console 2>&1)"
    if [ "$APP_OUTPUT" != "Success" ]; then
        echo "FAIL: NativeAot console application did not have expected output."
        exit 1
    fi
done

echo "PASS: source-built NativeAot apps build and run."