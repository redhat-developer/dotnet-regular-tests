#!/usr/bin/env bash

set -euo pipefail

set -x

rm -rf bin obj

# Publish the app.
if ! dotnet publish --use-current-runtime /p:PublishAot=true; then
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
if [ "$APP_OUTPUT" != "Hello, World!" ]; then
    echo "FAIL: NativeAot console application did not have expected output."
    exit 1
fi

echo "PASS: NativeAot app builds and runs."
