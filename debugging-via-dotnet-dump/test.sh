#!/usr/bin/env bash

# Check whether dotnet-dump, and its subcommands like `ps`, `collect`
# and `analyze` are working

# Ensure global tools are on PATH.
export PATH=~/.dotnet/tools:$PATH

# Enable "unofficial strict mode" only after loading /etc/profile
# because that usually contains lots of "errors".
set -euo pipefail
IFS=$'\n\t'

heading () {
    set +x
    echo
    echo "## $1"
    echo "---${1//?/-}"
    echo
    set -x
}

dump-analyze () {
    first_word_in_first_command=${1%% *}

    commands=()
    while [[ "$#" -ne 0 ]]; do
        command=$1
        commands+=('--command' "${command}")
        shift
    done
    commands+=('--command' 'exit')
    dotnet dump analyze \
           "${coredump}" \
           "${commands[@]}" > output.temporary
    set +x
    if grep -i 'unrecognized command' output.temporary ; then
        echo "fail: unrecognized command" >&2
        cat output.temporary >&2
        exit 1
    fi
    if grep -i 'invalid parameter' output.temporary ; then
        echo "fail: invalid parameter" >&2
        cat output.temporary >&2
        exit 1
    fi
    if grep -i 'argument is missing' output.temporary ; then
        echo "fail: missing arguments" >&2
        cat output.temporary >&2
        exit 1
    fi
    if grep -i 'Usage: ' output.temporary ; then
        echo "fail: invalid usage" >&2
        cat output.temporary >&2
        exit 1
    fi
    if grep -i 'Must pass a valid' output.temporary ; then
        echo "fail: invalid usage" >&2
        cat output.temporary >&2
        exit 1
    fi
    if grep -i ' is not a valid object' output.temporary ; then
        echo "fail: invalid usage" >&2
        cat output.temporary >&2
        exit 1
    fi
    if grep -i -E "^${first_word_in_first_command}" output.temporary ; then
        echo "fail: invalid usage" >&2
        cat output.temporary >&2
        exit 1
    fi
    if grep -F '<error>' output.temporary; then
        echo 'fail: <error> found in output' >&2
        cat output.temporary >&2
        exit 1
    fi
    set -x

    cat output.temporary
    rm output.temporary
}

sdk_version=${1:-$(dotnet --version)}

set -x

heading "Installing dotnet-dump"

dotnet tool uninstall -g dotnet-dump || true
dotnet tool install -g dotnet-dump
# For preview releases:
#dotnet tool install -g dotnet-dump --add-source https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-tools/nuget/v3/index.json

framework_dir=$(../dotnet-directory --framework "${sdk_version}")
test -f "${framework_dir}/createdump"

no_server=("/nodeReuse:false" "/p:UseSharedCompilation=false" "/p:UseRazorBuildServer=false" "/p:UsingMicrosoftNETSdkRazor=false" "/p:ScopedCssEnabled=false")

heading "Running test application"

rm -rf TestDir
mkdir TestDir
cd TestDir

dotnet new web --no-restore
sed -i -e 's|.UseStartup|.UseUrls("http://localhost:5000").UseStartup|' Program.cs
dotnet build "${no_server[@]}"

dotnet bin/Debug/net*/TestDir.dll &
run_pid=$!
trap "kill ${run_pid}" EXIT

sleep 5

heading "Testing dotnet dump ps"

dotnet dump ps > ps.out
cat ps.out
if [[ $(grep -cvE '^[ \t]*$' ps.out) -lt 2 ]]; then
    echo 'fail: dotnet dump ps produced less than expected lines of output'
    exit 2
fi
grep -F 'dotnet dump ps' ps.out

heading "Creating a dump"

dotnet dump collect --type full --output "coredump.${run_pid}" --process-id "${run_pid}" | tee run.pid
#"${framework_dir}"/createdump --full --name "$(pwd)/coredump.${run_pid}" "${run_pid}" | tee run.pid

kill "${run_pid}" || ( sleep 1; kill -9 "${run_pid}" )
trap - EXIT

coredump="coredump.${run_pid}"
test -f "${coredump}"

heading "Testing dotnet dump analyze subcommands"

# Test all subcommands. Keep list alphabetically sorted. Prefer long
# names over short aliases, so `registers` instead of `r`.

heading "analyzeoom"
dump-analyze 'analyzeoom' > dump.out
cat dump.out
grep -F 'no managed OOM due to allocations on the GC heap' dump.out


heading "clrmodules"
dump-analyze 'clrmodules' > dump.out
cat dump.out
grep -F System.Net.Sockets.dll dump.out
grep -F System.Memory.dll dump.out
grep -F Microsoft.AspNetCore.dll dump.out


heading "clrstack"
dump-analyze 'clrstack -a -f -r -all' > dump.out
cat dump.out
grep -F 'Program.<Main>' dump.out
grep -F 'Microsoft.AspNetCore' dump.out
grep -F 'PARAMETERS:' dump.out
grep -F 'LOCALS:' dump.out
dump-analyze 'clrthreads' > dump.out
cat dump.out
thread_id=$(grep -A5 'ID *OSID *ThreadOBJ' dump.out | tail -4 | grep -vE 'Finalizer|Threadpool' | { head -1; cat > /dev/null; } | awk '{print $1}')
dump-analyze "threads ${thread_id}" 'clrstack' > dump.out
cat dump.out
grep -E 'System\.Threading|DebuggerU2MCatchHandlerFrame' dump.out


heading "clrthreads"
dump-analyze "clrthreads" > dump.out
cat dump.out
grep -E 'ThreadCount: *[[:digit:]]+' dump.out
grep -E 'BackgroundThread: *[[:digit:]]' dump.out
grep -E 'Hosted Runtime: *no' dump.out


dump-analyze 'clrstack -a' > dump.out
grep -E 'this \([^)]+\) = 0x[0-9a-f]+' dump.out
addr=$(grep -E 'this \([^)]+\) = 0x[0-9a-f]+' dump.out | cut -d'=' -f2 | { head -1; cat > /dev/null; } )
dump-analyze "dumpalc $addr" > dump.out
cat dump.out


heading "dumpasync"
dump-analyze 'dumpasync' > dump.out
cat dump.out
grep -E 'Awaiting: [a-zA-Z0-9]+ [a-zA-Z0-9]+ System.Runtime.CompilerServices.ValueTaskAwaiter<System.Net.Sockets.Socket>' dump.out


# TODO: dumpconcurrentdictionary

# TODO: dumpconcurrentqueue


heading "dumpgen"
for gen in gen0 gen1 gen2 loh poh; do
    dump-analyze "dumpgen $gen" > dump.out
    cat dump.out
    total=$( (grep -E '00[0-9a-fA-F]+ +[[:digit:]]+ +[[:digit:]]+ +' dump.out | awk '{print $2}' | paste -sd+ | bc) || echo 0)
    grep -F "Total ${total} objects" dump.out
done


heading "dumparray"
dump-analyze 'dumpstackobjects' > dump.out
cat dump.out
mapfile -t object_ids < <(grep -F 'System.String[]' dump.out | awk '{ print $2 }')
echo '' > dump.out
for id in "${object_ids[@]}"; do
    dump-analyze "dumparray -details ${id}" > single.dump.out
    cat single.dump.out
    cat single.dump.out >> dump.out
    grep 'Array:       Rank 1,' dump.out
done
if grep 'Number of elements' dump.out | grep -cv 'Number of elements 0'; then
    grep -E '^\[0\]' dump.out
    grep -F '_stringLength' dump.out
fi


# TODO "dumpassembly"

# TODO: dumpasync


heading "dumpclass"
dump-analyze 'name2ee *!System.String' > dump.out
cat dump.out
grep 'EEClass: ' dump.out
string_eeclass=$(grep 'EEClass:' dump.out | { head -1; cat > /dev/null; }  | awk '{print $2}')
dump-analyze "dumpclass ${string_eeclass}" > dump.out
cat dump.out
grep 'Class Name:      System.String' dump.out


# TODO "dumpdelegate"


heading "dumpdomain"
dump-analyze 'dumpdomain' > dump.out
cat dump.out
grep -F 'System Domain:' dump.out
grep -F 'Domain 1:' dump.out
if [[ $(grep -c 'Name:   ' dump.out) -lt 2 ]]; then
    echo 'fail: too few domains in dump'
    exit 2
fi

# FIXME: why are all data values 0 here?
heading "dumpgcdata"
dump-analyze 'dumpgcdata' > dump.out
cat dump.out


heading "dumpheap"
dump-analyze "dumpheap -stat" > dump.out
cat dump.out
if grep UNKNOWN dump.out; then
    echo 'fail: UNKNOWN classes found in dumpheap'
    exit 2
fi
grep -E '^[0-9a-fA-F]+ +([[:digit:]]+,)?[[:digit:]]+ +([[:digit:]]+,)?[[:digit:]]+ +System.Object\[\]' dump.out
grep -E '^[0-9a-fA-F]+ +([[:digit:]]+,)?[[:digit:]]+ +([[:digit:]]+,)?[[:digit:]]+ +System.Char\[\]' dump.out
grep -E '^[0-9a-fA-F]+ +([[:digit:]]+,)?[[:digit:]]+ +([[:digit:]]+,)?[[:digit:]]+ +System.String$' dump.out


heading "dumpil"
dump-analyze 'name2ee *!System.String.ToString' > dump.out
cat dump.out
mapfile -t to_string_method_descriptors < <(grep 'MethodDesc:' dump.out | awk '{print $2}')
for desc in "${to_string_method_descriptors[@]}"; do
    dump-analyze "dumpil ${desc}" > dump.out
    cat dump.out
done
dump-analyze "dumpil ${to_string_method_descriptors[0]}" > dump.out
cat dump.out
grep 'IL_0000: ldarg.0' dump.out
grep 'IL_0001: ret ' dump.out


# TODO "dumplog"


heading "dumpmd"
dump-analyze 'clrthreads' > dump.out
cat dump.out
thread_id=$(grep -A5 'ID *OSID *ThreadOBJ' dump.out | tail -4 | grep -vE 'Finalizer|Threadpool' | { head -1; cat > /dev/null; }  | awk '{print $1}')
dump-analyze "threads ${thread_id}" 'clrstack' > dump.out
cat dump.out
ip=$(grep 'OS Thread Id:' dump.out -A5 | tail -n3 | grep -v -F '[Prestub' | { head -1; cat > /dev/null; }  | cut -d' ' -f2)
dump-analyze "dumpmd ${ip}" > dump.out
cat dump.out
if grep 'Unmanaged code' dump.out; then
    echo 'fail: dumpmd thinks IP points to unmanaged code'
    exit 2
fi
dump-analyze 'name2ee *!System.String.ToString' > dump.out
cat dump.out
grep 'TestDir.dll' dump.out
grep 'System.Runtime.dll' dump.out
grep 'Microsoft.AspNetCore.dll' dump.out
to_string_method_descriptor=$(grep 'MethodDesc:' dump.out | { head -1; cat > /dev/null; }  | awk '{print $2}')
dump-analyze "dumpmd ${to_string_method_descriptor}" > dump.out
cat dump.out
grep -F 'Method Name:          System.String.ToString()' dump.out
grep 'IsJitted:             yes' dump.out
grep 'Version History:' dump.out


heading "dumpmodule"
dump-analyze 'name2ee *!System.String' > dump.out
cat dump.out
string_module=$(grep 'Module: ' dump.out | { head -1; cat > /dev/null; }  | awk '{print $2}')
dump-analyze "dumpmodule ${string_module}" > dump.out
cat dump.out
grep "Name: *${framework_dir}" dump.out
grep 'Attributes: *PEFile' dump.out
grep 'MetaData start address: *0' dump.out


heading "dumpmt"
dump-analyze 'name2ee *!System.String' > dump.out
cat dump.out
grep 'MethodTable:' dump.out | awk '{print $2}'
string_method_table=$(grep 'MethodTable:' dump.out | awk '{print $2}')
dump-analyze "dumpmt ${string_method_table}" > dump.out
cat dump.out
grep -E '^Name:[ \n\t]+System.String' dump.out
grep -E "^File:[ \n\t]+${framework_dir}" dump.out

heading "dumpobj"
dump-analyze 'dumpstackobjects' > dump.out
cat dump.out
mapfile -t object_ids < <(grep -F 'System.String[]' dump.out | awk '{ print $2 }')
id="${object_ids[0]}"
dump-analyze "dumpobj ${id}" > dump.out
cat dump.out
grep 'Array:       Rank 1,' dump.out


heading "dumpruntimetypes"
# Disable exit on error for dumpruntimetypes. TODO Report this.
set +e
dump-analyze "dumpruntimetypes" > dump.out
set -e
cat dump.out
grep -E '^ *[0-9a-fA-F]+ +[0-9a-fA-F]+ +[0-9a-fA-F]+ +System\.String$' dump.out
grep -E '^ *[0-9a-fA-F]+ +[0-9a-fA-F]+ +[0-9a-fA-F]+ +System\.Byte$' dump.out
grep -E '^ *[0-9a-fA-F]+ +[0-9a-fA-F]+ +[0-9a-fA-F]+ +Microsoft\.Extensions\.Logging' dump.out


# TODO "dumpsig"

# TODO "dumpsigelem"


heading "dumpstackobjects"
dump-analyze 'dumpstackobjects' > dump.out
cat dump.out
if grep '<unknown type>' dump.out; then
    echo 'fail: <unknown type> found in dso output.'
    exit 2
fi
dump-analyze 'clrstack' > dump.out
cat dump.out
stack_pointer=$(grep 'OS Thread Id' dump.out -A3 | tail -1 | awk '{ print $1}')
# Disabled due to: https://github.com/dotnet/diagnostics/issues/4368
# dump-analyze "dumpstackobjects ${stack_pointer}"
# cat dump.out


# TODO "dumpvc"


heading "eeheap"
dump-analyze 'eeheap' > dump.out
cat dump.out
if grep 'Error getting' dump.out; then
    echo 'fail: Error getting some parts of eeheap'
    exit 2
fi
# FIXME: For some unknown reason, "No unique loader heaps found." is printed in
# some environments, even for same builds :/
if ! grep 'No unique loader heaps found.' dump.out; then
    grep 'Allocated Heap Size:    Size: 0x' dump.out
    grep 'Committed Heap Size:    Size: 0x' dump.out
fi

heading "eeversion"
dump-analyze 'eeversion' > dump.out
cat dump.out
grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' dump.out
grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ +@Commit: [0-9a-fA-F]+$' dump.out
grep -E '^(Workstation mode|Server mode with [[:digit:]]+ gc heaps)$' dump.out


heading "ehinfo"
dump-analyze 'name2ee *!System.String.ToString' > dump.out
cat dump.out
mapfile -t to_string_method_descriptors < <(grep 'MethodDesc:' dump.out | awk '{print $2}')
for desc in "${to_string_method_descriptors[@]}"; do
    dump-analyze "ehinfo ${desc}" > dump.out
    cat dump.out
done
# FIXME: why does ehinfo on a method with an actual try-catch show "No EH info available"?


# TODO: enummem

# TODO: ext/sos


heading "finalizequeue"
dump-analyze 'finalizequeue' > dump.out
cat dump.out
grep -E 'generation [[:digit:]]+ has [[:digit:]] (finalizable )?objects' dump.out


heading "findappdomain"
dump-analyze 'dumpstackobjects' > dump.out
cat dump.out
mapfile -t object_ids < <(grep -F 'System.String[]' dump.out | awk '{ print $2 }')
id="${object_ids[0]}"
dump-analyze "findappdomain ${id}" > dump.out
cat dump.out


heading "gchandles"
dump-analyze 'gchandles' > dump.out
cat dump.out
for reference in Strong WeakShort WeakLong Dependent; do
    if [[ $(cut -d' ' -f2 dump.out | grep -cF "$reference") -lt 2 ]]; then
        echo "fail: too few references of type $reference"
        exit 2
    fi
done


heading "gcheapstat"
dump-analyze 'gcheapstat' > dump.out
cat dump.out
grep -F 'Heap0' dump.out


heading "gcinfo"
dump-analyze 'name2ee *!System.String.ToString' > dump.out
cat dump.out
mapfile -t to_string_method_descriptors < <(grep 'MethodDesc:' dump.out | awk '{print $2}')
for desc in "${to_string_method_descriptors[@]}"; do
    dump-analyze "gcinfo ${desc}" > dump.out
    cat dump.out
done


heading "gcroot"
dump-analyze 'dso' > dump.out
cat dump.out
# Skipped on aarch64 due to https://github.com/dotnet/diagnostics/issues/4388
if [[ "$(uname -m)" != "aarch64" ]]; then
    mapfile -t object_ids < <(grep -F 'System.Threading.Tasks' dump.out | awk '{ print $2 }')
    id="${object_ids[0]}"
    dump-analyze "gcroot ${id}" > dump.out
    cat dump.out
    grep -E 'Found [[:digit:]]* (unique )?roots' dump.out
    count=$(grep -E 'Found [[:digit:]]* (unique )?roots' dump.out | sed -E 's|Found ([[:digit:]]*) (unique )?roots.*|\1|')
    if [[ $count -le 0 ]]; then
        echo "fail: $count unique roots found"
        exit 2
    fi
fi


heading "gcwhere"
dump-analyze 'dumpstackobjects' > dump.out
cat dump.out
mapfile -t object_ids < <(grep -F 'System.String[]' dump.out | awk '{ print $2 }')
id="${object_ids[-1]}"
dump-analyze "gcwhere ${id}" > dump.out
cat dump.out
# Output is in one of two formats:
#       Address          Gen Heap segment          begin            allocated         size
#       Address       Heap    Segment    Generation  Allocated    Committed     Reserved
grep -E '[0-9a-fA-F]+ +[0-9]+ +[0-9]+ +[0-9a-fA-F]+ +[0-9a-fA-F]+ +[0-9a-fA-F]+ +0x[0-9a-fA-F]+\([0-9]+\)' dump.out \
  || grep -E '[0-9a-fA-F]+ +[0-9]+ +[0-9a-fA-F]+ +[0-9]+ +[-0-9a-fA-F]+ +[-0-9a-fA-F]+ +[-0-9a-fA-F]+' dump.out \


# TODO "histobj"

# TODO "histobjfind"

# TODO "histroot"

# TODO "histstats"


heading "ip2md"
dump-analyze 'clrthreads' > dump.out
cat dump.out
i=0
while true; do
    i=$((i + 1))
    thread_id=$(grep -A999 'ID *OSID *ThreadOBJ' dump.out | tail -n +2 \
                    | grep -vE 'Finalizer|Threadpool' \
                    | { head -"$i"; cat > /dev/null; }  | tail -1 \
                    | awk '{print $1}')
    dump-analyze "threads ${thread_id}" 'clrstack' > dump.out
    cat dump.out
    if ! grep DebuggerU2MCatchHandlerFrame dump.out ; then
       break
    fi
done
ip=$(grep 'OS Thread Id:' dump.out -A5 | tail -n3 | grep -v -F '[Prestub' | { head -1; cat > /dev/null; }  | cut -d' ' -f2)
dump-analyze "ip2md ${ip}" > dump.out
cat dump.out
if ! grep 'IsJitted' dump.out ; then
    echo 'IsJitted field not found in ip2md'
    exit 2
fi


heading "listnearobj"
dump-analyze 'eeheap' > dump.out
cat dump.out
# FIXME: For some unknown reason, "No unique loader heaps found." is printed in
# some environments, even for same builds :/
if ! grep 'No unique loader heaps found.' dump.out; then
# Find a gen0 with a non-0 size, then grab the starting address from it
    addr=$(grep -m 1 -E '^[0-9a-fA-F]+ +[0-9a-fA-F]+ +[0-9a-fA-F]+ +[0-9a-fA-F]+ +0x[1-9a-fA-F]' dump.out | awk ' { print $2 } ')
    dump-analyze "listnearobj $addr" > dump.out
    cat dump.out
    grep -F 'Before: ' dump.out
    grep -F 'Current: ' dump.out
    grep -F 'After: ' dump.out
grep -F 'Heap local consistency confirmed.' dump.out
fi


heading "modules"
dump-analyze 'modules' > dump.out
cat dump.out
grep -E '/dotnet$' dump.out
grep -F '/libclrjit.so' dump.out
grep -F '/libcoreclr.so' dump.out
grep -F '/System.Private.CoreLib.dll' dump.out
grep -F '/System.Runtime.dll' dump.out


heading "name2ee"
dump-analyze 'name2ee *!System.String' > dump.out
cat dump.out
grep 'MethodTable: ' dump.out
grep 'EEClass: ' dump.out
grep 'Name: ' dump.out
dump-analyze 'name2ee *!System.String.ToString' > dump.out


heading "objsize"
dump-analyze 'dumpstackobjects' > dump.out
cat dump.out
mapfile -t object_ids < <(grep -F 'System.String[]' dump.out | awk '{ print $2 }')
id="${object_ids[-1]}"
dump-analyze "objsize ${id}" > dump.out
cat dump.out
if grep -F 'transitively keep alive' dump.out; then
    # Updated output from objsize looks like this:
    #
    # Objects which 7f85ab80efd8(System.String[]) transitively keep alive:
    #
    #      Address           MT         Size
    # 7f85ab80efd8 7fc58eb2e0c0           24
    grep -E "${id:10} +[0-9a-fA-F]+ +[0-9]+" dump.out
else
    grep -E '^sizeof\([0-9a-fA-F]+\) += +[0-9]+ \(0x[0-9a-fA-F]+\) bytes' dump.out
fi


heading "parallelstacks"
dump-analyze 'parallelstacks' > dump.out
cat dump.out
grep -E '==> [[:digit:]]+ threads with [[:digit:]]+ roots' dump.out


# TODO: printexception


heading "registers"
dump-analyze 'registers' > dump.out
cat dump.out
lines=$(wc -l dump.out | awk '{ print $1 }')
if [[ "$lines"  -lt 20 ]]; then
   echo "fail: too few registers"
   exit 2
fi


heading "readmemory"
# Disable exit on error for dumpruntimetypes. TODO Report this.
set +e
dump-analyze "dumpruntimetypes" > dump.out
set -e
cat dump.out
address=$(grep -F 'System.String' dump.out | { head -1; cat > /dev/null; }  | cut -d' ' -f1)
dump-analyze "readmemory ${address} --length 100" > dump.out
cat dump.out


heading "runtimes"
dump-analyze 'runtimes' > dump.out
cat dump.out
grep -E '^#0 .NET Core runtime ([[:digit:]]+(\.[[:digit:]]+)* )?at [0-9a-fA-F]+ size [0-9a-fA-F]+ index [0-9a-fA-F]+$' dump.out
grep -E '^    Runtime module path: /.*/libcoreclr.so$' dump.out
grep -E '^        Dac .*/libmscordaccore.so LINUX [^ ]+ Coreclr [0-9a-fA-F]+$' dump.out
grep -E '^        Dbi libmscordbi.so LINUX [^ ]+ Coreclr [0-9a-fA-F]+$' dump.out


heading "sosstatus"
dump-analyze 'sosstatus' > dump.out
cat dump.out
grep -E 'Target OS: LINUX Architecture: (X64|Arm64) ProcessId: [[:digit:]]+' dump.out


heading "syncblk"
dump-analyze 'syncblk' > dump.out
cat dump.out
grep -E 'Total +[0-9]+$' dump.out
grep -E 'Free +[0-9]+$' dump.out


# TODO: "taskstate"


heading "threadpool"
dump-analyze 'threadpool' > dump.out
cat dump.out
if ! grep -E 'Worker Thread: Total: [0-9]+ Running: [0-9]+ Idle: [0-9]+ MaxLimit: [0-9]+ MinLimit: [0-9]+' dump.out; then
    grep -E 'Workers Total: *[0-9]+' dump.out
    grep -E 'Workers Running: *[0-9]+' dump.out
    grep -E 'Workers Idle: *[0-9]+' dump.out
    grep -E 'Worker Min Limit: *[0-9]+' dump.out
    grep -E 'Worker Max Limit: *[0-9]+' dump.out
fi


# TODO: "threadpoolqueue"


heading "threads"
dump-analyze 'threads' > dump.out
cat dump.out
lines=$(wc -l dump.out | awk '{ print $1 }')
if [[ "$lines" -lt 9 ]]; then
    echo 'fail: too few threads'
    exit 2
fi


heading "threadstate"
dump-analyze 'threads' > dump.out
cat dump.out
tail -n +2 dump.out | cut -b2- | xargs | cut -d' ' -f1
mapfile -t thread_ids < <(grep -vE '^Loading core dump' dump.out | cut -b2- | cut -d' ' -f1)
echo "${thread_ids[@]}"
for id in "${thread_ids[@]}"; do
    dump-analyze "threadstate ${id}" > dump.out
    cat dump.out
    if [[ $(grep -cvE '^Loading core dump' dump.out) -lt 1 ]]; then
        echo 'fail: no output from thread state?'
        exit 2
    fi
done


heading "timerinfo"
dump-analyze 'timerinfo' > dump.out
cat dump.out
grep -E '^ +[0-9]+ timers$' dump.out


heading "traverseheap"
if [[ "$(uname -m)" != "aarch64" ]]; then
    dump-analyze 'help traverseheap' > dump.out
    cat dump.out
    dump-analyze 'traverseheap -xml full-heap' > dump.out
    cat dump.out
    head full-heap
    tail full-heap
    grep -E '<type id="[[:digit:]]+" name="System.Object\[\]" */>' full-heap
    grep -E '<object address="[^"]+" typeid="1" size="[0-9]+"' full-heap
    grep -E '<object address="[^"]+" typeid="2" size="[0-9]+"' full-heap
fi


heading "verifyheap"
dump-analyze 'verifyheap' > dump.out
grep -F 'No heap corruption detected.' dump.out


heading "verifyobj"
dump-analyze 'dumpstackobjects' > dump.out
cat dump.out
mapfile -t object_ids < <(grep -F 'System.String[]' dump.out | awk '{ print $2 }')
for object in "${object_ids[@]}"; do
    dump-analyze "verifyobj ${object}" > dump.out
    cat dump.out
    grep -E 'object 0[xX][0-9a-fA-F]+ is a valid object' dump.out
done

echo "PASS"
