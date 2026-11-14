#!/bin/sh
# Check / fetch updates from GitHub releases.

# shellcheck source=common.sh
. "${NFQWS_XKEEN_LIB:-$(dirname "$0")}/common.sh"

github_api() {
  path=$1
  url="https://api.github.com/repos/${NFQWS_XKEEN_GITHUB}${path}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -A "nfqws-xkeen/$(pkg_version)" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- --user-agent="nfqws-xkeen/$(pkg_version)" "$url"
  else
    die "нужен curl или wget для проверки обновлений"
  fi
}

latest_release_tag() {
  # Prefer Releases API; fall back to tags
  json=$(github_api "/releases/latest" 2>/dev/null) || json=
  tag=$(printf '%s' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  if [ -z "$tag" ]; then
    json=$(github_api "/tags?per_page=1" 2>/dev/null) || json=
    tag=$(printf '%s' "$json" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  fi
  printf '%s' "$tag" | sed 's/^v//'
}

check_update() {
  local_v=$(pkg_version)
  info "локальная версия: $local_v"
  remote_v=$(latest_release_tag) || remote_v=
  if [ -z "$remote_v" ]; then
    warn "не удалось узнать latest на GitHub (нет релиза/сети)"
    return 1
  fi
  info "GitHub latest: $remote_v"
  if [ "$local_v" = "$remote_v" ]; then
    ok "обновлений нет"
    return 0
  fi
  warn "доступна новая версия: $remote_v (сейчас $local_v)"
  echo "Обновление: nfqws-xkeen update - или переустановите install.sh"
  return 2
}

run_remote_install() {
  url="https://raw.githubusercontent.com/${NFQWS_XKEEN_GITHUB}/main/install.sh"
  info "запуск remote install.sh"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" | sh -s -- "$@"
  else
    wget -qO- "$url" | sh -s -- "$@"
  fi
}
