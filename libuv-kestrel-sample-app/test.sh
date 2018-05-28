#!/usr/bin/env bash

source ../../common.sh

initialize

step dotnet build
background-step dotnet run
step sleep 15
step curl "http://localhost:5000"

finish
