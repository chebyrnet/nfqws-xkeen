#!/bin/sh
# Install nfqws-xkeen onto Keenetic Entware.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/chebyrnet/nfqws-xkeen/main/install.sh | sh
#   sh install.sh [--from-dir /path/to/checkout] [--no-enable]

set -eu

GITHUB_REPO="chebyrnet/nfqws-xkeen"
PREFIX="${PREFIX:-/opt}"
SHARE_DIR="${PREFIX}/share/nfqws-xkeen"
BIN_LINK="${PREFIX}/sbin/nfqws-xkeen"
STATE_DIR="${PREFIX}/var/lib/nfqws-xkeen"
FROM_DIR=
DO_ENABLE=1
TMP_SRC=

log() { printf 'nfqws-xkeen-install: %s\n' "$*"; }
die() { printf 'nfqws-xkeen-install: ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
  [ -n "$TMP_SRC" ] && [ -d "$TMP_SRC" ] && rm -rf "$TMP_SRC" || true
}
trap cleanup EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    --from-dir) FROM_DIR=$2; shift 2 ;;
    --no-enable) DO_ENABLE=0; shift ;;
    -h|--help)
      echo "Usage: install.sh [--from-dir DIR] [--no-enable]"
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done

download_release_or_main() {
  dest=$1
  mkdir -p "$dest"
  command -v tar >/dev/null 2>&1 || die "нужна команда: tar"
  url_tgz="https://github.com/${GITHUB_REPO}/archive/refs/heads/main.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url_tgz" | tar -xz -C "$dest" --strip-components=1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url_tgz" | tar -xz -C "$dest" --strip-components=1
  else
    die "нужен curl или wget"
  fi
}

install_files() {
  src=$1
  [ -f "$src/bin/nfqws-xkeen" ] || die "в источнике нет bin/nfqws-xkeen: $src"
  [ -f "$src/lib/patch.sh" ] || die "в источнике нет lib/patch.sh"
  [ -f "$src/conf/nfqws2-xkeen.block" ] || die "в источнике нет conf/nfqws2-xkeen.block"

  mkdir -p "$SHARE_DIR" "$STATE_DIR" "${PREFIX}/sbin"
  rm -rf "${SHARE_DIR}.new"
  mkdir -p "${SHARE_DIR}.new"
  cp -a "$src/bin" "$src/lib" "$src/conf" "${SHARE_DIR}.new/"
  [ -f "$src/VERSION" ] && cp "$src/VERSION" "${SHARE_DIR}.new/"
  [ -f "$src/LICENSE" ] && cp "$src/LICENSE" "${SHARE_DIR}.new/"
  rm -rf "${SHARE_DIR}.old"
  if [ -d "$SHARE_DIR" ]; then
    mv "$SHARE_DIR" "${SHARE_DIR}.old"
  fi
  mv "${SHARE_DIR}.new" "$SHARE_DIR"
  rm -rf "${SHARE_DIR}.old"

  chmod +x "$SHARE_DIR/bin/nfqws-xkeen"
  ln -sf "$SHARE_DIR/bin/nfqws-xkeen" "$BIN_LINK"
  log "установлено в $SHARE_DIR"
  log "CLI: $BIN_LINK"
}

main() {
  src=
  if [ -n "$FROM_DIR" ]; then
    src=$FROM_DIR
  elif [ -f "$(dirname "$0")/bin/nfqws-xkeen" ]; then
    src=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
  else
    TMP_SRC=${TMPDIR:-/tmp}/nfqws-xkeen-install.$$
    rm -rf "$TMP_SRC"
    mkdir -p "$TMP_SRC"
    log "скачиваю main с GitHub..."
    download_release_or_main "$TMP_SRC"
    src=$TMP_SRC
  fi

  install_files "$src"

  export NFQWS_XKEEN_ROOT="$SHARE_DIR"
  export NFQWS_XKEEN_STATE_DIR="$STATE_DIR"

  if [ ! -f /opt/etc/init.d/S51nfqws2 ]; then
    log "WARN: нет /opt/etc/init.d/S51nfqws2 — сначала установите nfqws2"
  fi
  if [ ! -f /opt/etc/nfqws2/nfqws2.conf ]; then
    log "WARN: нет /opt/etc/nfqws2/nfqws2.conf"
  fi

  if [ "$DO_ENABLE" = "1" ] && [ -f /opt/etc/init.d/S51nfqws2 ] && [ -f /opt/etc/nfqws2/nfqws2.conf ]; then
    log "включаю интеграцию..."
    "$BIN_LINK" enable
  else
    log "пропуск enable; позже: nfqws-xkeen enable"
  fi

  log "готово. Запуск меню: nfqws-xkeen"
}

main
