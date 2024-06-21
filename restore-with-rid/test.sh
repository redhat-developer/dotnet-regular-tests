#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

dotnet new console --no-restore
dotnet restore -r "$(../runtime-id --sdk)"
