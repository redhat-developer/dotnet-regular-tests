#!/bin/bash

set -euo pipefail

SESSION_NAME=my-session
TEST_FOLDER=/tmp/$SESSION_NAME

TRACE_FOLDER=$TEST_FOLDER/trace
TRACE_EVENT=DotNETRuntime:RuntimeInformationStart

function remove_test_folder {
  rm -rf $TEST_FOLDER
}

function end_session {
  lttng stop $SESSION_NAME 2>/dev/null || true
  lttng destroy $SESSION_NAME 2>/dev/null || true
  killall lttng-sessiond 2>/dev/null || true
}

function start_session {
  # Start lttng user daemon
  lttng-sessiond --daemonize

  # Create and start session
  lttng create $SESSION_NAME --output $TRACE_FOLDER
  lttng add-context --userspace --session=$SESSION_NAME --type=vpid
  lttng enable-event -s $SESSION_NAME -u --tracepoint $TRACE_EVENT
  lttng start $SESSION_NAME
}

# Clean up from previous test run
end_session
remove_test_folder

# Start lttng session
echo "== Starting lttng session"
start_session

# Create new console application to generate an event
echo "== Creating new console application"
export COMPlus_PerfMapEnabled=1
export COMPlus_EnableEventLog=1
dotnet new console -o $TEST_FOLDER/console &
DOTNET_PID=$!
wait $DOTNET_PID

# End lttng session
echo "== Ending lttng session"
end_session

# Retrieve trace
LTTNG_TRACE=$(babeltrace "$TRACE_FOLDER/ust/uid/$(id -u)/64-bit" | grep "vpid = $DOTNET_PID")

# Clean up
remove_test_folder

echo "== Checking lttng trace"
if echo "$LTTNG_TRACE" | grep -q "$TRACE_EVENT"; then
  echo "OK: Event $TRACE_EVENT found in lttng trace."
  exit 0
else
  echo "FAIL: Event $TRACE_EVENT not found in lttng trace:"$'\n'"$LTTNG_TRACE"
  exit 1
fi
