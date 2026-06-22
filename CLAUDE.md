# CLAUDE.md — next-packer

## What This Repo Is
One-time infrastructure setup for the lab. Two jobs:
1. **Packer image build** — Ubuntu 24.04 with Docker + Libvirt + QEMU pre-baked, uploaded to MAAS as `custom/ubuntu-24.04-libvirt-host`
2. **MAAS machine registration** — registers HP bare metal servers in MAAS, sets power webhooks, assigns static IPs, waits for commissioning

## When to Run
- **First-time lab setup** — run both workflows once
- **Hardware change** — run `register-machines` for the affected server
- **Image update** — run `build-image` then `register-machines` is NOT needed (image is pulled at deploy time)

## When NOT to Run
Never trigger these workflows as part of a routine rebuild. The 1of3 pipeline (`next-base-baremetal`) handles deploy/release without touching machine registration.

## Workflows
| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `build-image.yml` | `workflow_dispatch` | Builds Packer image, uploads to MAAS |
| `register-machines.yml` | `workflow_dispatch` | Registers HP servers in MAAS, runs commissioning once |

## Plug Mapping
| Machine | MAAS host | IP | Power plug |
|---------|-----------|-----|-----------|
| blue | 192.168.3.91:5240 | 192.168.3.120 | plugB (192.168.4.3) via smart-plug-maas |
| green | 192.168.2.91:5240 | 192.168.2.120 | plugA (192.168.4.2) via smart-plug-maas |

## Key Files
- `packer/build.sh` — Packer build script (wraps Canonical's packer-maas toolchain)
- `terraform/main.tf` — maas_machine resources for blue + green
- `.github/workflows/build-image.yml` — builds + uploads image
- `.github/workflows/register-machines.yml` — TF apply for machine registration

## Six-Repo Family (GROUP 1 — this repo is here)
See CHARTER.md for the full architecture. Short version:
- **GROUP 1 (run once):** vault-access-control, smart-plug-maas, next-packer
- **GROUP 2 (routine):** next-base-baremetal (1of3) → next-base-libvirt (2of3) → next-base-kubernetes (3of3)

## Important Notes
- Commissioning takes 15-30 min on HP ProLiant due to NVMe storage scripts
- The TF `maas_machine` resource commissions without `skip_storage=true` — if it gets stuck, abort via MAAS CLI and recommission manually with `skip_storage=true skip_bmc_config=true`
- Machine hostnames must be `blue` and `green` (no random suffix) — the 1of3 pipeline allocates by hostname
