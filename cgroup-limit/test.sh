#!/usr/bin/env bash

set -euo pipefail
set -x

runtime_id="$(../runtime-id)"

cat /proc/self/mountinfo

cat /proc/self/cgroup

if [[ "$(stat -f -c "%T" /sys/fs/cgroup)" == "cgroup2fs" ]] && [[ $(dotnet --version) == "3."* ]]; then
    echo "cgroup v2 is not fully supported on .NET Core 3.x. Skipping."
    exit 0
fi

# For mono-based runtimes (ppc64le, s390x), cgroup support is only functional
# on .NET 7.0 and later.
if [[ "$(uname -m)" == "s390x" ]] || [[ "$(uname -m)" == "ppc64le" ]] ; then
  IFS='.-' read -ra VERSION <<< "${1:-$(dotnet --version)}"
  if [[ "${VERSION[0]}" -lt "7" ]]; then
    echo "cgroup support is not available on Mono-based runtimes before .NET 7. Skipping."
    exit 0
  fi
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

    # Pass DOTNET_ROOT to support testing against a dotnet tarball.
    # On RHEL 7 we don't pass the envvar because systemd-run doesn't support '-E' yet and the envvar is passed by default.
    if [[ "$runtime_id" != "rhel.7"* ]]; then
       SYSTEMD_RUN="$SYSTEMD_RUN -E DOTNET_ROOT=$DOTNET_ROOT"
    fi
  else
    # run on behalf of user.
    SYSTEMD_RUN="$SYSTEMD_RUN --user"
  fi
fi

mapfile -t DOTNET_LIMITS < <($SYSTEMD_RUN  -q --scope -p CPUQuota=100% -p MemoryLimit=100M bin/Release/net*/cgroup-limit)

if [ "${DOTNET_LIMITS[0]}" == "Limits:" ] &&      # Application ran.
   [ "${DOTNET_LIMITS[1]}" == "1" ] &&            # Available processors is 1.
   [ "${DOTNET_LIMITS[2]}" -lt 100000000 ]; then  # Available memory less is than 100M.
  echo ".NET Runtime uses cgroup limits PASS"
  exit 0
fi

printf 'error: unexpected limits: %s\n' "${DOTNET_LIMITS[@]}"
echo ".NET Runtime uses cgroup limits FAIL"
exit 1
