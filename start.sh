#!/bin/bash

# Read current path
if [ ! -z "$TARGET" ]; then
	SPATH="$TARGET"
else
	SPATH="$(realpath "$(dirname "$0")")"
fi
if [ -z "$SPATH" ]; then
	>&2 echo "ERR: SPATH is null ''"
	exit 1
fi
if [ ! -e "$SPATH" ]; then
	>&2 echo "ERR: SPATH not exist"
	exit 1
fi
MANAGED_PATH="$SPATH/code-server/lib/vscode/out/vs/managed_patch"
PATH_PATH="$SPATH/code-server/lib/vscode/out/vs/patch"

# Push vscode binary path
case ":${PATH}:" in
    *:"$SPATH/bin":*)
	;;
    *)
        export PATH="$SPATH/bin:$PATH"
	;;
esac

# Write top left window icon patch
write_window_appicon() {
	echo ".window-appicon {background-image: url('../patch/$1') !important;}" > "$MANAGED_PATH/window-appicon.css"
}
probe_window_appicon() {
	if [ -e "$SPATH/patch/window-appicon.png" ]; then
		write_window_appicon "window-appicon.png"
	elif [ -e "$SPATH/patch/window-appicon.webp" ]; then
		write_window_appicon "window-appicon.webp"
	elif [ -e "$SPATH/patch/window-appicon.jpg" ]; then
		write_window_appicon "window-appicon.jpg"
	elif [ -e "$SPATH/patch/window-appicon.jpeg" ]; then
		write_window_appicon "window-appicon.jpeg"
	elif [ -e "$SPATH/patch/window-appicon.gif" ]; then
		write_window_appicon "window-appicon.gif"
	else
		[ -e "$MANAGED_PATH/window-appicon.css" ] && rm "$MANAGED_PATH/window-appicon.css"
	fi
}

# Apply css/js injection into workbench.html
create_resource_list() { # SEARCH_PATH, MAPPED_PATH
	local buf=""
	for entry in "$1"/*; do
		name="$(basename -- "$entry")"
		extension="${name##*.}"
		#  TODO: Async sha1sum
		if [ "$extension" = "js" ]; then
			buf+="<script src=\"{{WORKBENCH_WEB_BASE_URL}}/out/vs/$2/$name?r=$(sha1sum "$entry" | awk '{ print $1 }')\"></script>"
		elif [ "$extension" = "css" ]; then
			buf+="<link rel="stylesheet" href=\"{{WORKBENCH_WEB_BASE_URL}}/out/vs/$2/$name?r=$(sha1sum "$entry" | awk '{ print $1 }')\">"
		fi
	done
	printf "%s" "$buf"
}
apply_resource_inject() {
	local buf=""
	buf+="$(create_resource_list "$SPATH/patch" "patch")"
	buf+="$(create_resource_list "$MANAGED_PATH" "managed_patch")"

	sed -E "s|^.+</head>\$|    $buf</head>|" -i "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
}

# Apply pwa metadata patch
apply_pwa_metadata_patch() {
	if [ -e "$SPATH/patch/icons/pwa-icon-512.png" ] && [ -z "$PWA_ICON_PREFIX" ]; then
		export PWA_ICON_PREFIX="{{BASE}}/_static/lib/vscode/out/vs/patch/icons/pwa-icon-"
	fi
	if [ -e "$SPATH/patch/icons/pwa-icon-192.png" ]; then
		sed 's|<link rel="apple-touch-icon" sizes="192x192" href="{{CS_STATIC_BASE}}/src/browser/media/pwa-icon-192\.png" */>|<link rel="apple-touch-icon" sizes="192x192" href="{{BASE}}/_static/lib/vscode/out/vs/patch/icons/pwa-icon-192.png" />|' -i $SPATH/code-server/src/browser/pages/*.html "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
	fi
	if [ -e "$SPATH/patch/icons/pwa-icon-512.png" ]; then
		sed 's|<link rel="apple-touch-icon" sizes="512x512" href="{{CS_STATIC_BASE}}/src/browser/media/pwa-icon-512\.png" */>|<link rel="apple-touch-icon" sizes="512x512" href="{{BASE}}/_static/lib/vscode/out/vs/patch/icons/pwa-icon-512.png" />|' -i $SPATH/code-server/src/browser/pages/*.html "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
	fi

	sed 's|^ *name: req.args."app-name".,$|name: process.env.PWA_NAME \|\| req.args["app-name"],|' -i $SPATH/code-server/out/node/routes/vscode.js
	sed 's|^ *short_name: req.args."app-name".,$|short_name: process.env.PWA_SHORT_NAME \|\| req.args["app-name"],|' -i $SPATH/code-server/out/node/routes/vscode.js
	sed 's|^ *src: `{{BASE}}/_static/src/browser/media/pwa-icon-${size}\.png`,$|src: process.env.PWA_ICON_PREFIX ? (process.env.PWA_ICON_PREFIX + size + (process.env.PWA_ICON_SUFFIX \|\| ".png")) : `{{BASE}}/_static/src/browser/media/pwa-icon-${size}.png`,|' -i $SPATH/code-server/out/node/routes/vscode.js
}

# Apply or undo patches
apply_pwa_metadata_patch
if [ -e "$SPATH/patch" ]; then
	# Applies patches
	# ln -sfn (not [ ! -e X ] && ln -s X) - `-e` follows a symlink to its
	# target, so it's false for a *dangling* symlink left over from a
	# previous SPATH (e.g. after moving $TARGET elsewhere), which meant the
	# guard incorrectly thought no link was there yet and the plain ln -s
	# failed with "File exists". -f overwrites regardless of what's
	# currently there; -n keeps ln from treating an existing PATH_PATH
	# directory as a place to put the link inside rather than the link
	# name itself.
	ln -sfn "$SPATH/patch" "$PATH_PATH"
	mkdir -p "$MANAGED_PATH"
	probe_window_appicon
	apply_resource_inject
else
	# Undo all patches. rm -f (not an [ -e X ] guard) for the same reason
	# as above - it's also correct for a dangling symlink, and does not
	# error when there's nothing to remove.
	rm -f "$SPATH/code-server/lib/vscode/out/vs/patch"
	sed -E "s|^.+</head>\$|    </head>|" -i "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
fi

# Source env file
if [ -e "$SPATH/env" ]; then
	source "$SPATH/env"
fi

exec "$SPATH/code-server/bin/code-server" --user-data-dir="$SPATH/user-data" --extensions-dir="$SPATH/extensions" --config "$SPATH/config.yaml" "$@"
