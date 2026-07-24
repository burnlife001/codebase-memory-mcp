#!/usr/bin/env bash

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ── Configurable remotes ─────────────────────────────────────────────────────
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
ORIGIN_REMOTE="${ORIGIN_REMOTE:-origin}"
WORK_BRANCH="${WORK_BRANCH:-burnlife001}"

# MSYS2 bash used for the MinGW build (login shell rebuilds PATH/TMP correctly)
MSYS2_BASH="${MSYS2_BASH:-D:/Programs/msys64/usr/bin/bash.exe}"
BUILD_SCRIPT="$REPO_ROOT/build_win.sh"

# ── Colors ───────────────────────────────────────────────────────────────────
red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
cyan()   { echo -e "\033[36m$*\033[0m"; }

# ── Sync upstream ────────────────────────────────────────────────────────────
# Delegates the full sync workflow (fetch → merge → push → rebase, with stash
# handling and conflict recovery) to scripts/sync-upstream-menu.sh via its
# `sync` CLI shortcut. We keep only the project-specific auto-add-upstream
# behavior here so the menu "just works" on a fresh clone.
sync_upstream() {
  local sync_script="$REPO_ROOT/scripts/sync-upstream-menu.sh"
  if [ ! -f "$sync_script" ]; then
    red "[sync] missing script: $sync_script"
    return 1
  fi

  # Project-specific: auto-add upstream if missing.
  if ! git remote get-url "$UPSTREAM_REMOTE" > /dev/null 2>&1; then
    yellow "Remote '$UPSTREAM_REMOTE' not found. Adding..."
    git remote add "$UPSTREAM_REMOTE" git@github.com:DeusData/codebase-memory-mcp.git
  fi

  bash "$sync_script" sync
}

# ── Build exe ────────────────────────────────────────────────────────────────
build_exe() {
  if [ ! -f "$BUILD_SCRIPT" ]; then
    red "[build-exe] missing build script: $BUILD_SCRIPT"
    return 1
  fi

  echo "[build-exe] Building via MSYS2 MINGW64 login shell..."
  MSYSTEM=MINGW64 "$MSYS2_BASH" -l "$BUILD_SCRIPT"
  local rc=$?
  if [ $rc -ne 0 ]; then
    red "[build-exe] build failed (rc=$rc)"
    return $rc
  fi

  echo "[build-exe] Smoke test: --version"
  "$REPO_ROOT/build/c/codebase-memory-mcp.exe" --version || {
    red "[build-exe] smoke test failed"
    return 1
  }
  green "[build-exe] OK: build/c/codebase-memory-mcp.exe"
}

# ── Menu ─────────────────────────────────────────────────────────────────────
show_menu() {
  clear
  echo "========== codebase-memory-mcp menu =========="
  echo "1. sync-upstream (fetch → merge → push → rebase)"
  echo "2. build-exe (MSYS2 MinGW → smoke test)"
  echo "0. exit"
  echo "=============================================="
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  case "${1:-}" in
    sync|1)
      sync_upstream
      ;;
    build|2)
      build_exe
      ;;
    *)
      while true; do
        show_menu
        read -r -p "请选择: " choice || { echo ""; exit 0; }
        case "$choice" in
          1) sync_upstream ;;
          2) build_exe ;;
          0) echo "Bye."; exit 0 ;;
          *) red "无效选项，请重新输入。" ;;
        esac

        if [ "$choice" != "0" ]; then
          echo ""
          read -r -p "按 Enter 继续..."
        fi
      done
      ;;
  esac
}

main "$@"
