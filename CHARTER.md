# Charter: next-packer

## Role in Family
**One-time infrastructure setup — run once per hardware install or image update.**

This repo has two jobs:
1. **Build** the Ubuntu 24.04 golden image (Packer + Canonical's packer-maas tooling), pre-baked with Docker, Libvirt, and QEMU — then upload it to MAAS as `custom/ubuntu-24.04-libvirt-host`
2. **Register** the HP bare metal servers in MAAS (commission, set power webhooks, assign static IPs)

Neither of these is a routine rebuild operation. Both workflows are `workflow_dispatch` only.

## Why This Repo Exists
The `next-base-baremetal` 1of3 pipeline must not commission hardware on every rebuild. Commissioning (MAAS inventorying hardware, running test scripts) takes 15-30 minutes and can fail on HP ProLiant NVMe due to storage scripts. It is a one-time operation per hardware setup.

Separating Packer + machine registration here means 1of3 only does deploy/release cycles (~10-12 min), never commissioning.

## Workflows

| Workflow | Trigger | When to Run |
|----------|---------|-------------|
| `build-image.yml` | Manual | When the base OS image needs updating (new packages, Ubuntu point release) |
| `register-machines.yml` | Manual | When setting up new hardware OR after wiping MAAS entirely |

## What This Produces
- **MAAS image**: `custom/ubuntu-24.04-libvirt-host` — Ubuntu 24.04 with Docker + Libvirt + QEMU pre-installed
- **MAAS machine records**: `blue` (e4:e7:49:39:8c:d2) and `green` (f8:b4:6a:ae:c2:25), commissioned and Ready

## Plug Mapping (set in terraform/main.tf)
| Machine | MAAS | IP | Plug | Physical |
|---------|------|----|------|----------|
| blue | 192.168.3.91:5240 | 192.168.3.120 | plugB (192.168.4.3) | HP Server 1 |
| green | 192.168.2.91:5240 | 192.168.2.120 | plugA (192.168.4.2) | HP Server 2 |

Power control via `smart-plug-maas` API on util (192.168.2.97:5005).

---

## Six-Repo Family

Six repos work together. They split cleanly into two groups:

---

### GROUP 1 — Run Once (Prerequisites)
These three repos establish the foundation. Run them once when setting up the lab,
or when something in the foundation changes. They are **not** part of the routine rebuild.

```
┌─────────────────────────────────────────────────────────────────────┐
│  GROUP 1 — RUN ONCE                                                 │
│                                                                     │
│  vault-access-control                                               │
│    Vault secrets, AppRole credentials, IAM for all pipeline repos.  │
│    Run when: initial setup, rotating secrets, adding new service.   │
│                                                                     │
│  smart-plug-maas                                                    │
│    HTTP power API on util (192.168.2.97:5005). MAAS calls this to  │
│    power-cycle HP servers during every deploy. Must always be UP.   │
│    Run when: initial setup, config change, or API is down.          │
│                                                                     │
│  next-packer   ← YOU ARE HERE                                       │
│    Builds the Ubuntu 24.04 OS image and registers HP servers in     │
│    MAAS (commission, set power webhooks, assign static IPs).        │
│    Run when: initial setup, new hardware, or image update needed.   │
└─────────────────────────────────────────────────────────────────────┘
```

---

### GROUP 2 — Run Together (Routine Rebuild Pipeline)
These three repos are the routine rebuild. Trigger 1of3 and it chains automatically
through 2of3 and 3of3. They assume Group 1 is already in place.

```
┌─────────────────────────────────────────────────────────────────────┐
│  GROUP 2 — RUN TOGETHER (chains automatically)                      │
│                                                                     │
│  next-base-baremetal  (1 of 3)                                      │
│    Deploys the Packer image to the HP server via MAAS.              │
│    Sets up libvirt/KVM. On success → triggers 2of3.                 │
│    Expected time: ~12 minutes.                                      │
│                          ↓ auto-chains                              │
│  next-base-libvirt    (2 of 3)                                      │
│    Creates and configures VMs on the libvirt host.                  │
│    On success → triggers 3of3.                                      │
│    Expected time: ~2 minutes.                                       │
│                          ↓ auto-chains                              │
│  next-base-kubernetes (3 of 3)                                      │
│    Installs Kubernetes, ArgoCD, and workloads on the VMs.           │
│    Expected time: ~8 minutes.                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Full Picture
```
GROUP 1 (once)          GROUP 2 (routine)
─────────────────       ──────────────────────────────────────────
vault-access-control ──→
smart-plug-maas      ──→  next-base-baremetal (1of3)
next-packer          ──→        ↓ chains automatically
                           next-base-libvirt (2of3)
                                ↓ chains automatically
                           next-base-kubernetes (3of3)
```

Group 1 must be in place before Group 2 can run. Once Group 1 is done, only
trigger `next-base-baremetal` — it handles the rest.

### First-Time Setup Order
1. `vault-access-control` — establish IAM and secrets
2. `smart-plug-maas` — deploy power API to util, verify plugA/plugB respond
3. `next-packer` → `build-image` — build Ubuntu image, upload to MAAS
4. `next-packer` → `register-machines` — register HP servers, commission, wait for Ready
5. `next-base-baremetal` (1of3) — triggers automatically through 2of3 → 3of3

## Repo Locations
| Repo | Remote | Local |
|------|--------|-------|
| next-packer | git@github.com:ejbest/next-packer.git | /home/ej/next-packer |
| smart-plug-maas | github.com/tracker-db/smart-plug-maas | /home/ej/smart-plug-maas |
| vault-access-control | github.com/tracker-db/vault-access-control | /home/ej/vault-access-control |
| next-base-baremetal | github.com/tracker-db/next-base-baremetal | /home/ej/next-base-baremetal |
| next-base-libvirt | github.com/tracker-db/next-base-libvirt | /home/ej/next-base-libvirt |
| next-base-kubernetes | github.com/tracker-db/next-base-kubernetes | /home/ej/next-base-kubernetes |
