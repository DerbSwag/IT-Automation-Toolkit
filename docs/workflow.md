# Workflow

## A. Endpoint Onboarding (IT runs on new PC)

```text
endpoint_toolkit.bat
    │
    ├─ 1. Load config from config/toolkit.ini
    ├─ 2. Validate required files exist
    ├─ 3. Request admin elevation (UAC prompt)
    │
    ├─ 4. Run Inventory Collection
    │      └─ inventory/inventory.bat
    │           └─ Get-PCInfo.ps1
    │                ├─ Collect: hostname, OS, CPU, RAM, disk, NICs, and security posture
    │                └─ Save JSON: output/inventory/<hostname>_<user>_<UTC timestamp>.json
    │
    ├─ 5. Install GLPI Agent
    │      └─ glpi/install_glpi.bat
    │           ├─ Validate the configured GLPI API endpoint
    │           ├─ Locate MSI from the configured installer path
    │           ├─ msiexec /i (silent install)
    │           └─ Trigger: glpi-agent --force
    │
    └─ 6. Log results to logs/toolkit.log
```

## B. Self-Service Device Registration (Employee)

```text
Employee opens browser → https://<registration-host>/register.php?hn=<HOSTNAME>
    │
    ├─ 1. Page loads with hostname from URL parameter
    ├─ 2. Employee fills: Lark account, Asset Number (optional), Department
    ├─ 3. Submit (POST with CSRF token)
    │
    └─ register.php backend:
         ├─ Validate CSRF token
         ├─ Validate hostname and input (length, format, required fields)
         ├─ Optionally validate a one-time token bound to hostname and Lark account
         ├─ Detect client IP → select App Token from an allowed subnet
         ├─ initSession (GLPI API)
         ├─ Search Computer by exact hostname; stop if not found or duplicated
         ├─ Search User by Lark account
         │    └─ If not found → Create user with a generated random password
         ├─ Search Group by department name
         ├─ PUT Computer: assign user, group, configured state, and configured Asset Number field
         ├─ killSession
         └─ Show success/error to employee
```

## C. GLPI Group Setup (IT runs once)

```text
Create-GLPIGroups.ps1 -ConfigPath glpi_config.ini
    │
    ├─ Read config (server URL, tokens)
    ├─ initSession
    ├─ Create the configured top-level groups
    ├─ Create configured child groups with the correct parent ID
    ├─ killSession
    └─ Output: 25 groups created with hierarchy
```

## D. Lark Account Linking (IT runs per-device or scripted)

```text
Link-LarkToGLPI.ps1 -LarkAccount "example.user" [-Hostname "PC-001"]
    │
    ├─ Auto-detect VLAN from local IP → select App Token
    ├─ initSession
    ├─ Search Computer by hostname
    ├─ Search User by Lark account
    │    ├─ Found → PUT Computer.users_id = user ID
    │    └─ Not found → PUT Computer.comment = "Lark: example.user"
    ├─ killSession
    └─ Exit code: 0 = success, 1 = failure
```

## E. CI Pipeline (GitHub Actions)

```text
Push/PR to main
    │
    ├─ Verify required files exist (10 critical files)
    ├─ PowerShell syntax check (all .ps1 files)
    ├─ Credential leak scan (basic token patterns)
    ├─ Batch file inventory (list all .bat)
    └─ Pester test suite (Read-IniFile, Get-PCInfo)
```
