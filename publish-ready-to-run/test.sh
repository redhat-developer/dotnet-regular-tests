#!/usr/bin/env bash

set -euo pipefail
set -x

dotnet new console --no-restore
dotnet publish -r "$(../runtime-id)" /p:PublishReadyToRun=true
