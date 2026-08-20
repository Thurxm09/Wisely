#!/bin/bash
# Installs user-level (global) Claude Code tools on remote session startup so
# they are available across every project in this environment, not just this
# repo. Best-effort only: everything here writes to $HOME/.claude, which is
# container-local and does NOT survive a fresh session/device - unlike static
# skills (see .claude/skills/), which are git-committed and always present.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

LOG_FILE="$HOME/.claude/skills-bootstrap.log"
mkdir -p "$HOME/.claude"
log() { echo "[$(date -u +%FT%TZ)] $*" >>"$LOG_FILE"; }

log "session-start: tools bootstrap starting"

# 1. impeccable (pbakaus/impeccable) - via Claude Code's own plugin manager
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

# 2. claude-mem (thedotmack/claude-mem) - official CLI installer.
if ! command -v claude-mem >/dev/null 2>&1 && [ ! -d "$HOME/.claude-mem" ]; then
  if npx --yes claude-mem install >>"$LOG_FILE" 2>&1; then
    log "claude-mem: installed"
  else
    log "claude-mem: install failed (network?), skipping"
  fi
else
  log "claude-mem: already installed, skipping"
fi

log "session-start: tools bootstrap finished"
exit 0
