#!/bin/bash

SPATH="$(realpath "$(dirname "$0")")"

env EXTENSION_GALLERY='{\"serviceUrl\": \"https://marketplace.visualstudio.com/_apis/public/gallery\"}' "$SPATH/code-server/bin/code-server" --auth=none --disable-telemetry --user-data-dir="$SPATH/user-data" --extensions-dir="$SPATH/extensions" --disable-workspace-trust --config "$SPATH/config.yaml" "$@"

