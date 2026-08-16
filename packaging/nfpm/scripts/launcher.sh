#!/bin/sh
APPDIR="/usr/share/mechanix/mechanix-notes"
exec "$APPDIR/mechanix_notes" --bundle="$APPDIR" "$@"
