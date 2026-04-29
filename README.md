# dr-bootstrap

The first thing you clone onto a fresh VM during joppa failover. Provisions a new primary host (Hetzner / DigitalOcean / Oracle), restores the sandbox from B2 via restic, and brings joppa back online.

## Status

**Skeleton only.** Vendor Terraform is stubbed pending API tokens. `setup.sh` phases are sketches. `./uluhe` is an argparse shell.

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
- [ ] `setup.sh` Phase 1 actually wired to restic + age-key.enc
- [ ] `./uluhe` CLI: replace argparse stubs with vendor logic
- [ ] cloud-init.yaml: bake in tailscale + claude-code preinstall
- [ ] Mirror workflow: Codeberg push + B2 tarball
- [ ] Fire-drill #1 against DO test VM
