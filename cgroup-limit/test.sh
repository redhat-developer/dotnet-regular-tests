#!/bin/bash

set -euo pipefail

set -x

cat /proc/self/mountinfo

cat /proc/self/cgroup

dotnet publish

SYSTEMD_RUN="systemd-run"
if [ "$UID" != "0" ]; then
  if ! grep -q "cpu" "/sys/fs/cgroup/user.slice/user-$UID.slice/user@$UID.service/cgroup.controllers" ; then
    # user can't set cpu limits, use sudo.
    SYSTEMD_RUN="sudo -n $SYSTEMD_RUN"
  else
    # run on behalf of user.
    SYSTEMD_RUN="$SYSTEMD_RUN --user"
  fi
fi

mapfile -t DOTNET_LIMITS < <($SYSTEMD_RUN  -q --scope -p CPUQuota=100% -p MemoryLimit=100M bin/Debug/net*/cgroup-limit)

if [ "${DOTNET_LIMITS[0]}" == "Limits:" ] &&      # Application ran.
   [ "${DOTNET_LIMITS[1]}" == "1" ] &&            # Available processors is 1.
   [ "${DOTNET_LIMITS[2]}" -lt 100000000 ]; then  # Available memory less is than 100M.
  echo ".NET Runtime uses cgroup limits PASS"
  exit 0
fi

printf 'error: unexpected limits: %s\n' "${DOTNET_LIMITS[@]}"
echo ".NET Runtime uses cgroup limits FAIL"
exit 1
