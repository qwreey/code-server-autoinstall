#!/bin/bash

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

case ":${PATH}:" in
    *:"$SPATH/bin":*)
	;;
    *)
        export PATH="$SPATH/bin:$PATH"
	;;
esac

if [ -e "$SPATH/patch" ]; then
	[ ! -e "$SPATH/code-server/lib/vscode/out/vs/patch" ] && ln -s "$SPATH/patch" "$SPATH/code-server/lib/vscode/out/vs/patch"
	buf=""
	for entry in "$SPATH/patch"/*; do
		name="$(basename -- "$entry")"
		extension="${name##*.}"
		#  TODO: Async sha1sum
		if [ "$extension" = "js" ]; then
			buf+="<script src=\"{{WORKBENCH_WEB_BASE_URL}}/out/vs/patch/$name?r=$(sha1sum "$entry" | awk '{ print $1 }')\"></script>"
		elif [ "$extension" = "css" ]; then
			buf+="<link rel="stylesheet" href=\"{{WORKBENCH_WEB_BASE_URL}}/out/vs/patch/$name?r=$(sha1sum "$entry" | awk '{ print $1 }')\">"
		fi
	done
	sed -E "s|^.+</head>\$|    $buf</head>|" -i "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
else
	if [ -e "$SPATH/code-server/lib/vscode/out/vs/patch" ]; then
		rm "$SPATH/code-server/lib/vscode/out/vs/patch"
	fi
	sed -E "s|^.+</head>\$|    </head>|" -i "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
fi

if [ -e "$SPATH/env" ]; then
	source "$SPATH/env"
fi

if [ -e "$SPATH/patch/icons/pwa-icon-512.png" ] && [ -z "$PWA_ICON_PREFIX" ]; then
	export PWA_ICON_PREFIX="{{BASE}}/_static/lib/vscode/out/vs/patch/icons/pwa-icon-"
fi
if [ -e "$SPATH/patch/icons/pwa-icon-192.png" ]; then
	sed 's|<link rel="apple-touch-icon" sizes="192x192" href="{{CS_STATIC_BASE}}/src/browser/media/pwa-icon-192\.png" */>|<link rel="apple-touch-icon" sizes="192x192" href="{{BASE}}/_static/lib/vscode/out/vs/patch/icons/pwa-icon-192.png" />|' -i $SPATH/code-server/src/browser/pages/*.html "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
fi
if [ -e "$SPATH/patch/icons/pwa-icon-512.png" ]; then
	sed 's|<link rel="apple-touch-icon" sizes="512x512" href="{{CS_STATIC_BASE}}/src/browser/media/pwa-icon-512\.png" */>|<link rel="apple-touch-icon" sizes="512x512" href="{{BASE}}/_static/lib/vscode/out/vs/patch/icons/pwa-icon-512.png" />|' -i $SPATH/code-server/src/browser/pages/*.html "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
fi

sed 's|^ *name: appName,$|name: process.env.PWA_NAME \|\| appName,|' -i $SPATH/code-server/out/node/routes/vscode.js
sed 's|^ *short_name: appName,$|short_name: process.env.PWA_SHORT_NAME \|\| appName,|' -i $SPATH/code-server/out/node/routes/vscode.js
sed 's|^ *src: `{{BASE}}/_static/src/browser/media/pwa-icon-${size}\.png`,$|src: process.env.PWA_ICON_PREFIX ? (process.env.PWA_ICON_PREFIX + size + (process.env.PWA_ICON_SUFFIX \|\| ".png")) : `{{BASE}}/_static/src/browser/media/pwa-icon-${size}.png`,|' -i $SPATH/code-server/out/node/routes/vscode.js

exec "$SPATH/code-server/bin/code-server" --user-data-dir="$SPATH/user-data" --extensions-dir="$SPATH/extensions" --config "$SPATH/config.yaml" "$@"

