# AGENTS.md

## Project Overview

Windows IT Automation Toolkit — production scripts for endpoint onboarding, inventory collection, GLPI asset management, and Lark integration. Used daily in a manufacturing facility (100+ users).

## Tech Stack

- Batch Script (.bat) — main orchestration and installers
- PowerShell (.ps1) — inventory collection, GLPI API automation
- PHP — self-service web registration portal
- HTML — registration UI
- GitHub Actions — CI (syntax check, credential leak detection, Pester tests)

## Architecture

```
config/toolkit.ini          → Centralized configuration (INI format)
glpi/                       → GLPI Agent installers + API scripts + web portal
  scripts/*.ps1             → PowerShell scripts calling GLPI REST API
  web/                      → PHP + HTML self-service registration
inventory/                  → PowerShell inventory collector + batch runner
portable/                   → One-click endpoint onboarding orchestrator
scripts/                    → Standalone PowerShell utilities (HealthCheck)
tests/                      → Pester test suite
.github/workflows/ci.yml   → CI pipeline
```

## Conventions

- All credentials stored in `.ini` config files (gitignored), never hardcoded
- PowerShell scripts use `Verb-Noun` naming (e.g., `Get-PCInfo`, `Create-GLPIGroups`)
- Batch scripts use `snake_case` or descriptive names
- Config templates use `.example` suffix (e.g., `glpi_config.ini.example`)
- Scripts must validate network/prerequisites before executing

## Commands

- Test: `Invoke-Pester tests/ -Verbose`
- CI: Runs automatically on push (file validation + PS syntax + credential scan)

## Security Rules

- NEVER commit real tokens, IPs, or credentials
- All sensitive values go in `.ini` files listed in `.gitignore`
- Use `.example` files as templates for documentation

## Important Notes

- Target OS: Windows (scripts run on Windows endpoints)
- GLPI API uses session tokens + app tokens (multi-VLAN aware)
- Scripts require admin elevation for inventory and agent install
