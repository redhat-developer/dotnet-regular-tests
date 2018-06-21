#!/bin/bash

helpPages=$(dotnet --help | grep -A 999 'SDK commands' | grep -B 999 'Common options' | awk 'NR>1 {print $1}' | head -n-2)
manPages=$(rpm -qd $(rpm -qa | grep 'rh-dotnet') | grep 'man1/dotnet-')

for page in $helpPages;
do
  echo "$manPages" | grep "$page"
  if [ $? -eq 1 ]; then
    echo "Man page for dotnet-$page not found: FAIL"
    exit 1
  fi
  echo $'\n'
done

echo "All the man pages were found: PASS"

