#!/bin/sh
# Patch S51nfqws2 and inject settings block into nfqws2.conf.

# shellcheck source=common.sh
. "${NFQWS_XKEEN_LIB:-$(dirname "$0")}/common.sh"

mktmp() {
  # busybox-friendly temp file
  f="${TMPDIR:-/tmp}/nfqws-xkeen.$$.${1:-tmp}"
  i=0
  while [ -e "$f" ]; do
    i=$((i + 1))
    f="${TMPDIR:-/tmp}/nfqws-xkeen.$$.${1:-tmp}.$i"
  done
  : > "$f" || return 1
  printf '%s' "$f"
}

write_s51_snippet() {
  out=$1
  cat > "$out" <<'EOF'
  # nfqws-xkeen BEGIN
  if [ "${XKEEN_MARK_ONLY:-0}" = "1" ]; then
    XKEEN_ROUTE_MARK="${XKEEN_ROUTE_MARK:-0x10000000}"
    XKEEN_ROUTE_MASK="${XKEEN_ROUTE_MASK:-0x10000000}"
    POLICY_MARK="${XKEEN_ROUTE_MARK}/${XKEEN_ROUTE_MASK}"
    POLICY_EXCLUDE=0
    echo "nfqws-xkeen: mark-only mode POLICY_MARK=$POLICY_MARK"
  fi
  # nfqws-xkeen END
EOF
}

# Remove legacy early-return that disabled stock nfqws2 firewall entirely.
strip_legacy_early_return() {
  infile=$1
  outfile=$2
  awk '
    {
      if ($0 ~ /if \[ "\$\{XKEEN_MARK_ONLY:-0\}" = "1" \]; then/) {
        line=$0
        if ((getline n1) <= 0) { print line; exit }
        if (n1 ~ /^[[:space:]]*return 0[[:space:]]*$/) {
          if ((getline n2) <= 0) { next }
          if (n2 ~ /^[[:space:]]*fi[[:space:]]*$/) next
          print line; print n1; print n2; next
        }
        print line; print n1; next
      }
      print
    }
  ' "$infile" > "$outfile"
}

backup_file() {
  src=$1
  name=$2
  ensure_state_dir
  [ -f "$src" ] || die "нет файла для бэкапа: $src"
  ts=$(date +%Y%m%d%H%M%S 2>/dev/null || echo 0)
  dest="${NFQWS_XKEEN_STATE_DIR}/${name}.${ts}.bak"
  cp -p "$src" "$dest" || die "бэкап не удался: $src"
  latest="${NFQWS_XKEEN_STATE_DIR}/${name}.latest.bak"
  cp -p "$src" "$latest"
  printf '%s\n' "$dest" > "${NFQWS_XKEEN_STATE_DIR}/${name}.lastpath"
  file_sha "$src" > "${NFQWS_XKEEN_STATE_DIR}/${name}.sha"
  ok "бэкап: $dest"
}

s51_is_patched() {
  has_markers "$S51_PATH"
}

conf_has_block() {
  has_markers "$NFQWS2_CONF"
}

insert_snippet_after_policy_empty() {
  infile=$1
  snippet=$2
  outfile=$3
  awk -v snippetf="$snippet" '
    BEGIN { done=0; want_fi=0 }
    {
      print
      if (!done && $0 ~ /^[[:space:]]*POLICY_MARK=""[[:space:]]*$/) {
        want_fi=1
        next
      }
      if (want_fi && !done && $0 ~ /^[[:space:]]*fi[[:space:]]*$/) {
        while ((getline line < snippetf) > 0) print line
        close(snippetf)
        done=1
        want_fi=0
      }
    }
    END { if (!done) exit 2 }
  ' "$infile" > "$outfile"
}

apply_s51_patch() {
  target=${1:-$S51_PATH}
  [ -f "$target" ] || die "нет $target"

  if has_markers "$target"; then
    info "S51 уже содержит патч nfqws-xkeen"
    tmp=$(mktmp s51strip) || die "temp"
    strip_legacy_early_return "$target" "$tmp"
    if ! cmp -s "$target" "$tmp" 2>/dev/null; then
      cp "$tmp" "$target"
      ok "удалён устаревший early-return XKEEN_MARK_ONLY"
    fi
    rm -f "$tmp"
    return 0
  fi

  backup_file "$target" "S51nfqws2"

  tmp1=$(mktmp s51a) || die "temp"
  tmp2=$(mktmp s51b) || die "temp"
  snip=$(mktmp snip) || die "temp"
  write_s51_snippet "$snip"
  strip_legacy_early_return "$target" "$tmp1"

  if ! insert_snippet_after_policy_empty "$tmp1" "$snip" "$tmp2"; then
    rm -f "$tmp1" "$tmp2" "$snip"
    die "не удалось найти место для патча в create_running_config (изменился upstream S51?)"
  fi

  cp "$tmp2" "$target" || die "запись патча не удалась"
  chmod +x "$target" 2>/dev/null || true
  rm -f "$tmp1" "$tmp2" "$snip"
  ok "патч применён к $target"
}

remove_s51_patch() {
  target=${1:-$S51_PATH}
  [ -f "$target" ] || return 0

  if ! has_markers "$target"; then
    info "патч S51 отсутствует"
    return 0
  fi

  backup_file "$target" "S51nfqws2-before-unpatch"
  tmp=$(mktmp s51rm) || die "temp"
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 ~ b { skip=1; next }
    $0 ~ e { skip=0; next }
    skip { next }
    { print }
  ' "$target" > "$tmp"
  cp "$tmp" "$target"
  chmod +x "$target" 2>/dev/null || true
  rm -f "$tmp"
  ok "патч удалён из $target"
}

apply_conf_block() {
  conf=${1:-$NFQWS2_CONF}
  block=${2:-$NFQWS_XKEEN_BLOCK}
  [ -f "$conf" ] || die "нет $conf"
  [ -f "$block" ] || die "нет шаблона $block"

  ensure_state_dir

  if has_markers "$conf"; then
    info "блок nfqws-xkeen в conf уже есть — значения не затираем"
    missing=
    for key in XKEEN_MARK_ONLY XKEEN_ROUTE_MARK XKEEN_ROUTE_MASK; do
      if ! grep -qE "^[[:space:]]*${key}=" "$conf"; then
        missing="$missing $key"
      fi
    done
    if [ -n "$missing" ]; then
      warn "в блоке не хватает:$missing"
    else
      ok "конфиг в порядке"
    fi
    return 0
  fi

  backup_file "$conf" "nfqws2.conf"

  old_only=$(read_conf_var "$conf" XKEEN_MARK_ONLY 2>/dev/null || true)
  old_mark=$(read_conf_var "$conf" XKEEN_ROUTE_MARK 2>/dev/null || true)
  old_mask=$(read_conf_var "$conf" XKEEN_ROUTE_MASK 2>/dev/null || true)

  tmp_clean=$(mktmp confclean) || die "temp"
  strip_orphan_xkeen_vars "$conf" "$tmp_clean"

  tmp_block=$(mktmp confblock) || die "temp"
  cp "$block" "$tmp_block"
  if [ -n "$old_only" ]; then
    sed "s|^XKEEN_MARK_ONLY=.*|XKEEN_MARK_ONLY=$old_only|" "$tmp_block" > "${tmp_block}.n" && mv "${tmp_block}.n" "$tmp_block"
  fi
  if [ -n "$old_mark" ]; then
    sed "s|^XKEEN_ROUTE_MARK=.*|XKEEN_ROUTE_MARK=$old_mark|" "$tmp_block" > "${tmp_block}.n" && mv "${tmp_block}.n" "$tmp_block"
  fi
  if [ -n "$old_mask" ]; then
    sed "s|^XKEEN_ROUTE_MASK=.*|XKEEN_ROUTE_MASK=$old_mask|" "$tmp_block" > "${tmp_block}.n" && mv "${tmp_block}.n" "$tmp_block"
  fi

  tmp_out=$(mktmp confout) || die "temp"
  {
    cat "$tmp_block"
    printf '\n'
    cat "$tmp_clean"
  } > "$tmp_out"

  cp "$tmp_out" "$conf" || die "не удалось записать $conf"
  rm -f "$tmp_clean" "$tmp_block" "$tmp_out"
  ok "блок настроек добавлен в $conf"
}

remove_conf_block() {
  conf=${1:-$NFQWS2_CONF}
  [ -f "$conf" ] || return 0

  if ! has_markers "$conf"; then
    if grep -qE '^[[:space:]]*XKEEN_(MARK_ONLY|ROUTE_MARK|ROUTE_MASK)=' "$conf" 2>/dev/null; then
      backup_file "$conf" "nfqws2.conf-before-unpatch"
      tmp=$(mktmp conforphan) || die "temp"
      strip_orphan_xkeen_vars "$conf" "$tmp"
      cp "$tmp" "$conf"
      rm -f "$tmp"
      ok "удалены одиночные XKEEN_* из conf"
    else
      info "блок conf отсутствует"
    fi
    return 0
  fi

  backup_file "$conf" "nfqws2.conf-before-unpatch"
  tmp=$(mktmp confrm) || die "temp"
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    {
      lines[NR]=$0
    }
    END {
      bidx=0; eidx=0
      for (i=1;i<=NR;i++) {
        if (index(lines[i], b)) bidx=i
        if (index(lines[i], e)) eidx=i
      }
      if (!bidx || !eidx || eidx < bidx) {
        for (i=1;i<=NR;i++) print lines[i]
        exit
      }
      start=bidx; end=eidx
      for (i=bidx-1; i>=1; i--) {
        if (lines[i] ~ /^#{10,}/ || lines[i] ~ /nfqws-xkeen/ || lines[i] ~ /^# Документация/ || lines[i] ~ /^# Маркеры/)
          start=i
        else break
      }
      if (end < NR && lines[end+1] ~ /^#{10,}/) end++
      # drop one blank line after block
      if (end < NR && lines[end+1] ~ /^[[:space:]]*$/) end++
      for (i=1;i<=NR;i++) if (i < start || i > end) print lines[i]
    }
  ' "$conf" > "$tmp"

  tmp2=$(mktmp confrm2) || die "temp"
  strip_orphan_xkeen_vars "$tmp" "$tmp2"
  cp "$tmp2" "$conf"
  rm -f "$tmp" "$tmp2"
  ok "блок настроек удалён из $conf"
}

migrate_legacy_manual() {
  removed=0
  if [ -f "$OLD_S99_PATH" ]; then
    warn "найден ручной $OLD_S99_PATH — отключаю"
    if [ -x "$OLD_S99_PATH" ]; then
      "$OLD_S99_PATH" disable 2>/dev/null || "$OLD_S99_PATH" stop 2>/dev/null || true
    fi
    ensure_state_dir
    mv "$OLD_S99_PATH" "${NFQWS_XKEEN_STATE_DIR}/S99nfqws-xkeen.migrated" 2>/dev/null || rm -f "$OLD_S99_PATH"
    removed=1
  fi
  if [ -f "$OLD_ZZ_PATH" ]; then
    warn "найден ручной $OLD_ZZ_PATH — убираю (restore делает 100-nfqws2.sh)"
    ensure_state_dir
    mv "$OLD_ZZ_PATH" "${NFQWS_XKEEN_STATE_DIR}/zz-nfqws-xkeen.sh.migrated" 2>/dev/null || rm -f "$OLD_ZZ_PATH"
    removed=1
  fi
  [ "$removed" = "1" ] && ok "миграция со старых скриптов выполнена"
  return 0
}

patch_status() {
  echo "=== nfqws-xkeen status ==="
  echo "version: $(pkg_version)"
  if [ -f "$S51_PATH" ]; then
    if s51_is_patched; then
      ok "S51 патч: установлен ($S51_PATH)"
    else
      fail "S51 патч: отсутствует"
    fi
  else
    fail "S51 не найден: $S51_PATH"
  fi

  if [ -f "$NFQWS2_CONF" ]; then
    if conf_has_block; then
      ok "блок conf: есть"
    else
      fail "блок conf: нет"
    fi
    only=$(read_conf_var "$NFQWS2_CONF" XKEEN_MARK_ONLY 2>/dev/null || echo "?")
    mark=$(read_conf_var "$NFQWS2_CONF" XKEEN_ROUTE_MARK 2>/dev/null || echo "?")
    mask=$(read_conf_var "$NFQWS2_CONF" XKEEN_ROUTE_MASK 2>/dev/null || echo "?")
    echo "  XKEEN_MARK_ONLY=$only"
    echo "  XKEEN_ROUTE_MARK=$mark"
    echo "  XKEEN_ROUTE_MASK=$mask"
  else
    fail "nfqws2.conf не найден: $NFQWS2_CONF"
  fi

  if is_nfqws2_running; then
    ok "nfqws2: запущен"
  else
    warn "nfqws2: не запущен"
  fi

  if [ -f "$OLD_S99_PATH" ] || [ -f "$OLD_ZZ_PATH" ]; then
    warn "остались ручные S99/zz — выполните enable"
  fi

  if command -v iptables >/dev/null 2>&1; then
    echo "--- iptables mangle nfqws_post (первые строки) ---"
    iptables -t mangle -L nfqws_post -n -v --line-numbers 2>/dev/null | head -n 20 || warn "цепочка nfqws_post отсутствует"
  fi
}

doctor_checks() {
  echo "=== doctor ==="
  errs=0
  [ -f "$S51_PATH" ] || { fail "нет S51"; errs=$((errs + 1)); }
  [ -f "$NFQWS2_CONF" ] || { fail "нет nfqws2.conf"; errs=$((errs + 1)); }
  s51_is_patched || { fail "S51 не пропатчен — nfqws-xkeen repatch"; errs=$((errs + 1)); }
  conf_has_block || { fail "нет блока в conf — nfqws-xkeen enable"; errs=$((errs + 1)); }
  only=$(read_conf_var "$NFQWS2_CONF" XKEEN_MARK_ONLY 2>/dev/null || echo 0)
  [ "$only" = "1" ] || warn "XKEEN_MARK_ONLY != 1"
  mark=$(read_conf_var "$NFQWS2_CONF" XKEEN_ROUTE_MARK 2>/dev/null || echo "")
  [ -n "$mark" ] || { fail "пустой XKEEN_ROUTE_MARK"; errs=$((errs + 1)); }
  iface=$(read_conf_var "$NFQWS2_CONF" ISP_INTERFACE 2>/dev/null || echo "")
  [ -n "$iface" ] && ok "ISP_INTERFACE=$iface" || warn "ISP_INTERFACE пуст"
  q=$(read_conf_var "$NFQWS2_CONF" NFQUEUE_NUM 2>/dev/null || echo "")
  [ -n "$q" ] && ok "NFQUEUE_NUM=$q" || warn "NFQUEUE_NUM не задан"
  is_nfqws2_running && ok "процесс nfqws2 жив" || { fail "nfqws2 не запущен"; errs=$((errs + 1)); }
  if [ "$errs" -eq 0 ]; then
    ok "doctor: критичных проблем нет"
  else
    fail "doctor: проблем: $errs"
  fi
  return "$errs"
}

enable_integration() {
  migrate_legacy_manual
  apply_conf_block
  apply_s51_patch
  restart_nfqws2
  ok "интеграция включена"
}

disable_integration() {
  conf=$NFQWS2_CONF
  if [ -f "$conf" ] && grep -qE '^[[:space:]]*XKEEN_MARK_ONLY=' "$conf"; then
    backup_file "$conf" "nfqws2.conf-before-disable"
    tmp=$(mktmp dis) || die "temp"
    sed 's/^[[:space:]]*XKEEN_MARK_ONLY=.*/XKEEN_MARK_ONLY=0/' "$conf" > "$tmp"
    cp "$tmp" "$conf"
    rm -f "$tmp"
    ok "XKEEN_MARK_ONLY=0"
  fi
  restart_nfqws2
  ok "mark-only выключен (патч S51 остаётся безвредным при MARK_ONLY=0)"
}

repatch_all() {
  migrate_legacy_manual
  if has_markers "$S51_PATH"; then
    remove_s51_patch
  fi
  apply_s51_patch
  apply_conf_block
  restart_nfqws2
  ok "repatch выполнен"
}

uninstall_integration() {
  migrate_legacy_manual
  remove_s51_patch
  remove_conf_block
  restart_nfqws2
  ok "интеграция снята"
}
