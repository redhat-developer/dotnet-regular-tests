#!/usr/bin/env bash

set -euo pipefail
set -x

dotnet new console --no-restore
dotnet restore -r "$(../runtime-id)"
