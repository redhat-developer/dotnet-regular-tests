#!/usr/bin/env bash

set -euo pipefail
set -x

runtime_id="$(../runtime-id)"

cat /proc/self/mountinfo

cat /proc/self/cgroup

CGROUPV2=false
if [[ "$(stat -f -c "%T" /sys/fs/cgroup)" == "cgroup2fs" ]] ; then
    CGROUPV2=true
fi

if [ -z "$(command -v systemctl)" ]; then
    echo "Environment does not use systemd"
    exit 0
fi

dotnet publish -c Release

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

# Pass DOTNET_ROOT to support testing against a dotnet tarball.
SYSTEMD_RUN="$SYSTEMD_RUN -E DOTNET_ROOT=${DOTNET_ROOT:-}"
# Unset DOTNET_PROCESSOR_COUNT so .NET won't return its value instead of the cgroup CPU limit.
SYSTEMD_RUN="$SYSTEMD_RUN -E DOTNET_PROCESSOR_COUNT="

memory_args="-p MemoryLimit=100M"
if [[ $CGROUPV2 == true ]]; then
    memory_args="-p MemoryMax=100M"
fi

mapfile -t DOTNET_LIMITS < <($SYSTEMD_RUN  -q --scope -p CPUQuota=100% $memory_args bin/Release/net*/cgroup-limit)

if [ "${DOTNET_LIMITS[0]}" == "Limits:" ] &&      # Application ran.
   [ "${DOTNET_LIMITS[1]}" == "1" ] &&            # Available processors is 1.
   [ "${DOTNET_LIMITS[2]}" -lt 100000000 ]; then  # Available memory less is than 100M.
  echo ".NET Runtime uses cgroup limits PASS"
  exit 0
fi

printf 'error: unexpected limits: %s\n' "${DOTNET_LIMITS[@]}"
echo ".NET Runtime uses cgroup limits FAIL"
exit 1
