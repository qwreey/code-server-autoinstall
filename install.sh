#!/bin/bash

if [ ! -z "$TARGET" ]; then
	SPATH="$TARGET"
else
	SPATH="$(realpath "$(dirname "$0")")"
fi

# Timecheck (prevent spam)
NOW="$(date +%s)"
TIME_FILE="$SPATH/last-check"
if [ -e "$SPATH/code-server" ] && [ -e "$TIME_FILE" ]; then
	if (( $NOW-"$(cat $TIME_FILE)" < 3600 )); then
		exit 0
	fi
fi
printf "%s" "$NOW" > "$TIME_FILE"

# Version check
while true; do
	LATEST_CURL="$(curl -s https://github.com/coder/code-server/releases/latest -i)"
	[ "$?" == '0' ] && break
	echo "Failed to fetch latest version from https://github.com/coder/code-server/releases/latest"
	echo "Retrying after 10 seconds..."
	sleep 10
done
LATEST="$(printf "%s" "$LATEST_CURL" | grep location: | sed -r 's|location: https://github\.com/coder/code\-server/releases/tag/v||' | tr -d '\r')"
echo "Fetched latest version: $LATEST"
VERSION_FILE="$SPATH/installed-version"
[ -e "$SPATH/code-server" ] && [ -e "$VERSION_FILE" ] && CURRENT="$(cat "$VERSION_FILE")"
if [ "x$LATEST" == "x$CURRENT" ]; then
	exit 0
fi
echo "Installing..."

# Download
[ -e "$SPATH/code-server" ] && rm -rf "$SPATH/code-server"
mkdir -p "$SPATH/code-server"
curl -fL https://github.com/coder/code-server/releases/download/v$LATEST/code-server-$LATEST-linux-amd64.tar.gz \
  | tar -C "$SPATH/code-server" -xz --strip-components=1
if [ "$?" != '0' ]; then
	echo "Download failed."
	exit 1
fi

# Create helper bin
# ln -sf (not a separate [ -e X ] && rm X + plain ln -s) - `-e` follows a
# symlink to its target, so it's false for a *dangling* symlink left over
# from a previous SPATH (e.g. after moving $TARGET elsewhere), which meant
# the guard never fired and the plain ln -s below failed with "File
# exists". -f overwrites regardless of what's currently there.
mkdir -p "$SPATH/bin"
ln -sf "$SPATH/code-server/lib/vscode/bin/helpers/browser.sh" "$SPATH/bin/browser.sh"
# Newer code-server releases ship remote-cli's wrapper without a .sh
# extension (older ones had it) - resolve whichever actually exists instead
# of hardcoding one, so this doesn't silently dangle again on the next
# upstream rename.
CLI_SCRIPT="$SPATH/code-server/lib/vscode/bin/remote-cli/code-server"
[ -e "$CLI_SCRIPT" ] || CLI_SCRIPT="$CLI_SCRIPT.sh"
ln -sf "$CLI_SCRIPT" "$SPATH/bin/code"
ln -sf "$CLI_SCRIPT" "$SPATH/bin/code-server"

# Save version
CURLSTATE="$?"
[ "$CURLSTATE" == '0' ] && printf "%s" "$LATEST" > "$VERSION_FILE"
exit "$?"
