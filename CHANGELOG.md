# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - 2026-06-09

### Added
- `it-bot-demo.html` — Interactive AI IT Support Bot prototype (Thai language)
- `config/httpd.conf` — Apache configuration for GLPI web portal
- `scripts/Deploy-ZabbixAgent2.ps1` — Zabbix Agent 2 deployment script
- `inventory/inventory_computer_legacy.bat` — Computer-only inventory variant
- `inventory/inventory_legacy.bat` — Lightweight inventory script
- `glpi/open_register.bat` — Opens registration portal in browser
- `glpi/scripts/lib/Read-IniFile.ps1` — Shared INI parser library
- `docs/case-study.md` — Real-world impact case study
- `docs/screenshots/` — UI screenshots (dashboard, registration, agent installer)
- `.github/workflows/gitleaks.yml` — Secret scanning workflow
- `INCIDENTS.md` — Incident response documentation
- Screenshots section in README
- IT Support Bot Demo section in README

### Security
- Removed `glpi/config.ini` from repository (credential file)

## [1.2.0] - 2026-05-08

### Security
- Added HTTPS enforcement (301 redirect) in `register.php` (bypassed for localhost)
- Added rate limiting (5 requests / 10 min per IP) in `register.php`

### Added
- `scripts/HealthCheck-GLPI.ps1` — Checks agent service, server ping, API, last inventory; sends Lark alert on failure
- `glpi/Uninstall_GLPI_Agent.bat` — Uninstall GLPI Agent, remove scheduled task and data
- `tests/GLPIScripts.Tests.ps1` — Pester tests for API scripts (syntax, parameters)
- `tests/BatchFiles.Tests.ps1` — Pester tests for batch files (existence, setlocal, no credentials)
- Server-side error logging in `register.php` (`logs/register_YYYY-MM.log`)

### Changed
- Expanded `docs/architecture.md` with full system diagram, components, VLAN table, security boundaries
- Expanded `docs/workflow.md` with 5 detailed workflow diagrams (onboarding, registration, groups, lark, CI)
- Expanded `docs/network-diagram.md` with logical layout, data flow, ports & firewall rules

## [1.1.0] - 2026-05-06

### Security
- Removed hardcoded credentials from repository
- Added CSRF protection to register.php
- Added input validation (length + format) to register.php
- Password now hashed with `password_hash()` instead of stored as plaintext
- Added SHA256 checksum verification for MSI downloads

### Changed
- PowerShell scripts now use `-ConfigPath` parameter (default: relative path) instead of hardcoded UNC path
- Updated `.gitignore` to exclude `glpi_config.ini`, `config.ini`, and `_local-only/`

### Added
- `.github/workflows/ci.yml` — CI pipeline with syntax checks, credential scanning, and Pester tests
- `CHANGELOG.md`
- Pester test suite (`tests/`)

## [1.0.0] - 2025-04-23

### Added
- Initial release
- Endpoint inventory collection (`Get-PCInfo.ps1`)
- GLPI Agent silent installer (local MSI + HTTP download variants)
- GLPI API scripts: Create-GLPIGroups, Fix-StatusAndGroup, Link-LarkToGLPI
- Web registration portal (`register.php` + `index.html`)
- Portable endpoint onboarding orchestrator
- Centralized config via `toolkit.ini`
- `Read-IniFile.ps1` shared library
