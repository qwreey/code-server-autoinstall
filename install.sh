#!/bin/bash

SPATH="$(realpath "$(dirname "$0")")"

# Version check
LATEST="$(curl https://github.com/coder/code-server/releases/latest -i | grep location: | sed -r 's|location: https://github\.com/coder/code\-server/releases/tag/v||' | tr -d '\r')"
VERSION_FILE="$SPATH/installed-version"
[ -e "$VERSION_FILE" ] && CURRENT="$(cat "$VERSION_FILE")"
if [ "x$LATEST" == "x$CURRENT" ]; then
	exit 0
fi

# Download
[ -e "$SPATH/code-server" ] && rm -rf "$SPATH/code-server"
mkdir -p "$SPATH/code-server"
curl -fL https://github.com/coder/code-server/releases/download/v$LATEST/code-server-$LATEST-linux-amd64.tar.gz \
  | tar -C "$SPATH/code-server" -xz --strip-components=1

# Save version
CURLSTATE="$?"
[ "$CURLSTATE" == '0' ] && printf "%s" "$LATEST" > "$VERSION_FILE"
exit "$?"

