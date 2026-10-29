#!/usr/bin/env bash

# Check that libraries are declared correctly as bundled or are system-linked
#
# If a library must be system-linked, add it to required-system-libraries as
# well.

set -euo pipefail
IFS=$'\n\t'

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

discover_vmr_libraries() {
  local external_path=src/runtime/src/native/external

  echo "Cloning https://github.com/dotnet/dotnet.git at $branch"
  git clone --quiet --depth 1 --filter=blob:none --sparse --branch "$branch" \
    https://github.com/dotnet/dotnet.git "$vmr"

  git -C "$vmr" cat-file -e "HEAD:$external_path"
  git -C "$vmr" ls-tree "HEAD:$external_path" > "vmr-tree"
  awk '$1 == "040000" { print $4 }' "vmr-tree" > "vmr-libraries"
  mapfile -t vmr_libraries < "vmr-libraries"
  ((${#vmr_libraries[@]} > 0)) || fail "no library directories found in $branch:$external_path"
  echo "VMR libraries (${#vmr_libraries[@]}):"
  printf '  - %s\n' "${vmr_libraries[@]}"
}

collect_bundled_libraries() {
  local package capability
  local -a packages

  rpm -qa --qf '%{NAME}\n' | awk -v version="${major}.${minor}" '
    $0 == "dotnet-host" ||
    $0 == "aspnetcore-runtime-" version ||
    $0 == "dotnet-runtime-" version ||
    $0 == "dotnet-sdk-" version ||
    $0 == "dotnet-sdk-aot-" version
  ' | sort -u > "dotnet-packages"
  mapfile -t packages < "dotnet-packages"

  printf 'RPM packages checked (%d):\n' "${#packages[@]}"
  if ((${#packages[@]} > 0)); then
    printf '  - %s\n' "${packages[@]}"
  else
    echo "  (none)"
  fi

  : > "rpm-provides"
  for package in "${packages[@]}"; do
    rpm -q --provides "$package" | awk -v package="$package" '
      $1 ~ /^bundled\(/ { print package "\t" $1 }
    ' >> "rpm-provides"
  done
  while IFS=$'\t' read -r package capability; do
    bundled_packages["$capability"]=$package
  done < "rpm-provides"
}

collect_system_libraries() {
  local file soname dependency_path resolved ldd_status

  # Write the list first so failures from find or file cannot be hidden by a
  # process substitution. Exclude common managed assemblies and metadata.
  find -L "$root" -type f \
    ! -iname '*.dll' ! -iname '*.pdb' ! -iname '*.xml' ! -iname '*.json' \
    ! -iname '*.txt' ! -iname '*.targets' ! -iname '*.globalconfig' \
    ! -iname '*.props' ! -iname '*.pubxml' ! -iname '*.nupkg' ! -iname '*.xaml' \
    -exec sh -c '
      for file do
        description=$(file -b "$file") || exit 1
        case "$description" in
          *ELF*) printf "%s\0" "$file" ;;
        esac
      done
    ' _ {} + > "elf-files"

  : > "system-dependencies"
  while IFS= read -r -d '' file; do
    ((elf_count += 1))
    if ! LC_ALL=C readelf -d "$file" > "readelf-output" 2>&1; then
      cat "readelf-output" >&2
      fail "could not inspect ELF dependencies: $file"
    fi
    awk '$2 == "(NEEDED)" {
      gsub(/^\[|\]$/, "", $NF)
      print $NF
    }' "readelf-output" > "direct-sonames"

    # Static and relocatable ELF files do not need dynamic resolution.
    [[ -s direct-sonames ]] || continue
    ldd_status=0
    LC_ALL=C ldd "$file" > "ldd-output" 2>&1 || ldd_status=$?
    if awk '$2 == "=>" && $3 == "not" && $4 == "found" { found = 1 }
            END { exit !found }' "ldd-output"; then
      cat "ldd-output" >&2
      fail "missing ELF dependencies: $file"
    fi
    if ((ldd_status != 0)); then
      echo "WARNING: could not resolve ELF dependencies: $file" >&2
      cat "ldd-output" >&2
      continue
    fi
    # ldd also lists transitive dependencies; only retain direct DT_NEEDED entries.
    awk '
      NR == FNR { direct[$0] = 1; next }
      $2 == "=>" && $1 in direct && $3 ~ /^\// { print $1 "\t" $3 }
    ' "direct-sonames" "ldd-output" > "resolved-direct"
    while IFS=$'\t' read -r soname dependency_path; do
      resolved=$(readlink -f "$dependency_path" 2>/dev/null) || continue
      [[ -e $resolved ]] || continue
      [[ $resolved != "$root"/* ]] && printf '%s\t%s\t%s\n' "$soname" "$resolved" "$file" >> "system-dependencies"
    done < "resolved-direct"
  done < "elf-files"
  ((elf_count > 0)) || fail "no ELF files found under .NET installation root $root"
}

check_library_evidence() {
  local library=$1 skip_reason canonical_library pattern
  local capability bundled_evidence system_count

  # TODO: Verify skipped VMR directories remain header-only or non-library.
  case $library in
    patches) skip_reason='patches' ;;
    rapidjson) skip_reason='header-only library' ;;
    libunwind_extras) skip_reason='build configuration for libunwind' ;;
    *) skip_reason='' ;;
  esac
  if [[ -n $skip_reason ]]; then
    echo "SKIP: $library ($skip_reason)"
    ((skipped += 1))
    return
  fi

  # zlib-intel is an optimized zlib implementation, not a separate library.
  canonical_library=$library
  [[ $library == zlib-intel ]] && canonical_library=zlib
  pattern=${soname_patterns[$canonical_library]-}
  if [[ -z $pattern ]]; then
    echo "FAIL: $library (no SONAME mapping configured)" >&2
    ((failed += 1))
    return
  fi

  # ENVIRON preserves the backslashes in the Bash SONAME patterns.
  SONAME_PATTERN="^${pattern}$" awk -F '\t' '
    $1 ~ ENVIRON["SONAME_PATTERN"] && !seen[$3]++ {
      printf "  %s: %s => %s\n", $3, $1, $2
    }
  ' "system-dependencies" > "library-evidence"

  capability="bundled($canonical_library)"
  bundled_evidence=${bundled_packages[$capability]-}
  if [[ -s library-evidence && -n $bundled_evidence ]]; then
    echo "FAIL: $library (both direct system dependency and bundled RPM declaration found in $bundled_evidence)" >&2
    cat "library-evidence" >&2
    ((failed += 1))
  elif [[ -s library-evidence ]]; then
    system_count=$(wc -l < "library-evidence")
    echo "PASS: $library (direct system dependency found in $system_count ELF files)"
    cat "library-evidence"
    ((passed += 1))
  elif [[ -n $bundled_evidence ]]; then
    echo "PASS: $library (bundled by $bundled_evidence)"
    ((passed += 1))
  else
    echo "FAIL: $library (no direct system dependency or bundled RPM declaration found)" >&2
    ((failed += 1))
  fi
}

check_unexpected_bundled_libraries() {
  local library capability
  local -A vmr_capabilities=()

  for library in "${vmr_libraries[@]}"; do
    vmr_capabilities["bundled($library)"]=1
    # Match the alias used when checking evidence for zlib-intel.
    if [[ $library == zlib-intel ]]; then
      vmr_capabilities['bundled(zlib)']=1
    fi
  done

  for capability in "${!bundled_packages[@]}"; do
    if [[ -z ${vmr_capabilities[$capability]-} ]]; then
      echo "FAIL: $capability (declared by ${bundled_packages[$capability]}, but not found in VMR branch $branch)" >&2
      ((unexpected_bundled += 1))
    fi
  done
}

sdk_version=$(dotnet --version) || fail "could not get SDK version from dotnet on PATH"
version_without_suffix=${sdk_version%%-*}
if [[ ! $version_without_suffix =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  fail "cannot map SDK version '$sdk_version' to a VMR release branch"
fi
major=${BASH_REMATCH[1]}
minor=${BASH_REMATCH[2]}
branch="release/${major}.0.1xx"

command -v rpm >/dev/null || fail "rpm tooling is required to inspect installed package metadata"
command -v file >/dev/null || fail "file utility is required to identify ELF files"
command -v readelf >/dev/null || fail "readelf is required to inspect direct ELF dependencies"
command -v ldd >/dev/null || fail "ldd is required to resolve ELF dependencies"

root=$(../dotnet-directory --root) || fail "could not determine .NET installation root"
root=$(realpath "$root")
[[ -d $root ]] || fail "canonical .NET installation root does not exist: $root"

# Map VMR dependency directory names explicitly to their ELF SONAMEs. Keep
# these keys aligned with src/runtime/src/native/external on active branches.
architecture=$(uname -m)
declare -A soname_patterns=(
  [LinuxTracepoints]='libtracepoint\.so([.][0-9]+)*'
  [brotli]='libbrotli(common|dec|enc)\.so([.][0-9]+)*'
  [libunwind]="libunwind(-${architecture})?\\.so([.][0-9]+)*"
  [llvm-libunwind]="libunwind(-${architecture})?\\.so([.][0-9]+)*"
  [zlib]='lib(z|z-ng)\.so([.][0-9]+)*'
  [zlib-ng]='lib(z|z-ng)\.so([.][0-9]+)*'
  [zstd]='libzstd\.so([.][0-9]+)*'
)

workdir=$(mktemp -d "./vmr-work.XXXXXXXX") || fail "could not create working directory"
trap 'rm -rf -- "$workdir"' EXIT
vmr="$workdir/vmr"
declare -a vmr_libraries=()
declare -A bundled_packages=()
elf_count=0
passed=0
failed=0
skipped=0
unexpected_bundled=0

discover_vmr_libraries
collect_bundled_libraries
collect_system_libraries
for library in "${vmr_libraries[@]}"; do
  check_library_evidence "$library"
done
check_unexpected_bundled_libraries

if ((failed > 0 || unexpected_bundled > 0)); then
  echo "Diagnostics:" >&2
  printf '  .NET root: %s\n' "$root" >&2
  printf '  ELF files inspected: %d\n' "$elf_count" >&2
fi

echo "Summary: $passed passed, $failed failed, $skipped skipped (${#vmr_libraries[@]} VMR libraries); $unexpected_bundled unexpected bundled declarations (SDK $sdk_version, branch $branch)"
((failed == 0 && unexpected_bundled == 0))
