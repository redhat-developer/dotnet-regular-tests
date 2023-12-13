#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

PROJNAME=dotnettrace
FILENAME=dotnettrace.nettrace
SPEEDSCOPENAME=dotnettrace.speedscope.json
REPORTNAME=dotnettrace.nettrace.etlx

dotnet tool update -g dotnet-trace
export PATH="$HOME/.dotnet/tools:$PATH"

dotnet-trace collect -o $FILENAME -- dotnet new console --output $PROJNAME
if [ -f $FILENAME ]; then
   echo "collect - OK"
else
   echo "collect - FAIL"
   rm -r $PROJNAME
   exit 1
fi

if dotnet-trace ps; then
   echo "ps - OK"
else
   echo "ps - FAIL"
   rm -r $PROJNAME
   rm $FILENAME
   exit 1
fi

if dotnet-trace list-profiles; then
   echo "list-profiles - OK"
else
   echo "list-profiles - FAIL"
   rm -r $PROJNAME
   rm $FILENAME
   exit 1
fi

dotnet-trace convert $FILENAME --format Speedscope
if [ -f $SPEEDSCOPENAME ]; then
   echo "convert - OK"
else
   echo "convert - FAIL"
   rm -r $PROJNAME
   rm $FILENAME
   exit 1
fi 

output=$(dotnet-trace report $FILENAME topN)
if [[ $output == *"Missing Symbol"* ]]; then 
   echo "report - FAIL"
   rm -r $PROJNAME
   rm $FILENAME
   rm $SPEEDSCOPENAME
   rm $REPORTNAME
   exit 1
elif [[ $output == *"Top 5 Functions (Exclusive)"* ]]; then
   echo "report - OK"
else
   echo "report - FAIL"
   rm -r $PROJNAME
   rm $FILENAME
   rm $SPEEDSCOPENAME
   rm $REPORTNAME
   exit 1
fi


rm -r $PROJNAME
rm $FILENAME
rm $SPEEDSCOPENAME
rm $REPORTNAME