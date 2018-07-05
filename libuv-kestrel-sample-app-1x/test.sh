#!/usr/bin/env bash

source ../../common.sh

rm -f project.json
if [ "x$1" = "x1.0" ]; then
  cp project10.json project.json
elif [ "x$1" = "x1.1" ]; then
  cp project11.json project.json
fi

initialize

step dotnet restore
step dotnet build
background-step dotnet run
step sleep 15
step curl "http://localhost:5000"

finish
