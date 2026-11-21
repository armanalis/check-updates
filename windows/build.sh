#!/bin/zsh
# Builds CheckUpdates.exe (Windows) on this Mac, runs the parser tests, and copies the exe into the website.
set -e
cd "$(dirname "$0")"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
DOTNET="${DOTNET:-$HOME/.dotnet/dotnet}"
"$DOTNET" run --project tests
"$DOTNET" build CheckUpdates.csproj -c Release -nologo -v quiet
cp bin/Release/net48/CheckUpdates.exe ../website/public/CheckUpdates.exe
echo "Built: website/public/CheckUpdates.exe"
