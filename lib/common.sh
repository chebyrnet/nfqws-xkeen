#!/bin/sh
# Shared helpers for nfqws-xkeen (busybox ash).

NFQWS_XKEEN_NAME="nfqws-xkeen"
NFQWS_XKEEN_GITHUB="chebyrnet/nfqws-xkeen"

# Resolve package root: installed layout or repo checkout.
if [ -z "$NFQWS_XKEEN_ROOT" ]; then
  _self=$0
  case "$_self" in
    */*) _dir=$(CDPATH= cd -- "$(dirname "$_self")" && pwd) ;;
    *) _dir=$(pwd) ;;
  esac
  if [ -d "$_dir/../lib" ] && [ -f "$_dir/../lib/common.sh" ]; then
    NFQWS_XKEEN_ROOT=$(CDPATH= cd -- "$_dir/.." && pwd)
  elif [ -d /opt/share/nfqws-xkeen ]; then
    NFQWS_XKEEN_ROOT=/opt/share/nfqws-xkeen
  else
    NFQWS_XKEEN_ROOT=$_dir
  fi
fi

NFQWS_XKEEN_LIB="${NFQWS_XKEEN_ROOT}/lib"
NFQWS_XKEEN_CONF_DIR="${NFQWS_XKEEN_ROOT}/conf"
NFQWS_XKEEN_BLOCK="${NFQWS_XKEEN_CONF_DIR}/nfqws2-xkeen.block"
NFQWS_XKEEN_VERSION_FILE="${NFQWS_XKEEN_ROOT}/VERSION"
NFQWS_XKEEN_STATE_DIR="${NFQWS_XKEEN_STATE_DIR:-/opt/var/lib/nfqws-xkeen}"

S51_PATH="${S51_PATH:-/opt/etc/init.d/S51nfqws2}"
NFQWS2_CONF="${NFQWS2_CONF:-/opt/etc/nfqws2/nfqws2.conf}"
OLD_S99_PATH="${OLD_S99_PATH:-/opt/etc/init.d/S99nfqws-xkeen}"
OLD_ZZ_PATH="${OLD_ZZ_PATH:-/opt/etc/ndm/netfilter.d/zz-nfqws-xkeen.sh}"

MARKER_BEGIN="# nfqws-xkeen BEGIN"
MARKER_END="# nfqws-xkeen END"

DEFAULT_ROUTE_MARK="0x10000000"
DEFAULT_ROUTE_MASK="0x10000000"

# Colors only on TTY
if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_DIM='\033[2m'
  C_RED='\033[31m'
  C_GREEN='\033[32m'
  C_YELLOW='\033[33m'
  C_BLUE='\033[34m'
  C_MAGENTA='\033[35m'
  C_CYAN='\033[36m'
  C_BCYAN='\033[1;36m'
  C_BMAGENTA='\033[1;35m'
  C_BYELLOW='\033[1;33m'
else
  C_RESET= C_BOLD= C_DIM= C_RED= C_GREEN= C_YELLOW= C_BLUE= C_MAGENTA= C_CYAN=
  C_BCYAN= C_BMAGENTA= C_BYELLOW=
fi

log() { printf '%s\n' "${NFQWS_XKEEN_NAME}: $*"; }
ok() { printf "${C_GREEN}[OK]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$*"; }
fail() { printf "${C_RED}[FAIL]${C_RESET} %s\n" "$*"; }
info() { printf "${C_CYAN}[INFO]${C_RESET} %s\n" "$*"; }

die() {
  fail "$*"
  exit 1
}

pkg_version() {
  if [ -f "$NFQWS_XKEEN_VERSION_FILE" ]; then
    tr -d ' \r\n' < "$NFQWS_XKEEN_VERSION_FILE"
  else
    echo "0.0.0"
  fi
}

ensure_state_dir() {
  mkdir -p "$NFQWS_XKEEN_STATE_DIR" || die "не удалось создать $NFQWS_XKEEN_STATE_DIR"
}

file_sha() {
  f=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v sha256 >/dev/null 2>&1; then
    sha256 -q "$f" 2>/dev/null || sha256 "$f" | awk '{print $NF}'
  else
    # busybox cksum fallback
    cksum "$f" | awk '{print $1"-"$2}'
  fi
}

has_markers() {
  f=$1
  [ -f "$f" ] || return 1
  grep -q "$MARKER_BEGIN" "$f" 2>/dev/null && grep -q "$MARKER_END" "$f" 2>/dev/null
}

# Remove lines between markers inclusive (and optional decorative #### lines around them).
strip_marked_block() {
  infile=$1
  outfile=$2
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 ~ b { skip=1; next }
    $0 ~ e { skip=0; next }
    skip { next }
    { print }
  ' "$infile" > "$outfile"
}

# Strip orphan XKEEN_* lines that sat outside our block (manual install leftovers).
strip_orphan_xkeen_vars() {
  infile=$1
  outfile=$2
  awk '
    /^[[:space:]]*XKEEN_MARK_ONLY=/ { next }
    /^[[:space:]]*XKEEN_ROUTE_MARK=/ { next }
    /^[[:space:]]*XKEEN_ROUTE_MASK=/ { next }
    { print }
  ' "$infile" > "$outfile"
}

read_conf_var() {
  # read_conf_var FILE VAR -> print value without quotes
  conf=$1
  var=$2
  [ -f "$conf" ] || return 1
  # shellcheck disable=SC2162
  line=$(grep -E "^[[:space:]]*${var}=" "$conf" 2>/dev/null | tail -n 1) || return 1
  [ -n "$line" ] || return 1
  val=${line#*=}
  val=$(printf '%s' "$val" | sed 's/^["'\'']//; s/["'\'']$//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//')
  printf '%s' "$val"
}

is_nfqws2_running() {
  pidfile=/opt/var/run/nfqws2.pid
  [ -f "$pidfile" ] || return 1
  pid=$(cat "$pidfile" 2>/dev/null) || return 1
  case "$pid" in
    '' | *[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null
}

restart_nfqws2() {
  if [ -x "$S51_PATH" ]; then
    info "перезапуск nfqws2..."
    "$S51_PATH" restart || warn "restart nfqws2 вернул ошибку"
  else
    warn "нет $S51_PATH - перезапустите nfqws2 вручную"
  fi
}
