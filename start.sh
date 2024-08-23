#!/bin/bash

if [ ! -z "$TARGET" ]; then
	SPATH="$TARGET"
else
	SPATH="$(realpath "$(dirname "$0")")"
fi

case ":${PATH}:" in
    *:"$SPATH":*)
	;;
    *)
        export PATH="$SPATH/code-server/bin:$PATH"
	;;
esac

"$SPATH/code-server/bin/code-server" --user-data-dir="$SPATH/user-data" --extensions-dir="$SPATH/extensions" --config "$SPATH/config.yaml" "$@"
