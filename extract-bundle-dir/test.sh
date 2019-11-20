#!/bin/bash

# The profile file sets DOTNET_BUNDLE_EXTRACT_BASE_DIR to avoid multi-user issues.
# see: https://bugzilla.redhat.com/show_bug.cgi?id=1752350.
. /etc/profile.d/dotnet.sh

set -euo pipefail

# Verify DOTNET_BUNDLE_EXTRACT_BASE_DIR is set.
if [[ "$DOTNET_BUNDLE_EXTRACT_BASE_DIR" != "$HOME/.dotnet/bundle_extract_dir" ]]; then
    echo "error: DOTNET_BUNDLE_EXTRACT_BASE_DIR $DOTNET_BUNDLE_EXTRACT_BASE_DIR is not expected $HOME/.dotnet/bundle_extract_dir"
    exit 1
else
    echo "info: DOTNET_BUNDLE_EXTRACT_BASE_DIR is $DOTNET_BUNDLE_EXTRACT_BASE_DIR."
fi

APP_NAME=extract-bundle-app
APP_EXTRACT_DIR=$DOTNET_BUNDLE_EXTRACT_BASE_DIR/$APP_NAME

# Clean up the extract dir.
rm -rf $APP_EXTRACT_DIR

# Create a single file executable.
dotnet new console -o $APP_NAME
dotnet publish -r linux-x64 /p:PublishSingleFile=true $APP_NAME -o published

# Execute the single file, which will cause it to extract.
./published/$APP_NAME

# Verify the single file exe was extracted.
if [ -d "$APP_EXTRACT_DIR" ]; then
    echo "info: Application was extracted to expected location: $APP_EXTRACT_DIR"
    rm -rf $APP_EXTRACT_DIR
else
    echo "error: Application was not found at expected location: $APP_EXTRACT_DIR"
    exit 1
fi
