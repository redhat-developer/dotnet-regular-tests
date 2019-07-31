#!/bin/bash

# this file tests templates created by
# dotnet new <template>

set -euo pipefail
#set -x

# tested templates
# format: <template> <action>
# actions:
#    new - just create template ( using dotnet new <template> )
#    build - create template and run build on it ( dotnet build )
#    build-nodejs - build with nodejs dependencies
#    run - create template and run it ( dotnet run )
#    test - create template and run its tests ( dotnet test )

templates="console run
classlib build
mstest test
xunit test
web build
mvc build
razor build
webapi build
webconfig new
globaljson new
nugetconfig new
sln new
page new
viewstart new
viewimports new"

tmpDir=""
templateName=""

function cleanupFunc {
	if [ -n "${tmpDir:-}" ] ; then
		rm -rf "${tmpDir}"
	fi
}

function testTemplate {
	local templateName="${1}"
	local action="${2}"

	dotnet new "${templateName}"
	sed -i '0,/<PropertyGroup>/s/<PropertyGroup>/<PropertyGroup><TreatWarningsAsErrors>true<\/TreatWarningsAsErrors>/' *.csproj || true


	if [ "${action}" = "new" ] ; then
		true # no additional action
	elif [ "${action}" = "build" ] ; then
		dotnet build
	elif [ "${action}" = "build-nodejs" ] ; then
		exit 1
	elif [ "${action}" = "run" ] ; then
		dotnet run
	elif [ "${action}" = "test" ] ; then
		dotnet test
	fi
	return 0
}


function testTemplates {
	local templateName
	local action

	local passed=0
	local failed=0

	while read -r line ; do
		if [ -n "${line:-}" ] ; then
			templateName="${line%% *}"
			action="${line##* }"

			[ -d "${tmpDir}" ]
			mkdir -p "${tmpDir}/${templateName}-template"
			pushd "${tmpDir}/${templateName}-template"

			testTemplate "${templateName}" "${action}"

			popd
		fi
	done < <( printf "%s\n" "$templates" )

	return 0
}

trap cleanupFunc EXIT
tmpDir="$( mktemp -d )"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
if [[ -f "${script_dir}/nuget.config" ]]; then
    cp "${script_dir}/nuget.config" "${tmpDir}/"
fi

testTemplates
