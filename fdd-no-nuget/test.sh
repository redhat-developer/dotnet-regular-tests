#!/usr/bin/bash

set +x

  # Create the nuget.config with <clear /> to block NuGet
cat <<EOF >nuget.config
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
  </packageSources>
</configuration>
EOF

dotnet publish

if [ $? -eq 1 ]; then
  echo "FAIL: unable to publish FFD without nuget.org access"
  exit 1
fi

echo "PASS: successfully published FDD without nuget.org access"