# 🖥 Windows IT Automation Toolkit

[![CI](https://github.com/DerbSwag/IT-Automation-Toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/DerbSwag/IT-Automation-Toolkit/actions/workflows/ci.yml)

Production-oriented Windows automation toolkit for endpoint onboarding, inventory collection, GLPI asset management, and Lark integration.

> 💼 **Real-world project** — Built and used daily by a sole IT engineer managing 100+ users in a manufacturing facility. Not a tutorial — this runs in production.

![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Batch](https://img.shields.io/badge/Batch-4D4D4D?style=for-the-badge&logo=windows-terminal&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)
![GLPI](https://img.shields.io/badge/GLPI-6C63FF?style=for-the-badge)
![GitHub Actions](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)


## 💡 Problem → Solution → Impact

| | Before (Manual) | After (Automated) |
|---|---|---|
| **Endpoint onboarding** | ~45 min/device — manual install, inventory, registration | **~5 min/device** — one-click script |
| **Inventory collection** | Walk to each PC, manually record specs | **Run remotely** — PowerShell auto-collects |
| **GLPI registration** | Manually create user + assign device in UI | **Self-service portal** — employees register themselves |
| **Department groups** | Create 25+ groups one-by-one | **One script** — all groups with hierarchy in seconds |
| **Device status updates** | Click through UI for each device | **Bulk update** — PowerShell fixes all at once |

> **Total time saved: ~3+ hours/week** on routine IT operations

---


## 🚀 Overview

This toolkit automates repetitive IT operations in a manufacturing environment (100+ users):

- **Endpoint inventory** — Collect hardware/software info via PowerShell
- **GLPI Agent deployment** — Silent install with network validation
- **GLPI API automation** — Create groups, fix statuses, register devices
- **Web registration** — Self-service device registration portal
- **Lark integration** — Bridge GLPI alerts to Lark messaging
- **Portable orchestration** — One-click endpoint onboarding with admin elevation

```mermaid
graph TD
    Admin[IT Admin] --> Onboard[Endpoint Onboarding Script]
    Onboard --> Inventory[PowerShell Inventory Collection]
    Onboard --> GLPI_Agent[GLPI Agent Install]
    Inventory --> GLPI[(GLPI Server)]
    GLPI_Agent --> GLPI
    Employee[Employee] --> Web[Self-Service Registration Portal]
    Web --> |PHP + API| GLPI
    GLPI --> |Notifications| Lark[Lark Messaging]
    Admin --> |PowerShell| BulkFix[Bulk Status Fix]
    BulkFix --> GLPI
```

---

## 📈 Results

| Metric | Before | After |
|--------|--------|-------|
| Endpoint onboarding | ~45 min/device | **~5 min/device** |
| Weekly IT time saved | — | **3+ hours/week** |
| Users managed (sole IT) | — | **100+ users** |
| GLPI group creation | Manual one-by-one | **25+ groups in seconds** |
| Device status updates | Click-through UI | **Bulk PowerShell fix** |
| Health check | Manual server check | **Automated + Lark alert** |

---


## 📁 Project Structure

```text
IT-Automation-Toolkit/
├── config/
│   ├── toolkit.ini                     # Centralized configuration
│   └── httpd.conf                      # Apache config for GLPI web portal
├── glpi/
│   ├── install_glpi.bat                # GLPI Agent installer (production)
│   ├── Install_GLPI_Agent.bat          # GLPI Agent installer v2 (download + install)
│   ├── Uninstall_GLPI_Agent.bat        # GLPI Agent uninstaller (v1.2.0)
│   ├── open_register.bat              # Opens registration portal in browser
│   ├── glpi_config.ini.example         # Config template (copy & fill your tokens)
│   ├── scripts/
│   │   ├── Create-GLPIGroups.ps1       # Create department groups via GLPI API
│   │   ├── Fix-StatusAndGroup.ps1      # Bulk fix device status & group assignment
│   │   ├── Link-LarkToGLPI.ps1        # Bridge GLPI notifications → Lark
│   │   └── lib/
│   │       └── Read-IniFile.ps1       # Shared INI parser
│   └── web/
│       ├── index.html                  # Device registration UI
│       └── register.php                # Registration backend (HTTPS + rate limit)
├── inventory/
│   ├── Get-PCInfo.ps1                  # PowerShell inventory collector
│   ├── IT_PJ_Inventory.bat             # All-in-one: inventory + GLPI install
│   ├── IT_PJ_Computer_Inventory.bat    # Computer-only inventory variant
│   ├── IT_PJ_Inven.bat                 # Lightweight inventory script
│   └── inventory.bat                   # Runner with admin elevation + logging
├── scripts/
│   ├── HealthCheck-GLPI.ps1            # Server health check + Lark alerts (v1.2.0)
│   └── Deploy-ZabbixAgent2.ps1         # Zabbix Agent 2 deployment script
├── portable/
│   └── endpoint_toolkit.bat            # One-click orchestration script
├── tests/
│   ├── Read-IniFile.Tests.ps1          # INI parsing tests
│   ├── Get-PCInfo.Tests.ps1            # Inventory script tests
│   ├── GLPIScripts.Tests.ps1           # API scripts syntax + param tests (v1.2.0)
│   └── BatchFiles.Tests.ps1            # Batch file validation tests (v1.2.0)
├── docs/
│   ├── architecture.md                 # System architecture + VLAN diagram
│   ├── workflow.md                     # Workflow diagrams (5 flows)
│   ├── network-diagram.md             # Network layout + firewall rules
│   ├── case-study.md                   # Real-world impact case study
│   └── screenshots/                    # UI screenshots for documentation
├── .github/workflows/
│   ├── ci.yml                          # CI: file validation + PS syntax check
│   └── gitleaks.yml                    # Secret scanning (credential leak prevention)
├── it-bot-demo.html                    # 🤖 AI IT Support Bot demo (interactive)
├── .gitignore
├── AGENTS.md                           # AI agent context file
├── CHANGELOG.md                        # Version history
├── INCIDENTS.md                        # Incident response documentation
└── LICENSE (Apache-2.0)
```

---

## ⚙️ Modules

### 📦 Inventory Collection (`inventory/`)

Collects endpoint hardware and software information.

```
inventory.bat → elevates to admin → runs Get-PCInfo.ps1 → saves output
```

- Hostname, OS, CPU, RAM, disk, network adapters
- Installed software list
- Output to timestamped file

### 🔧 GLPI Agent Deployment (`glpi/`)

Silent deployment of GLPI Agent with pre-flight checks.

**Which script to use:**

| Script | Use When |
|--------|----------|
| `Install_GLPI_Agent.bat` | **Recommended** — Downloads MSI via HTTP, verifies SHA256, installs silently |
| `install_glpi.bat` | Legacy — Uses MSI from local network share |
| `IT_PJ_Inventory.bat` | All-in-one — Inventory + GLPI install in a single run |

> `install_glpi.bat` is kept for environments without HTTP download. For new deployments, prefer `Install_GLPI_Agent.bat`.


```
Install_GLPI_Agent.bat → ping server → download MSI → silent install → trigger inventory
```

- Network reachability validation before install
- Configurable server URL and MSI path
- Error handling with logging

### 📡 GLPI API Scripts (`glpi/scripts/`)

PowerShell scripts that automate GLPI management via REST API.

| Script | Function |
|--------|----------|
| `Create-GLPIGroups.ps1` | Create department groups (top-level + sub-groups) with parent-child hierarchy |
| `Fix-StatusAndGroup.ps1` | Bulk update device status and group assignment |
| `Link-LarkToGLPI.ps1` | Read GLPI data and push notifications to Lark messaging |

All scripts read credentials from `glpi_config.ini` — no hardcoded tokens.

### 🌐 Web Registration (`glpi/web/`)

Self-service device registration portal for end users.

- `index.html` — Clean UI for employees to register their devices
- `register.php` — Backend that creates users + assigns computers via GLPI API
- Auto-detects VLAN and selects appropriate API token

### 🚀 Portable Orchestration (`portable/`)

One-click endpoint onboarding script.

```
endpoint_toolkit.bat → validate config → elevate admin → inventory → GLPI install
```

### 🩺 Health Check (`scripts/`)

Server monitoring with Lark alerting (v1.2.0).

```
HealthCheck-GLPI.ps1 → check agent service → ping server → test API → verify last inventory → alert on failure
```

---

## 📸 Screenshots

| GLPI Dashboard | Registration Portal |
|:-:|:-:|
| ![GLPI Dashboard](docs/screenshots/glpi-dashboard.png) | ![Registration Form](docs/screenshots/registration-form.png) |

| Agent Installer (Download) | Agent Installer (Success) |
|:-:|:-:|
| ![Agent Download](docs/screenshots/agent-installer-download.png) | ![Agent Success](docs/screenshots/agent-installer-success.png) |

<details>
<summary>📖 Registration Guide (step-by-step)</summary>

![Step 1](docs/screenshots/registration-guide-1.png)
![Step 2](docs/screenshots/registration-guide-2.png)
![Step 3](docs/screenshots/registration-guide-3.png)

</details>

---

## 🤖 IT Support Bot Demo

Interactive AI-powered IT helpdesk chatbot prototype ([`it-bot-demo.html`](it-bot-demo.html)).

- Built with vanilla HTML/CSS/JS — no dependencies
- Thai language support for factory employees
- Simulates IT troubleshooting workflows (password reset, network issues, printer problems)
- Designed as proof-of-concept for GLPI + AI integration

---

## 🔧 Configuration

### Main Config (`config/toolkit.ini`)

```ini
[GLPI]
SERVER_URL=http://glpi.example.local/glpi/front/inventory.php
MSI_NAME=GLPI-Agent.msi
PING_HOST=glpi.example.local

[INVENTORY]
OUTPUT_DIR=..\output\inventory
INVENTORY_SCRIPT=..\inventory\Get-PCInfo.ps1

[LOGGING]
LOG_DIR=..\logs
LOG_FILE=toolkit.log
```

### GLPI API Config (`glpi/glpi_config.ini.example`)

```ini
[GLPI]
SERVER_URL=http://YOUR_SERVER_IP
USER_TOKEN=YOUR_USER_TOKEN

[APP_TOKENS]
VLAN1=YOUR_APP_TOKEN_VLAN1
VLAN2=YOUR_APP_TOKEN_VLAN2
```

> Copy `glpi_config.ini.example` → `glpi_config.ini` and fill in your actual values.

---

## 🔒 Security

- ✅ No hardcoded credentials — all tokens in config files (gitignored)
- ✅ `.ini.example` provided as template
- ✅ HTTPS enforced on registration portal (v1.2.0)
- ✅ Rate limiting on public endpoints (v1.2.0)
- ✅ Restrict execution to authorized IT administrators
- ✅ All sensitive data sanitized before commit

## ✅ CI / Validation

GitHub Actions workflow validates on every push:
- Required file presence
- PowerShell script syntax parsing
- Credential leak detection (blocks commits with real tokens)
- Pester test suite execution

## Tests

Run Pester tests locally:

```powershell
Invoke-Pester tests/ -Verbose
```

Tests cover:
- `Read-IniFile` - INI parsing, missing file handling, empty values
- `Get-PCInfo` - stdout output, file output, hostname detection
- `GLPIScripts` - API script syntax validation, parameter checks (v1.2.0)
- `BatchFiles` - Batch file existence, setlocal usage, no credentials (v1.2.0)

## 📄 License

Apache-2.0 License — see [LICENSE](LICENSE)
