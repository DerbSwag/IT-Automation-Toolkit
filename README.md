# 🖥 Windows IT Automation Toolkit (GLPI Deployment & Inventory)

Production-oriented Windows automation toolkit for endpoint onboarding, inventory collection, and GLPI registration.

## 🚀 Overview

This project automates repetitive IT operations:

- Endpoint inventory collection
- Silent GLPI Agent deployment
- Portable endpoint workflow orchestration
- Centralized configuration and logging

## 📁 Project Structure

```text
IT-Automation-Toolkit/
├── config/
│   └── toolkit.ini
├── glpi/
│   ├── config.ini                  # legacy demo config
│   ├── install_glpi_demo.bat.txt   # legacy demo script
│   └── install_glpi.bat            # production installer
├── inventory/
│   ├── Get-PCInfo_demo.ps1         # legacy demo script
│   ├── inventory_demo.bat.txt      # legacy demo script
│   ├── Get-PCInfo.ps1              # production inventory collection
│   └── inventory.bat               # production runner (admin + logging)
├── portable/
│   ├── endpoint_toolkit_demo.bat.txt
│   └── endpoint_toolkit.bat        # production orchestration
├── docs/
│   ├── architecture.md
│   ├── workflow.md
│   └── network-diagram.md
├── logs/                           # runtime logs (gitignored)
├── output/                         # inventory output (gitignored)
└── .github/workflows/ci.yml
```

## ⚙️ Production Workflow

1. `portable/endpoint_toolkit.bat` validates config and elevates to admin.
2. `inventory/inventory.bat` runs `Get-PCInfo.ps1` and writes inventory output.
3. `glpi/install_glpi.bat` validates network reachability, installs GLPI Agent, and triggers inventory submission.
4. All modules append events to a centralized log file.

## 🧩 Configuration

Main configuration is in `config/toolkit.ini`.

```ini
[GLPI]
SERVER_URL=http://glpi.example.local/glpi/front/inventory.php
MSI_NAME=GLPI-Agent.msi
INSTALLER_PATH=..\glpi
PING_HOST=glpi.example.local

[INVENTORY]
OUTPUT_DIR=..\output\inventory
INVENTORY_SCRIPT=..\inventory\Get-PCInfo.ps1

[LOGGING]
LOG_DIR=..\logs
LOG_FILE=toolkit.log
```

## 🔒 Security Notes

- Do not commit production server URLs, credentials, or tokens.
- Keep sensitive settings in environment-specific config (or secret store).
- Restrict toolkit execution to authorized IT administrators.

## ✅ CI / Validation

GitHub Actions workflow (`.github/workflows/ci.yml`) validates:

- Required file presence
- PowerShell script syntax parsing
- Batch file existence checks

## 🛠 Legacy Demo Scripts

Legacy demo scripts are preserved for reference:

- `inventory/*_demo*`
- `glpi/install_glpi_demo.bat.txt`
- `portable/endpoint_toolkit_demo.bat.txt`

## 📄 License

MIT License (see `LICENSE`).
