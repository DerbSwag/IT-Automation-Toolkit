# Case Study: IT Automation in Manufacturing

## One IT Engineer, 100+ Users, Zero Manual Processes

> How a sole IT engineer automated endpoint management in a manufacturing facility — reducing onboarding time by 89% and saving 3+ hours per week.

---

## Context

| | |
|---|---|
| **Industry** | Manufacturing (wood products) |
| **Company size** | 100+ employees |
| **IT team** | 1 engineer (sole IT) |
| **ITSM platform** | GLPI (open-source) |
| **Environment** | Windows endpoints, multiple VLANs |

---

## The Challenge

As the only IT engineer in a growing manufacturing facility, every minute spent on repetitive tasks was a minute not spent on infrastructure improvements, security, or user support.

**Pain points:**

1. **Endpoint onboarding took ~45 minutes per device** — manually installing agents, collecting hardware specs, registering in GLPI, and assigning to departments
2. **No centralized inventory** — walking to each PC to record specs, or relying on outdated spreadsheets
3. **Manual GLPI registration** — creating users, assigning devices, setting groups one-by-one through the web UI
4. **Department group setup** — 25+ groups with parent-child hierarchy, created manually
5. **No integration between systems** — GLPI data isolated from Lark (company messaging platform)

---

## The Solution

Built a modular automation toolkit using PowerShell, Batch, and PHP — tools already available in the Windows environment with zero additional licensing cost.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    IT Operator                           │
│              (runs one script)                           │
└──────────────────────┬──────────────────────────────────┘
                       │
          ┌────────────┼────────────────┐
          ▼            ▼                ▼
   ┌─────────────┐ ┌──────────┐ ┌─────────────────┐
   │  Inventory  │ │  GLPI    │ │  Registration   │
   │  Collection │ │  Agent   │ │  Portal (Web)   │
   │  (PS + BAT) │ │  Deploy  │ │  (PHP + HTML)   │
   └──────┬──────┘ └────┬─────┘ └───────┬─────────┘
          │              │               │
          ▼              ▼               ▼
   ┌─────────────────────────────────────────────────────┐
   │              GLPI Server (REST API)                  │
   │         Asset Management + Service Desk             │
   └──────────────────────┬──────────────────────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Lark Messaging │
                 │  (Notifications)│
                 └─────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Batch + PowerShell** (not Ansible/GPO) | No domain controller, mixed workgroup environment, zero dependencies needed |
| **INI config files** (not environment variables) | Easy for non-developers to edit, works across batch and PowerShell |
| **VLAN-based token selection** | Multi-network factory floor — auto-detects which API token to use based on client IP |
| **Self-service portal** (not IT-only) | Reduces bottleneck — employees register their own devices |
| **Modular scripts** (not monolithic) | Each module works standalone or orchestrated together |

---

## Implementation

### Phase 1: Inventory Collection (Week 1)
- Built `Get-PCInfo.ps1` — collects hardware, OS, network, installed software
- CIM/WMI fallback for older Windows versions
- Output to timestamped files for audit trail

### Phase 2: GLPI Agent Deployment (Week 1-2)
- Silent MSI install with network validation
- SHA256 checksum verification of downloaded installer
- Auto-triggers first inventory submission

### Phase 3: API Automation (Week 2-3)
- `Create-GLPIGroups.ps1` — 25+ department groups with hierarchy in one run
- `Fix-StatusAndGroup.ps1` — bulk update device status and assignments
- `Link-LarkToGLPI.ps1` — bridge asset data to company messaging

### Phase 4: Self-Service Portal (Week 3-4)
- PHP registration form with GLPI API backend
- Auto-creates GLPI user if not exists
- Assigns device to user + department group
- CSRF protection, input validation, password hashing

### Phase 5: One-Click Orchestration (Week 4)
- `endpoint_toolkit.bat` — single script runs entire onboarding flow
- Admin elevation, config validation, error handling, centralized logging

---

## Results

### Quantitative Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Endpoint onboarding | ~45 min/device | ~5 min/device | **89% faster** |
| Inventory collection | 15-20 min/device (walk + record) | 30 sec (remote) | **97% faster** |
| Department group setup | ~2 hours (manual) | 10 seconds (script) | **99% faster** |
| Device registration | 10 min/device (IT only) | 2 min (self-service) | **80% faster** |
| Weekly routine operations | 5+ hours | <2 hours | **3+ hours saved/week** |

### Qualitative Impact

- **Consistency** — Every device gets the same configuration, no human error
- **Audit trail** — Timestamped logs and inventory files for compliance
- **Scalability** — Adding 10 new devices takes the same effort as adding 1
- **Self-service** — Employees don't wait for IT to register their devices
- **Documentation as code** — The scripts ARE the documentation of the process

---

## Lessons Learned

1. **Start with the biggest time sink** — Endpoint onboarding was 45 min × multiple devices/week. Automating this first gave immediate ROI.

2. **Config files > hardcoded values** — Moving all environment-specific values to INI files made scripts portable and safe to share publicly.

3. **Self-service reduces bottleneck** — The registration portal eliminated the "waiting for IT" problem entirely.

4. **Modular > monolithic** — Each script works independently. When one breaks, the others still function.

5. **CI catches mistakes early** — GitHub Actions validates syntax and scans for credential leaks before they reach production.

---

## Tech Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| Inventory | PowerShell (CIM/WMI) | Native to Windows, no install needed |
| Deployment | Batch scripts | Works without execution policy issues |
| API automation | PowerShell + REST | Direct GLPI API integration |
| Web portal | PHP + HTML/CSS/JS | Runs on existing Apache server |
| CI/CD | GitHub Actions | Free for public repos |
| Testing | Pester | PowerShell-native test framework |
| Config | INI files | Simple, cross-tool compatible |

---

## Applicability

This approach works for any organization that:
- Runs Windows endpoints
- Uses GLPI (or similar ITSM with REST API)
- Has limited IT staff
- Needs repeatable, auditable processes
- Can't justify enterprise automation tools (SCCM, Intune, etc.)

---

*Built and maintained by a sole IT engineer. Running in production since 2025.*
