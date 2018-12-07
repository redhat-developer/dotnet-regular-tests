#!/bin/bash

set -euo pipefail
set -x

mkdir bin
cd bin

dotnet new console
dotnet publish -r linux-x64 --self-contained false
./bin/Debug/netcoreapp3.0/linux-x64/publish/bin
