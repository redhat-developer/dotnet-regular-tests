#!/usr/bin/env bash

set -euo pipefail

for TEST_RESULT in pass fail ;
do
  export TEST_RESULT
  EXIT_CODE=0
  OUTPUT=$(dotnet test 2>&1) || EXIT_CODE=$?
  if [[ ( "$TEST_RESULT" == "pass" && "$EXIT_CODE" != "0" ) \
     || ( "$TEST_RESULT" == "fail" && "$EXIT_CODE" == "0" ) ]] ; then
    echo "$OUTPUT"
    echo "xunit tests can $TEST_RESULT: FAIL"
    exit 1
  fi
  echo "xunit tests can $TEST_RESULT: PASS"
done
