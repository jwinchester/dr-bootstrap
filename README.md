# dr-bootstrap

The first thing you clone onto a fresh VM during joppa failover. Provisions a new primary host (Hetzner / DigitalOcean / Oracle), restores the sandbox from B2 via restic, and brings joppa back online.

## Status

**Skeleton.** Vendor Terraform is stubbed pending API tokens. `setup.sh` phases are sketches. `./uluhe status` is real (SSH-based health check on the current primary); `./uluhe switch/surge/--hold` are still argparse stubs.

### `./uluhe status` (working)

Run from wallypad or anywhere with Tailscale + ssh access to `uluhe@hetz-1`. Reports OK/WARN/FAIL for: ssh reach, tailscaled, syncthing@uluhe, joppa-agent.service (with crash-loop detection), library-intake, restic-backup.timer + restic-forget.timer, last restic-backup result + age, disk %, mem/load, uptime. Color-coded; no B2 hits required, so safe to run when B2 caps are exhausted.

Override target: `ULUHE_PRIMARY=other-host ./uluhe status` (defaults to `hetz-1`).

## What this repo contains

- `terraform/` — per-vendor Terraform configs (cloud-init bootstraps a fresh VM)
- `bootstrap/setup.sh` — 3-phase restore script run on a freshly-provisioned VM
- `bootstrap/cloud-init.yaml` — minimal cloud-init that installs git + clones this repo + runs setup.sh
- `uluhe` — operator CLI: `./uluhe switch <vendor>`, `./uluhe status`, `./uluhe surge`, `./uluhe --hold`
- `.github/workflows/mirror-nightly.yml` — nightly mirror to Codeberg + B2 tarball

## Failover flow (target)

1. Operator: `./uluhe switch do` (on wallypad or any laptop)
2. Terraform provisions DO Standard-4GB, injects Tailscale auth key + cloud-init
3. New VM boots, runs cloud-init, clones this repo, runs `setup.sh`
4. `setup.sh` Phase 1 (≤15 min): tailscale up, restic restore hot subset, start telegram bots
5. `setup.sh` Phase 2 (≤30 min): restic restore full sandbox, canvas mirror sync, midpen daemons restored but disabled
6. `setup.sh` Phase 3 (≤60 min): defi-agent venv + start
7. Operator provides age passphrase via Lotor prompt → secrets unlocked

## Design reference

Canonical: [`scratch/dr-design/DESIGN_v2.md`](https://github.com/...) in the joppa sandbox.

## TODO before this can actually fail over

- [ ] Hetzner / DO / Oracle API tokens stored age-encrypted, decrypted into Terraform variables at runtime
- [ ] Terraform remote state in B2 (or local fallback)
- [x] `setup.sh` Phase 1 wired to restic + age-key.enc + joppa-bots venv rebuild (2026-04-30) — materialize_secrets + restic restore + rebuild_joppa_bots_runtime live; phase2/3 still skeletons
- [ ] `setup.sh`: agent.env + ANTHROPIC_API_KEY DR gap (out of bot-tokens.enc scope) — operator hand-place required after failover; both joppa-agent.service AND lotor.service depend on this file
- [ ] `./uluhe switch <vendor>`: replace stub with vendor provisioning logic
- [x] `./uluhe status`: real health check (2026-04-29)
- [ ] cloud-init.yaml: bake in tailscale + claude-code preinstall
- [ ] Mirror workflow: Codeberg push + B2 tarball
- [ ] Fire-drill #1 against DO test VM
- [x] B2 caps raised (2026-04-30) — $1/day on Storage/Bandwidth/Class B/C with 80% email alerts
