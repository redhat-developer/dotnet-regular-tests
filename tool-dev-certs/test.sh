#!/bin/bash


dotnet tool install dotnet-dev-certs
dotnet dev-certs

if [ $? -eq 1 ]; then
  echo "FAIL: dotnet tool not found"
  exit 1
fi

echo "PASS: dotnet tool dev-certs"

