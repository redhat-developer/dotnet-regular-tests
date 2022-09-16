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
PUBLISHED_FILE_COUNT=$(ls ./bin/Debug/net*/*/publish | wc -l)
if [ "$PUBLISHED_FILE_COUNT" != "1" ]; then
    echo "FAIL: published NativeAot app contains more than 1 file."
    exit 1
fi

# Verify the application runs successfully.
if ! ./bin/Debug/net*/*/publish/console; then
    echo "FAIL: NativeAot console application failed to run."
    exit 1
fi

echo "PASS: NativeAot app builds and runs."
