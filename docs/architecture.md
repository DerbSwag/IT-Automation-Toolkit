# Architecture

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                      Internal LAN (example)                           │
│                                                                      │
│  ┌──────────────┐     ┌──────────────────┐     ┌────────────────┐  │
│  │  Windows     │     │  GLPI Server     │     │  Lark API      │  │
│  │  Endpoints   │────▶│  (Apache + PHP   │────▶│  (Webhook)     │  │
│  │  100+ PCs    │     │   + MariaDB)     │     │                │  │
│  └──────┬───────┘     └────────┬─────────┘     └────────────────┘  │
│         │                      │                                     │
│         │  ┌───────────────────┘                                     │
│         │  │                                                         │
│         ▼  ▼                                                         │
│  ┌──────────────────────────────────────┐                           │
│  │  IT Operator Workstation             │                           │
│  │  - PowerShell scripts                │                           │
│  │  - Batch orchestrators               │                           │
│  │  - Config files (toolkit.ini)        │                           │
│  └──────────────────────────────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Endpoint Layer (Windows PCs)

- Runs `endpoint_toolkit.bat` for onboarding
- GLPI Agent installed silently → pushes inventory to server
- Accesses `register.php` via browser for self-service registration

### 2. GLPI Server

- **Web Server:** Apache (XAMPP-based or standalone)
- **Application:** GLPI 10.x with REST API enabled
- **Database:** MariaDB / MySQL
- **Registration Portal:** `register.php` hosted on same or separate vhost
- **API Endpoint:** `http://<server>/glpi/apirest.php/`

### 3. IT Operator Scripts

| Script | Purpose | Runs On |
|--------|---------|---------|
| `Get-PCInfo.ps1` | Collect hardware/software inventory | Endpoint |
| `Install_GLPI_Agent.bat` | Download + install GLPI Agent | Endpoint |
| `Create-GLPIGroups.ps1` | Create department groups via API | IT workstation |
| `Fix-StatusAndGroup.ps1` | Query/fix device status & groups | IT workstation |
| `Link-LarkToGLPI.ps1` | Link Lark account to computer asset | IT workstation |

### 4. Configuration

```text
config/toolkit.ini          ← Shared config for batch/PS scripts
glpi/glpi_config.ini        ← API credentials (gitignored)
glpi/glpi_config.ini.example ← Template for new deployments
```

All scripts use `Read-IniFile.ps1` (shared library) to parse INI config.

## VLAN / Network Segmentation

| VLAN Prefix | Purpose | App Token |
|-------------|---------|-----------|
| Office subnet | VLAN1 | `APP_TOKENS.VLAN1` |
| Production subnet | VLAN2 | `APP_TOKENS.VLAN2` |
| Management subnet | VLAN100 | `APP_TOKENS.VLAN100` |
| Additional managed subnet | VLAN101 | `APP_TOKENS.VLAN101` |
| `127.x` | Localhost (dev) | `APP_TOKENS.LOCALHOST` |

`register.php` auto-detects client IP and selects the correct App Token.

## Security Boundaries

- **Credentials:** Never stored in code; loaded from gitignored `.ini` files
- **CSRF:** Session-based token on registration form
- **Input Validation:** Length + regex checks before any API call
- **Password Hashing:** `password_hash()` (bcrypt) for GLPI user creation
- **MSI Integrity:** SHA256 checksum verification before install
