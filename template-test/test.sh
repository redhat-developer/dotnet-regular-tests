#!/usr/bin/env bash

# this file tests templates created by
# dotnet new <template>

set -euo pipefail
#set -x

# The list of templates in each version of .NET that we want to test.
# If additional templates are found via `dotnet new --list`, this test
# will fail unless they are added here.

dotnet6Templates=(
    angular
    blazorserver
    blazorwasm
    classlib
    console
    editorconfig
    gitignore
    globaljson
    grpc
    mstest
    mvc
    nugetconfig
    nunit
    nunit-test
    page
    proto
    razor
    razorclasslib
    razorcomponent
    react
    sln
    solution
    tool-manifest
    viewimports
    viewstart
    web
    webapi
    webapp
    webconfig
    worker
    xunit
)

dotnet5Templates=(
    angular
    blazorserver
    blazorwasm
    classlib
    console
    editorconfig
    gitignore
    globaljson
    grpc
    mstest
    mvc
    nugetconfig
    nunit
    nunit-test
    page
    proto
    razor
    razorclasslib
    razorcomponent
    react
    reactredux
    sln
    tool-manifest
    viewimports
    viewstart
    web
    webapi
    webapp
    webconfig
    worker
    xunit
)

dotnet3Templates=(
    angular
    blazorserver
    classlib
    console
    gitignore
    globaljson
    grpc
    mstest
    mvc
    nugetconfig
    nunit
    nunit-test
    page
    proto
    razorclasslib
    razorcomponent
    react
    reactredux
    sln
    tool-manifest
    viewimports
    viewstart
    web
    webapi
    webapp
    webconfig
    worker
    xunit
)

# All templates are tested with "dotnet template new", but this list
# adds further actions (eg, build, run) for some templates. These
# templates are only tested if `dotnet new --list` shows the template
# for this .NET version.
#
# format: <template> <action>
# actions:
#    new - just create template ( using dotnet new <template> )
#    build - create template and run build on it ( dotnet build )
#    run - create template and run it ( dotnet run )
#    test - create template and run its tests ( dotnet test )

templateActions=\
"angular build
blazorserver build
blazorwasm build
classlib build
console run
mstest test
mvc build
nunit test
razor build
razorclasslib build
react build
reactredux build
webapi build
webapp build
web build
worker build
xunit test"

# Templates that can be ignored. They may be present in the dotnet new
# --list output but are safe to ignore. We we don't want to test these
# because they are known to not work on the platforms we care about.
templateIgnoreList=(
    winforms
    winformslib
    wpf
    wpfcustomcontrollib
    wpflib
    wpfusercontrollib
)


declare -A knownTemplateActions
readarray -t templateLines <<< "$templateActions"
for line in "${templateLines[@]}"; do
    templateName="${line%% *}"
    action="${line##* }"
    knownTemplateActions["$templateName"]="$action"
done

dotnet help > /dev/null 2>/dev/null

readarray -t allAutoTemplates < <(
    dotnet new --list |
        sed '0,/^--*/d' |
        awk -F '  +' ' { print $2 }' |
        sed 's/,/\n/' |
        sed -e '/^ *$/d' |
        sort -u)

if [[ "${#allAutoTemplates[@]}" -lt 10 ]]; then
    echo "unable to parse 'dotnet new --list' correctly"
    exit 1
fi

filteredAutoTemplates=()
for template in "${allAutoTemplates[@]}"; do
    ignore=0
    for ignoreTemplate in "${templateIgnoreList[@]}"; do
        if [[ $ignoreTemplate == "$template" ]]; then
            ignore=1
        fi
    done
    if [[ $ignore == 0 ]]; then
        filteredAutoTemplates+=("$template")
    fi
done

IFS='.' read -ra VERSION_SPLIT <<< "$1"
declare -a allTemplates
if [[ ${VERSION_SPLIT[0]} == "6" ]]; then
    allTemplates=( "${dotnet6Templates[@]}" )
elif [[ ${VERSION_SPLIT[0]} == "5" ]]; then
    allTemplates=( "${dotnet5Templates[@]}" )
elif [[ ${VERSION_SPLIT[0]} == "3" ]]; then
    allTemplates=( "${dotnet3Templates[@]}" )
else
    echo "error: unknown dotnet version " "${VERSION_SPLIT[@]}"
    echo "Need a new template list for this. Here's a starting point:"
    echo "${filteredAutoTemplates[@]}"
    exit 1
fi

for autoTemplate in "${filteredAutoTemplates[@]}"; do
    found=0
    for explicitTemplate in "${allTemplates[@]}"; do
        if [[ $explicitTemplate == "$autoTemplate" ]]; then
            found=1
        fi
    done
    if [[ $found == 0 ]]; then
        echo "error: auto-detected template '${autoTemplate}' which is not in" \
             "the explicit list of templates to test. If this is intentional," \
             "add it to the templateIgnoreList."
        echo "detected templates:" "${filteredAutoTemplates[@]}"
        exit 1

    fi
done

echo "Auto-detected templates:" "${allAutoTemplates[@]}"
echo "Ignoring:" "${templateIgnoreList[@]}"
echo "Testing:" "${allTemplates[@]}"
echo

tmpDir=""
templateName=""

failedTests=0

function cleanupFunc {
    if [ -n "${tmpDir:-}" ] ; then
        rm -rf "${tmpDir}"
    fi
}

function testTemplate {
    local templateName="${1}"
    local action="${2}"

    echo "### Testing: ${templateName}"

    dotnet new "${templateName}" 2>&1 | tee "${templateName}.log"
    if grep -i failed "${templateName}.log"; then
        echo "error: ${templateName} failed."
        failedTests=$((failedTests+1))
        return
    fi

    allCsprojs=(./*.csproj)
    firstCsproj=${allCsprojs[0]}
    if [ -f "${firstCsproj}" ]; then
        sed -i '0,/<PropertyGroup>/s/<PropertyGroup>/<PropertyGroup><TreatWarningsAsErrors>true<\/TreatWarningsAsErrors>/' "${firstCsproj}"
    fi

    if [ "${action}" = "new" ] ; then
        true # no additional action
    elif [[ ( $(uname -m) == "s390x" ) && ( "${templateName}" == "angular" ) ]]; then
        # angular needs the node module fsevents, which is not supported on s390x
        true
    elif [ "${action}" = "build" ] || [ "${action}" = "run" ] || [ "${action}" = "test" ] ; then
        if [[ ( $(uname -m) == "s390x" ) && ( "${templateName}" == "xunit" || "${templateName}" == "nunit" || "${templateName}" == "mstest" ) ]]; then
            # xunit/nunit/mstest need a package version fix for s390x;
            # the default templates are known to be broken out of the
            # box
            sed -i -E 's|(PackageReference Include="Microsoft.NET.Test.Sdk" Version=")16.11.0"|\117.0.0"|' ./*.csproj
        fi
        if ! dotnet "${action}"; then
            failedTests=$((failedTests+1))
            echo "FAILED: ${templateName} failed"
        fi
    else
        echo "error: unknown action ${action}"
        exit 1
    fi
    return
}

function testTemplates {
    local templateName
    local action

    for templateName in "${allTemplates[@]}"; do
        action="${knownTemplateActions[$templateName]:-new}"

        mkdir -p "${tmpDir}/${templateName}-template"
        pushd "${tmpDir}/${templateName}-template" > /dev/null

        testTemplate "${templateName}" "${action}"

        popd > /dev/null
    done

    if [[ $failedTests == 0 ]]; then
        echo "OK: all template tests passed."
        exit 0
    else
        echo "error: $failedTests tests failed"
        exit 1
    fi
}

trap cleanupFunc EXIT
tmpDir="$( mktemp -d )"

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
if [[ -f "${scriptDir}/nuget.config" ]]; then
    cp "${scriptDir}/nuget.config" "${tmpDir}/"
fi

testTemplates
