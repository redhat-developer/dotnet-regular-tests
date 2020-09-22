#!/bin/bash

# Check whether coredumps produced by .NET Core can be used by sos
# successfully. This test uses the `dotnet sos` global tool.

if [ -f /etc/profile ]; then
  source /etc/profile
fi

# Enable "unofficial strict mode" only after loading /etc/profile
# because that usually contains lots of "errors".
set -euo pipefail
IFS=$'\n\t'

# https://stackoverflow.com/questions/3173131/redirect-copy-of-stdout-to-log-file-from-within-bash-script-itself
exec > >(tee -i sos-lldb-core.log)
exec 2>&1

lldb-core () {
    commands=()
    while [[ "$#" -ne 0 ]]; do
        command=$1
        commands+=('--one-line' "${command}")
        shift
    done
    lldb --batch \
         -c "${coredump}" \
         "${commands[@]}"
}

sdk_version=$1

set -x

dotnet tool uninstall -g dotnet-sos || true
dotnet tool uninstall -g dotnet-dump || true
dotnet tool install -g dotnet-sos
dotnet tool install -g dotnet-dump

dotnet sos install

framework_dir=$(../dotnet-directory --framework "${sdk_version}")
test -f "${framework_dir}/createdump"

if ! command -v lldb ; then
    echo "lldb is not installed"
    exit 1
fi

no_server=("/nodeReuse:false" "/p:UseSharedCompilation=false" "/p:UseRazorBuildServer=false")

# Create a dump

rm -rf TestDir
mkdir TestDir
cd TestDir

dotnet new web
sed -i -e 's|.UseStartup|.UseUrls("http://localhost:5000").UseStartup|' Program.cs
dotnet build "${no_server[@]}"

dotnet bin/Debug/net*/TestDir.dll &
run_pid=$!

sleep 5

dotnet dump collect --output "coredump.${run_pid}" --process-id "${run_pid}" | tee run.pid

kill -9 "${run_pid}" || true

coredump="coredump.${run_pid}"
test -f "${coredump}"

# Object Inspection

echo "[dumpobj]"
lldb-core 'dso' > lldb.out
cat lldb.out
id=$(grep -F 'System.String[]' lldb.out | head -1 | cut -d' ' -f 2)
lldb-core "dumpobj ${id}" > lldb.out
cat lldb.out
grep 'Array:       Rank 1,' lldb.out

echo "[dso]"
lldb-core 'dso' > lldb.out
cat lldb.out
# TODO: enable this
# if grep '<unknown type>' lldb.out; then
#     echo 'fail: <unknown type> found in dso output.'
#     exit 2
# fi

echo "[dumpheap]"
lldb-core "dumpheap -stat" > lldb.out
cat lldb.out
# TODO: enable this
# if grep UNKNOWN lldb.out; then
#     echo 'fail: UNKNOWN classes found in dumpheap'
#     exit 2
# fi

echo "[gcroot]"
lldb-core 'dso' > lldb.out
cat lldb.out
id=$(grep -F 'System.Threading.Tasks' lldb.out | head -1 | cut -d' ' -f 2)
lldb-core "gcroot ${id}" > lldb.out
cat lldb.out
grep 'Found [[:digit:]]* unique roots' lldb.out
count=$(grep 'Found [[:digit:]]* unique roots' lldb.out | sed -E 's|Found ([[:digit:]]*) unique roots.*|\1|')
if [[ $count -le 0 ]]; then
   echo "fail: $count unique roots found"
   exit 2
fi
# TODO: enable
# if grep -F '<error>' lldb.out; then
#     echo 'fail: <error> found in gcroot output'
#     exit 2
# fi

echo "[pe]"

# Examining code and stacks

echo "[clrthreads]"
lldb-core "clrthreads" > lldb.out
cat lldb.out
# TODO: fail if there are any "Ukn" at all
# if grep Ukn lldb.out;  then
#     echo 'fail: Ukn found in clrthreads'
#     exit 2
# fi

echo "[ip2md]"
lldb-core 'clrthreads' > lldb.out
cat lldb.out
thread_id=$(grep -A5 'ID *OSID *ThreadOBJ' lldb.out | tail -4 | grep -vE 'Finalizer|Threadpool' | head -1 | awk '{print $1}')
lldb-core "thread select ${thread_id}" 'clrstack' > lldb.out
cat lldb.out
ip=$(grep 'OS Thread Id:' lldb.out -A5 | tail -n3 | grep -v -F '[Prestub' | head -1 | cut -d' ' -f2)
lldb-core "ip2md ${ip}" > lldb.out
cat lldb.out
if ! grep 'IsJitted' lldb.out ; then
    echo 'IsJitted field not found in ip2md'
    exit 2
fi

echo "[clru]"
lldb-core "clru ${ip}" > lldb.out
cat lldb.out
if grep 'Unmanaged code' lldb.out; then
    echo 'fail: clru thinks IP points to unmanaged code'
    exit 2
fi

echo "[dumpstack]"
lldb-core 'clrstack' > lldb.out
cat lldb.out
stack_pointer=$(grep 'OS Thread Id' lldb.out -A3 | tail -1 | awk '{ print $1}')
lldb-core "dumpstack ${stack_pointer}"
cat lldb.out

echo "[eestack]"
lldb-core 'eestack' > lldb.out
cat lldb.out
grep -E 'Child-SP\s+RetAddr\s+Caller, Callee' lldb.out

echo "[clrstack]"
lldb-core 'clrstack' > lldb.out
cat lldb.out
grep 'TestDir.Program.Main' lldb.out

echo "[bpmd] breakpoints make no sense for core files"

# Examining CLR data structures

echo "[eeheap]"
lldb-core 'eeheap' > lldb.out
cat lldb.out
grep 'GC Heap Size:    Size: 0x' lldb.out
# TODO: enable this
# if grep 'Error getting' lldb.out; then
#     echo 'fail: Error getting some parts of eeheap'
#     exit 2
# fi

echo "[name2ee]"
lldb-core 'name2ee *!System.String' > lldb.out
cat lldb.out
grep 'MethodTable: ' lldb.out
grep 'EEClass: ' lldb.out
grep 'Name: ' lldb.out
string_module=$(grep 'Module: ' lldb.out | head -1 | awk '{print $2}')
string_method_table=$(grep 'MethodTable:' lldb.out | awk '{print $2}')
string_eeclass=$(grep 'EEClass:' lldb.out | head -1 | awk '{print $2}')

lldb-core 'name2ee *!System.String.ToString' > lldb.out
cat lldb.out
grep 'TestDir.dll' lldb.out
grep 'System.Runtime.dll' lldb.out
grep 'Microsoft.AspNetCore.dll' lldb.out
to_string_method_descriptor=$(grep 'MethodDesc:' lldb.out | head -1 | awk '{print $2}')

echo "[dumpmt]"
lldb-core "dumpmt ${string_method_table}" > lldb.out
cat lldb.out
grep 'Name:            System.String' lldb.out
grep -F "File:            ${framework_dir}" lldb.out

echo "[dumpclass]"
lldb-core "dumpclass ${string_eeclass}" > lldb.out
cat lldb.out
grep 'Class Name:      System.String' lldb.out

echo "[dumpmd]"
lldb-core "dumpmd ${to_string_method_descriptor}" > lldb.out
cat lldb.out
grep -F 'Method Name:          System.String.ToString()' lldb.out
grep 'IsJitted:             yes' lldb.out
grep 'Version History:' lldb.out

echo "[dumpmodule]"
lldb-core "dumpmodule ${string_module}" > lldb.out
cat lldb.out
grep "Name: *${framework_dir}" lldb.out
grep 'Attributes: *PEFile' lldb.out
grep 'MetaData start address: *0' lldb.out

# TODO bug https://github.com/dotnet/diagnostics/issues/448
# echo "[dumpil]"
# lldb-core "dumpil ${to_string_method_descriptor}" > lldb.out
# cat lldb.out
# grep 'IL_0000: ldarg.0' lldb.out
# grep 'IL_0001: ret ' lldb.out

echo "[dumplog]"

echo "PASS"
