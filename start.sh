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
		if [ "$extension" = "js" ]; then
			buf+="<script src=\"{{WORKBENCH_WEB_BASE_URL}}/out/vs/patch/$name\"></script>"
		elif [ "$extension" = "css" ]; then
			buf+="<link rel="stylesheet" href=\"{{WORKBENCH_WEB_BASE_URL}}/out/vs/patch/$name\">"
		fi
	done
	sed -E "s|^.+</head>\$|    $buf</head>|" -i "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
else
	if [ -e "$SPATH/code-server/lib/vscode/out/vs/patch" ]; then
		rm "$SPATH/code-server/lib/vscode/out/vs/patch"
	fi
	sed -E "s|^.+</head>\$|    </head>|" -i "$SPATH/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html"
fi

"$SPATH/code-server/bin/code-server" --user-data-dir="$SPATH/user-data" --extensions-dir="$SPATH/extensions" --config "$SPATH/config.yaml" "$@"
