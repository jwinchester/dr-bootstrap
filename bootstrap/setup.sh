#!/usr/bin/env bash
# Joppa restore script — runs on a freshly-provisioned VM after cloud-init.
# 3 phases, each callable independently for incremental testing.
#
# Usage:
#   bash setup.sh phase1   # tier-0 + tier-1, target ≤15 min
#   bash setup.sh phase2   # tier-2, target ≤30 min
#   bash setup.sh phase3   # tier-3, target ≤60 min
#   bash setup.sh all      # phase1 -> phase2 -> phase3 sequential
#
# Prereqs (set up by cloud-init):
#   - tailscale + age + restic + git installed
#   - tailnet joined
#   - this repo cloned to /opt/dr-bootstrap

set -euo pipefail

PHASE="${1:-all}"
LOG=/var/log/joppa-setup.log
JOPPA_USER=uluhe
JOPPA_HOME=/home/${JOPPA_USER}

log() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

require_root() {
  [ "$EUID" -eq 0 ] || { log "ERROR: setup.sh must run as root"; exit 1; }
}

# --- TODO: secret materialization ---
# Operator ships passphrase-protected age-key.enc + b2-keys.enc + bot-tokens.enc
# to this VM (via scp, Lotor, or paste). This block prompts ONCE, decrypts the
# age private key, then uses it to decrypt all other .enc bundles.
materialize_secrets() {
  log "phase 0: materialize secrets (TODO)"
  # 1. Read passphrase-protected age private key (operator types passphrase)
  # 2. Decrypt b2-keys.enc -> /etc/restic/env (B2_ACCOUNT_ID, B2_ACCOUNT_KEY)
  # 3. Decrypt restic-password.enc -> /etc/restic/password
  # 4. Decrypt bot-tokens.enc -> /etc/joppa-bots/*.env
  # 5. Decrypt privacy-cards.csv.enc -> kept in memory or written to volatile tmpfs
  return 0
}

phase1() {
  require_root
  log "=== PHASE 1: tier-0 + tier-1 (target ≤15 min) ==="

  materialize_secrets

  # TODO: create joppa user if not exists, set up homedir
  # TODO: restic restore --tag joppa-hot --target / --latest
  #   (restores /home/uluhe/jon-claude-grand-ham subset + /etc/restic + /etc/systemd/system)
  # TODO: install Claude Code, Node 20, Python venv tools, R 4.5
  # TODO: deploy + start telegram bots from /etc/joppa-bots/
  # TODO: send "Phase 1 complete" via @Jonclaudemandam_bot

  log "PHASE 1 complete (skeleton — not yet functional)"
}

phase2() {
  require_root
  log "=== PHASE 2: tier-2 (target ≤30 min) ==="

  # TODO: restic restore --tag joppa-full --target / --latest
  # TODO: chown -R uluhe:uluhe /home/uluhe
  # TODO: enable canvas-sync timer (USFCA + UoA)
  # TODO: restore midpen supervisor/worker units to disk BUT leave disabled
  #       (safety interlock — operator enables manually after politeness rewrite)
  # TODO: send "Phase 2 complete, midpen disabled pending operator" via TG

  log "PHASE 2 complete (skeleton — not yet functional)"
}

phase3() {
  require_root
  log "=== PHASE 3: tier-3 (target ≤60 min) ==="

  # TODO: setup defi-agent venv + dependencies
  # TODO: enable defi-agent systemd unit
  # TODO: send "Phase 3 complete, joppa fully operational" via TG

  log "PHASE 3 complete (skeleton — not yet functional)"
}

case "$PHASE" in
  phase1)  phase1 ;;
  phase2)  phase2 ;;
  phase3)  phase3 ;;
  all)     phase1 && phase2 && phase3 ;;
  *)       echo "Unknown phase: $PHASE" >&2; exit 1 ;;
esac
