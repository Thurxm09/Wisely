#!/bin/bash
# Installs user-level (global) Claude Code skills on remote session startup so
# they are available across every project in this environment, not just Wisely.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

LOG_FILE="$HOME/.claude/skills-bootstrap.log"
mkdir -p "$HOME/.claude"
log() { echo "[$(date -u +%FT%TZ)] $*" >>"$LOG_FILE"; }

log "session-start: skills bootstrap starting"

# 1. task-observer (rebelytics/one-skill-to-rule-them-all)
# Manual copy: SKILL.md + references/ live at the repo root.
if [ ! -f "$HOME/.claude/skills/task-observer/SKILL.md" ]; then
  TMP_DIR="$(mktemp -d)"
  if git clone --depth 1 https://github.com/rebelytics/one-skill-to-rule-them-all "$TMP_DIR" >>"$LOG_FILE" 2>&1; then
    mkdir -p "$HOME/.claude/skills/task-observer"
    if cp -r "$TMP_DIR/SKILL.md" "$TMP_DIR/references" "$HOME/.claude/skills/task-observer/" 2>>"$LOG_FILE"; then
      log "task-observer: installed"
    else
      log "task-observer: copy failed"
    fi
  else
    log "task-observer: clone failed (network?), skipping"
  fi
  rm -rf "$TMP_DIR"
else
  log "task-observer: already installed, skipping"
fi

# 2. impeccable (pbakaus/impeccable) - via Claude Code's own plugin manager
# (git-based; the `npx impeccable install` CDN download is blocked in some
# sandboxed environments, so this is the more reliable path here).
if ! claude plugin list 2>/dev/null | grep -q "impeccable@impeccable"; then
  if claude plugin marketplace add pbakaus/impeccable >>"$LOG_FILE" 2>&1 \
      && claude plugin install impeccable >>"$LOG_FILE" 2>&1; then
    log "impeccable: installed"
  else
    log "impeccable: install failed (network?), skipping"
  fi
else
  log "impeccable: already installed, skipping"
fi

# 3. claude-mem (thedotmack/claude-mem) - official CLI installer.
if ! command -v claude-mem >/dev/null 2>&1 && [ ! -d "$HOME/.claude-mem" ]; then
  if npx --yes claude-mem install >>"$LOG_FILE" 2>&1; then
    log "claude-mem: installed"
  else
    log "claude-mem: install failed (network?), skipping"
  fi
else
  log "claude-mem: already installed, skipping"
fi

# 4. vercel-labs/skills CLI ("skills" npm package) - installed globally so the
#    `skills` command is available in every session without npx.
if ! command -v skills >/dev/null 2>&1; then
  if npm install -g skills >>"$LOG_FILE" 2>&1; then
    log "skills CLI: installed"
  else
    log "skills CLI: install failed (network?), skipping"
  fi
else
  log "skills CLI: already installed, skipping"
fi

log "session-start: skills bootstrap finished"
exit 0
