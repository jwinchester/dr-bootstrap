#!/usr/bin/env bash
# Joppa restore script — runs on a freshly-provisioned VM after cloud-init.
# 3 phases, each callable independently for incremental testing.
#
# Usage:
#   bash setup.sh secrets   # phase 0 only: decrypt + materialize secrets
#   bash setup.sh phase1    # tier-0 + tier-1, target ≤15 min
#   bash setup.sh phase2    # tier-2, target ≤30 min
#   bash setup.sh phase3    # tier-3, target ≤60 min
#   bash setup.sh all       # phase1 → phase2 → phase3
#
# Env vars (with sane defaults):
#   AGE_KEY_ENC          path to passphrase-protected age-key.enc
#                          default: $REPO_DIR/secrets/age-key.enc
#   SECRETS_DIR          dir holding *.enc bundles
#                          default: $REPO_DIR/secrets
#   JOPPA_USER           target unix user (default: uluhe)
#   B2_RESTIC_REPO       restic repo URL (default: b2:uluhe-restic)
#   RUNTIME_TMPFS        tmpfs mount for ephemeral plaintext (default: /run/joppa)
#   OPERATOR_CHAT_ID     written into bot env files (default: 8628318993)
#
# Prereqs (cloud-init handles these on a fresh VM):
#   - tailscale, age, restic, git, python3, jq installed
#   - tailnet joined
#   - this repo cloned to /opt/dr-bootstrap
#   - secrets/*.enc present (operator scp'd them OR ../scripts/fetch-secrets-from-b2.sh ran)
#   - secrets/age-key.enc present (operator handoff — phone, wallypad, or scp)
#
# DESTRUCTIVE: phase1's restic restore overwrites /etc/restic, /etc/systemd/system,
# /home/$JOPPA_USER. Intended for fresh VMs only.

set -euo pipefail

# ----------------------------- Configuration ---------------------------------

PHASE="${1:-all}"
LOG=/var/log/joppa-setup.log
JOPPA_USER="${JOPPA_USER:-uluhe}"
JOPPA_HOME="/home/${JOPPA_USER}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGE_KEY_ENC="${AGE_KEY_ENC:-${REPO_DIR}/secrets/age-key.enc}"
SECRETS_DIR="${SECRETS_DIR:-${REPO_DIR}/secrets}"
B2_RESTIC_REPO="${B2_RESTIC_REPO:-b2:uluhe-restic}"
RUNTIME_TMPFS="${RUNTIME_TMPFS:-/run/joppa}"
OPERATOR_CHAT_ID="${OPERATOR_CHAT_ID:-8628318993}"

IDENTITY=""
declare -a CLEANUP_PATHS=()

# ------------------------------- Helpers -------------------------------------

log()          { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
die()          { log "ERROR: $*"; exit 1; }
require_root() { [ "$EUID" -eq 0 ] || die "must run as root"; }

cleanup() {
  for p in "${CLEANUP_PATHS[@]:-}"; do
    [ -f "$p" ] && shred -u "$p" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

# Mount tmpfs so the age identity + plaintext never touch persistent storage.
setup_tmpfs() {
  if ! mountpoint -q "$RUNTIME_TMPFS" 2>/dev/null; then
    mkdir -p "$RUNTIME_TMPFS"
    mount -t tmpfs -o size=8m,mode=0700 tmpfs "$RUNTIME_TMPFS" \
      || die "couldn't mount tmpfs at $RUNTIME_TMPFS"
  fi
  chmod 700 "$RUNTIME_TMPFS"
}

# Decrypt the age private key (passphrase prompt). Idempotent within one run.
decrypt_age_identity() {
  if [ -n "$IDENTITY" ] && [ -f "$IDENTITY" ]; then
    return 0
  fi
  [ -f "$AGE_KEY_ENC" ] || die "missing $AGE_KEY_ENC (operator must scp it onto this VM)"
  setup_tmpfs
  IDENTITY="$RUNTIME_TMPFS/age-id"
  CLEANUP_PATHS+=("$IDENTITY")
  log "decrypting age identity (you will be prompted for the passphrase)"
  age -d -o "$IDENTITY" "$AGE_KEY_ENC" || die "age identity decryption failed"
  chmod 600 "$IDENTITY"
}

# Decrypt $1 (.enc) to $2 (plaintext) using the loaded identity.
decrypt_with_identity() {
  local src="$1" dst="$2"
  [ -f "$src" ] || die "missing source $src"
  [ -n "$IDENTITY" ] && [ -f "$IDENTITY" ] || die "identity not loaded"
  age -d -i "$IDENTITY" -o "$dst" "$src" || die "decryption of $src failed"
  chmod 600 "$dst"
}

# Bail with instructions if the .enc bundles are not on disk.
require_secrets_present() {
  local need=(b2-keys.enc restic-password.enc bot-tokens.enc privacy-cards.csv.enc)
  local missing=()
  local f
  for f in "${need[@]}"; do
    [ -f "$SECRETS_DIR/$f" ] || missing+=("$f")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    log "ERROR: missing .enc files in $SECRETS_DIR: ${missing[*]}"
    log "       Pull them from B2 first:"
    log "         B2_SECRETS_KEY_ID=… B2_SECRETS_KEY=… ../scripts/fetch-secrets-from-b2.sh"
    log "       (envs come from b2-keys.enc / secrets-uluhe entry — operator-supplied first time)"
    exit 1
  fi
}

# ------------------------- Phase 0: secrets ----------------------------------

materialize_secrets() {
  log "phase 0: materialize secrets"
  require_secrets_present
  decrypt_age_identity

  # --- /etc/restic/env (B2 creds for restic-uluhe key) ---
  install -d -m 0700 -o root -g root /etc/restic
  local b2_plain="$RUNTIME_TMPFS/b2-keys.txt"
  CLEANUP_PATHS+=("$b2_plain")
  log "  b2-keys.enc → /etc/restic/env (restic-uluhe key only)"
  decrypt_with_identity "$SECRETS_DIR/b2-keys.enc" "$b2_plain"

  # b2-keys.enc plaintext is B2-console label/value pairs:
  #   keyID:\n<id>\nkeyName:\n<name>\napplicationKey:\n<key>\n\n...
  # Same parser as scripts/push-secrets-to-b2.sh.
  python3 - "$b2_plain" /etc/restic/env <<'PY' || die "b2-keys parse failed"
import sys
src, dst = sys.argv[1], sys.argv[2]
LABELS = {"keyID", "keyName", "applicationKey"}
lines = [ln.rstrip("\n") for ln in open(src)]
entries, cur, i = [], {}, 0
while i < len(lines):
    s = lines[i].strip()
    if not s:
        if cur: entries.append(cur); cur = {}
        i += 1; continue
    if s.endswith(":") and s[:-1] in LABELS:
        label = s[:-1]
        j = i + 1
        while j < len(lines) and not lines[j].strip(): j += 1
        if j < len(lines):
            if label in cur: entries.append(cur); cur = {}
            cur[label] = lines[j].strip()
        i = j + 1
    else:
        i += 1
if cur: entries.append(cur)
target = next((e for e in entries if e.get("keyName") == "restic-uluhe"), None)
if not target:
    sys.stderr.write("FAIL: restic-uluhe not found; available: " +
        ", ".join(repr(e.get("keyName")) for e in entries) + "\n")
    sys.exit(1)
with open(dst, "w") as f:
    f.write(f"B2_ACCOUNT_ID={target['keyID']}\n")
    f.write(f"B2_ACCOUNT_KEY={target['applicationKey']}\n")
PY
  chown root:root /etc/restic/env
  chmod 0600 /etc/restic/env

  # --- /etc/restic/password ---
  log "  restic-password.enc → /etc/restic/password"
  decrypt_with_identity "$SECRETS_DIR/restic-password.enc" /etc/restic/password
  chown root:root /etc/restic/password
  chmod 0600 /etc/restic/password

  # --- /etc/joppa-bots/{mih,midpen,inaturalist}.env ---
  install -d -m 0700 -o root -g root /etc/joppa-bots
  local bots_plain="$RUNTIME_TMPFS/bot-tokens.txt"
  CLEANUP_PATHS+=("$bots_plain")
  log "  bot-tokens.enc → /etc/joppa-bots/{mih,midpen,inaturalist}.env"
  decrypt_with_identity "$SECRETS_DIR/bot-tokens.enc" "$bots_plain"

  # bot-tokens.enc plaintext format (numbered list):
  #   N. @<BotName>
  #      Token: <token>
  #      Created: YYYY-MM-DD
  python3 - "$bots_plain" /etc/joppa-bots "$OPERATOR_CHAT_ID" <<'PY' || die "bot-tokens parse failed"
import re, sys, os
src, dst_dir, chat_id = sys.argv[1], sys.argv[2], sys.argv[3]
NAME_TO_FILE = {
    "Mih_pm_bot":         "mih.env",
    "Midpen_pm_bot":      "midpen.env",
    "My_inaturalist_bot": "inaturalist.env",
}
text = open(src).read()
pairs, current = {}, None
for line in text.splitlines():
    m_name = re.search(r"@([A-Za-z0-9_]+)", line)
    if m_name and m_name.group(1) in NAME_TO_FILE:
        current = m_name.group(1); continue
    m_tok = re.search(r"Token:\s*(\S+)", line)
    if m_tok and current:
        pairs[current] = m_tok.group(1); current = None
missing = [n for n in NAME_TO_FILE if n not in pairs]
if missing:
    sys.stderr.write("FAIL: tokens missing for: " + ", ".join(missing) + "\n")
    sys.exit(1)
for name, fname in NAME_TO_FILE.items():
    p = os.path.join(dst_dir, fname)
    with open(p, "w") as f:
        f.write(f"BOT_TOKEN={pairs[name]}\n")
        f.write(f"OPERATOR_CHAT_ID={chat_id}\n")
    os.chmod(p, 0o600)
PY
  chown -R root:root /etc/joppa-bots

  # --- /etc/joppa-bots/agent.env (joppa-agent + lotor exec env) ---
  # Holds BOT_TOKEN (@Jonclaudemandam_bot) + OPERATOR_CHAT_ID + ANTHROPIC_API_KEY.
  # Both joppa-agent.service AND lotor.service have `EnvironmentFile=/etc/joppa-bots/agent.env`
  # (required, no leading dash). Lotor uses BOT_TOKEN for its own alerts;
  # joppa-agent additionally needs ANTHROPIC_API_KEY for the Claude SDK.
  if [ -f "$SECRETS_DIR/agent-tokens.enc" ]; then
    log "  agent-tokens.enc → /etc/joppa-bots/agent.env"
    decrypt_with_identity "$SECRETS_DIR/agent-tokens.enc" /etc/joppa-bots/agent.env
    chown root:root /etc/joppa-bots/agent.env
    chmod 0600 /etc/joppa-bots/agent.env
  else
    log "  WARN: $SECRETS_DIR/agent-tokens.enc not present — /etc/joppa-bots/agent.env not populated; joppa-agent.service AND lotor.service will fail to start until operator hand-places it"
  fi

  # --- privacy-cards.csv → tmpfs (volatile, never on disk) ---
  log "  privacy-cards.csv.enc → $RUNTIME_TMPFS/privacy-cards.csv (tmpfs, volatile)"
  decrypt_with_identity "$SECRETS_DIR/privacy-cards.csv.enc" "$RUNTIME_TMPFS/privacy-cards.csv"
  CLEANUP_PATHS+=("$RUNTIME_TMPFS/privacy-cards.csv")
  log "        (cards wipe when this script exits; re-decrypt as needed)"

  log "phase 0: secrets materialized"
}

# Rebuild /opt/joppa-bots/ runtime: copy source files from the restored sandbox,
# create venv, pip-install requirements. Idempotent. Requires network.
#
# Why this is here instead of in restic: /opt/joppa-bots/ isn't in the backup
# paths (only /home/uluhe/jon-claude-grand-ham, /home/uluhe/.claude, /etc/restic,
# /etc/systemd/system are), and venv/ is excluded by /etc/restic/excludes.txt
# anyway. Source-of-truth lives in the sandbox; /opt/joppa-bots/ is per-host.
rebuild_joppa_bots_runtime() {
  local src="$JOPPA_HOME/jon-claude-grand-ham/projects/telegram-bots/joppa-bots"
  local dst="/opt/joppa-bots"

  if [ ! -d "$src" ]; then
    log "WARN: $src not found in restored sandbox — skipping joppa-bots runtime rebuild"
    return 0
  fi

  log "rebuilding $dst from $src"
  install -d -m 0755 -o "$JOPPA_USER" -g "$JOPPA_USER" "$dst"

  # Copy .py + requirements.txt (skip systemd/ subdir — units restored via restic)
  for f in joppa_agent.py joppa_alert.py joppa_bot.py requirements.txt; do
    [ -f "$src/$f" ] && install -m 0644 -o "$JOPPA_USER" -g "$JOPPA_USER" "$src/$f" "$dst/$f"
  done

  if [ ! -x "$dst/venv/bin/python" ]; then
    log "  creating venv at $dst/venv"
    sudo -u "$JOPPA_USER" python3 -m venv "$dst/venv" || die "venv creation failed"
  else
    log "  venv already exists; reusing"
  fi

  log "  pip install -r requirements.txt (python-telegram-bot, anthropic)"
  sudo -u "$JOPPA_USER" "$dst/venv/bin/pip" install --quiet --upgrade pip \
    || log "WARN: pip upgrade failed (continuing)"
  sudo -u "$JOPPA_USER" "$dst/venv/bin/pip" install --quiet -r "$dst/requirements.txt" \
    || die "pip install failed"

  chown -R "$JOPPA_USER:$JOPPA_USER" "$dst"
  log "  joppa-bots runtime ready at $dst"
}

# ------------------------------- Phases --------------------------------------

phase1() {
  require_root
  log "=== PHASE 1: tier-0 + tier-1 (target ≤15 min) ==="

  materialize_secrets

  # Pull restic env into this shell.
  set -a; . /etc/restic/env; set +a
  export RESTIC_REPOSITORY="$B2_RESTIC_REPO"
  export RESTIC_PASSWORD_FILE=/etc/restic/password
  export XDG_CACHE_HOME=/var/cache/restic
  install -d -m 0700 /var/cache/restic

  # Snapshots are NOT tagged. Backup paths per /etc/restic/paths.txt are:
  #   /home/uluhe/jon-claude-grand-ham, /home/uluhe/.claude,
  #   /etc/restic, /etc/systemd/system
  # Restoring everything is ~6-8 GB stored, single-digit minutes from B2 → Hetzner.
  log "restic restore latest → /  (overwrites /etc/restic, /etc/systemd, /home/$JOPPA_USER)"
  restic restore latest --target / || die "restic restore failed"

  id "$JOPPA_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$JOPPA_USER"
  chown -R "$JOPPA_USER:$JOPPA_USER" "$JOPPA_HOME"

  systemctl daemon-reload

  rebuild_joppa_bots_runtime

  log "enabling timers + services"
  systemctl enable --now library-intake.service || log "WARN: library-intake start failed"
  systemctl enable --now restic-backup.timer    || log "WARN: restic-backup.timer enable failed"
  systemctl enable --now restic-forget.timer    || log "WARN: restic-forget.timer enable failed"
  systemctl enable --now lotor.timer            || log "WARN: lotor.timer enable failed"

  if [ -f /etc/joppa-bots/agent.env ]; then
    systemctl enable --now joppa-agent.service || log "WARN: joppa-agent failed to start"
  else
    log "SKIP joppa-agent.service: agent.env missing (see materialize_secrets warning)"
  fi

  # TODO: send "Phase 1 complete" via @Jonclaudemandam_bot (needs joppa_alert.py
  # available + agent.env populated)
  log "PHASE 1 complete"
}

phase2() {
  require_root
  log "=== PHASE 2: tier-2 (target ≤30 min) ==="
  # TODO: canvas USFCA sync cron — needs token migration first
  # TODO: verify midpen-* units exist on disk but stay disabled
  #       (politeness rewrite blocker; safety interlock)
  log "PHASE 2 complete (canvas-sync + midpen verify still TODO)"
}

phase3() {
  require_root
  log "=== PHASE 3: tier-3 (target ≤60 min) ==="
  # TODO: defi-agent venv + start
  log "PHASE 3 skipped (defi-agent not yet deployed anywhere)"
}

# ------------------------------- Dispatch ------------------------------------

case "$PHASE" in
  secrets) require_root; materialize_secrets ;;
  phase1)  phase1 ;;
  phase2)  phase2 ;;
  phase3)  phase3 ;;
  all)     phase1 && phase2 && phase3 ;;
  *)       echo "Unknown phase: $PHASE" >&2
           echo "Usage: bash setup.sh {secrets|phase1|phase2|phase3|all}" >&2
           exit 1 ;;
esac
