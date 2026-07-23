#!/usr/bin/env bash

REPO_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
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
sync_upstream() {
  # 1. Check upstream remote exists, auto-add if missing
  if ! git remote get-url "$UPSTREAM_REMOTE" > /dev/null 2>&1; then
    yellow "Remote '$UPSTREAM_REMOTE' not found. Adding..."
    git remote add "$UPSTREAM_REMOTE" git@github.com:DeusData/codebase-memory-mcp.git
  fi

  # 2. Check origin remote exists
  if ! git remote get-url "$ORIGIN_REMOTE" > /dev/null 2>&1; then
    red "Error: remote '$ORIGIN_REMOTE' not found."
    return 1
  fi

  # 3. Stash if worktree is dirty (tracked changes only; untracked files are inert)
  local stashed=false
  if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    yellow "Worktree is dirty. Stashing changes..."
    git stash push -m "auto: stash before sync $(date '+%Y-%m-%d %H:%M:%S')"
    stashed=true
  fi

  # 4. Remember original branch
  local original_branch
  original_branch="$(git rev-parse --abbrev-ref HEAD)"

  # 5. Checkout main, fetch upstream, merge
  echo "[1/4] Fetching $UPSTREAM_REMOTE..."
  git fetch "$UPSTREAM_REMOTE"

  echo "[2/4] Checking out main and merging $UPSTREAM_REMOTE/main..."
  git checkout main
  git merge "$UPSTREAM_REMOTE/main" --no-edit

  # 6. Push to origin
  echo "[3/4] Pushing to $ORIGIN_REMOTE..."
  git push "$ORIGIN_REMOTE" main

  # 7. Checkout original branch and rebase onto main
  echo "[4/4] Rebasing $original_branch onto main..."
  git checkout "$original_branch"
  if ! git rebase main; then
    red "Rebase failed. Resolve conflicts, then run:"
    echo "  git rebase --continue"
    echo "  git stash pop  (if you had stashed changes)"
    return 1
  fi

  # 8. Pop stash if we stashed
  if [ "$stashed" = true ]; then
    echo "Restoring stashed changes..."
    git stash pop
  fi

  green "Sync complete."
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
