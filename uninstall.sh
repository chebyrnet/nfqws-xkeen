#!/bin/sh
# Remove nfqws-xkeen integration and package files.
set -eu

PREFIX="${PREFIX:-/opt}"
SHARE_DIR="${PREFIX}/share/nfqws-xkeen"
BIN_LINK="${PREFIX}/sbin/nfqws-xkeen"
STATE_DIR="${PREFIX}/var/lib/nfqws-xkeen"

log() { printf 'nfqws-xkeen-uninstall: %s\n' "$*"; }

if [ -x "$BIN_LINK" ]; then
  log "снимаю патч и блок conf..."
  "$BIN_LINK" uninstall || true
elif [ -x "$SHARE_DIR/bin/nfqws-xkeen" ]; then
  "$SHARE_DIR/bin/nfqws-xkeen" uninstall || true
fi

rm -f "$BIN_LINK"
rm -rf "$SHARE_DIR"
log "файлы пакета удалены"
log "бэкапы оставлены в $STATE_DIR (можно удалить вручную)"
log "готово"
