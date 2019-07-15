#!/bin/bash

# Check whether coredumps produced by .NET Core can be used by sos
# successfully. This test uses the built-in CoreCLR sos support, not
# the new `dotnet sos` global tool.

set -euo pipefail
IFS=$'\n\t'

lldb-core () {
    commands=()
    while [[ "$#" -ne 0 ]]; do
        command=$1
        commands+=('--one-line' "${command}")
        shift
    done
    lldb --batch \
         --no-lldbinit \
         -c "${coredump}" \
         --one-line "plugin load ${framework_dir}/libsosplugin.so" \
         "${commands[@]}"
}

sdk_version=$1

set -x

if ! command -v lldb ; then
    echo "lldb is not installed"
    exit 1
fi

# Create a dump

rm -rf TestDir
mkdir TestDir
cd TestDir

dotnet new web
sed -i -e 's|.UseStartup|.UseUrls("http://localhost:5000").UseStartup|' Program.cs
dotnet build
dotnet run --no-restore --no-build &
run_pid=$!

exec_pid=$(pgrep --list-full --full 'dotnet exec' | cut -d' ' -f1) || true
while [ -z "${exec_pid}" ]; do
    sleep 1
    exec_pid=$(pgrep --list-full --full 'dotnet exec' | cut -d' ' -f1) || true
done

sleep 5

# TODO: assert that this is only one directory
declare -a versions
readarray -d '.' -t versions <<< ${sdk_version}
framework_dir="$(ls -d "$(dirname "$(readlink -f "$(command -v dotnet)")")/shared/Microsoft.NETCore.App/${versions[0]}.${versions[1]}"*)"
echo "${framework_dir}"
test -d "${framework_dir}"

"${framework_dir}"/createdump --name 'coredump.%d' "${exec_pid}" | tee exec.pid

kill "${exec_pid}"
kill "${run_pid}" || true

coredump="coredump.${exec_pid}"
test -f "${coredump}"

# Make sure dotnet-sos is not active
lldb --batch \
     -c "${coredump}" \
     --one-line "soshelp" >lldb.out 2>&1
cat lldb.out
grep -F "error: 'soshelp' is not a valid command." lldb.out

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
thread_id=$(grep -A5 'ID OSID ThreadOBJ' lldb.out | tail -4 | grep -vE 'Finalizer|Threadpool' | head -1 | awk '{print $1}')
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
grep 'Heap Size:               Size: 0x' lldb.out
grep 'GC Heap Size:            Size: 0x' lldb.out
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
grep 'System.Security.Cryptography.Primitives' lldb.out
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
grep 'Code Version History:' lldb.out

echo "[dumpmodule]"
lldb-core "dumpmodule ${string_module}" > lldb.out
cat lldb.out
grep -F "Name:       ${framework_dir}" lldb.out
grep 'Attributes: PEFile' lldb.out
grep 'MetaData start address:  0' lldb.out

echo "[dumpil]"
lldb-core "dumpil ${to_string_method_descriptor}" > lldb.out
cat lldb.out
grep 'IL_0000: ldarg.0' lldb.out
grep 'IL_0001: ret ' lldb.out

echo "[dumplog]"

echo "PASS"
