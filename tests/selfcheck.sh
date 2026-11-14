#!/bin/sh
# Self-check for patcher against temp/ fixtures (or local copies).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d /tmp/nfqws-xkeen-test.XXXXXX 2>/dev/null || echo "/tmp/nfqws-xkeen-test.$$")
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

# Prefer fixtures from sibling temp/ (dev workspace) or tests/fixtures
FIXTURE_S51=
FIXTURE_CONF=
for cand in \
  "$ROOT/../temp/etc/init.d/S51nfqws2" \
  "$ROOT/tests/fixtures/S51nfqws2" \
  "$ROOT/../temp/etc/nfqws2/nfqws2.conf"
do
  :
done

if [ -f "$ROOT/../temp/etc/init.d/S51nfqws2" ]; then
  FIXTURE_S51="$ROOT/../temp/etc/init.d/S51nfqws2"
  FIXTURE_CONF="$ROOT/../temp/etc/nfqws2/nfqws2.conf"
elif [ -f "$ROOT/tests/fixtures/S51nfqws2" ]; then
  FIXTURE_S51="$ROOT/tests/fixtures/S51nfqws2"
  FIXTURE_CONF="$ROOT/tests/fixtures/nfqws2.conf"
else
  echo "FAIL: нет fixtures (положи temp/ рядом или tests/fixtures/)"
  exit 1
fi

cp "$FIXTURE_S51" "$WORK/S51nfqws2"
cp "$FIXTURE_CONF" "$WORK/nfqws2.conf"
chmod +x "$WORK/S51nfqws2"

export NFQWS_XKEEN_ROOT="$ROOT"
export NFQWS_XKEEN_STATE_DIR="$WORK/state"
export S51_PATH="$WORK/S51nfqws2"
export NFQWS2_CONF="$WORK/nfqws2.conf"
mkdir -p "$NFQWS_XKEEN_STATE_DIR"

# stub restart
restart_nfqws2() { echo "restart stub"; }

# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"
# shellcheck source=../lib/patch.sh
. "$ROOT/lib/patch.sh"

echo "== apply conf block =="
apply_conf_block
grep -q "$MARKER_BEGIN" "$NFQWS2_CONF"
grep -q 'XKEEN_MARK_ONLY=1' "$NFQWS2_CONF"
grep -q 'XKEEN_ROUTE_MARK=0x10000000' "$NFQWS2_CONF"
# no duplicate orphan at top after migration
count=$(grep -cE '^[[:space:]]*XKEEN_MARK_ONLY=' "$NFQWS2_CONF")
[ "$count" -eq 1 ]

echo "== apply twice (idempotent conf) =="
apply_conf_block
count=$(grep -c "$MARKER_BEGIN" "$NFQWS2_CONF")
[ "$count" -eq 1 ]

echo "== apply S51 patch (strips legacy early-return) =="
apply_s51_patch
grep -q "$MARKER_BEGIN" "$S51_PATH"
grep -q 'POLICY_MARK="${XKEEN_ROUTE_MARK}/${XKEEN_ROUTE_MASK}"' "$S51_PATH"
# legacy early return in _firewall_start must be gone
if grep -A2 'XKEEN_MARK_ONLY' "$S51_PATH" | grep -q 'return 0'; then
  # only allowed inside create_running_config snippet? snippet has no return 0
  if awk '/_firewall_start/,/^}$/' "$S51_PATH" | grep -q 'return 0'; then
    # check specifically the XKEEN early return pattern
    if awk '
      /_firewall_start/ {in=1}
      in && /XKEEN_MARK_ONLY/ {hit=1}
      hit && /return 0/ {found=1}
      in && /^}/ {in=0; hit=0}
      END { exit found?0:1 }
    ' "$S51_PATH"; then
      echo "FAIL: early-return still in _firewall_start"
      exit 1
    fi
  fi
fi

echo "== apply S51 twice =="
apply_s51_patch
count=$(grep -c "$MARKER_BEGIN" "$S51_PATH")
[ "$count" -eq 1 ]

echo "== backups exist =="
[ -f "$NFQWS_XKEEN_STATE_DIR/S51nfqws2.latest.bak" ]
[ -f "$NFQWS_XKEEN_STATE_DIR/nfqws2.conf.latest.bak" ]

echo "== remove conf block =="
remove_conf_block
! grep -q "$MARKER_BEGIN" "$NFQWS2_CONF"
! grep -qE '^[[:space:]]*XKEEN_MARK_ONLY=' "$NFQWS2_CONF"

echo "== remove S51 patch =="
remove_s51_patch
! grep -q "$MARKER_BEGIN" "$S51_PATH"

echo "== CLI resolves ROOT via symlink =="
mkdir -p "$WORK/sbin"
ln -sf "$ROOT/bin/nfqws-xkeen" "$WORK/sbin/nfqws-xkeen"
out=$("$WORK/sbin/nfqws-xkeen" help 2>&1) || {
  echo "FAIL: CLI via symlink: $out"
  exit 1
}
printf '%s\n' "$out" | grep -q 'Использование: nfqws-xkeen'

echo "OK selfcheck passed"
