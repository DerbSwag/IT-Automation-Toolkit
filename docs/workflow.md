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
    │                ├─ Collect: hostname, OS, CPU, RAM, disk, NICs, software
    │                └─ Save to: output/inventory/<hostname>_<date>.txt
    │
    ├─ 5. Install GLPI Agent
    │      └─ Install_GLPI_Agent.bat
    │           ├─ Ping GLPI server (connectivity check)
    │           ├─ Download MSI from HTTP server
    │           ├─ Verify SHA256 checksum
    │           ├─ msiexec /i (silent install)
    │           └─ Trigger: glpi-agent --force (immediate inventory push)
    │
    └─ 6. Log results to logs/toolkit.log
```

## B. Self-Service Device Registration (Employee)

```text
Employee opens browser → http://<server>/register.php?hn=<HOSTNAME>
    │
    ├─ 1. Page loads with hostname from URL parameter
    ├─ 2. Employee fills: Lark account, Employee ID, Department
    ├─ 3. Submit (POST with CSRF token)
    │
    └─ register.php backend:
         ├─ Validate CSRF token
         ├─ Validate input (length, format, required fields)
         ├─ Detect client IP → select App Token (VLAN-based)
         ├─ initSession (GLPI API)
         ├─ Search Computer by hostname
         ├─ Search User by Lark account
         │    └─ If not found → Create user (password = hashed emp_id)
         ├─ Search Group by department name
         ├─ PUT Computer: assign user, group, status, comment
         ├─ killSession
         └─ Show success/error to employee
```

## C. GLPI Group Setup (IT runs once)

```text
Create-GLPIGroups.ps1 -ConfigPath glpi_config.ini
    │
    ├─ Read config (server URL, tokens)
    ├─ initSession
    ├─ Create top-level groups (IT, SH, MM, QA, HR, AC, CP, Sr. Mgt, RD, SCM, Operation, BD&CS)
    ├─ Create sub-groups with parent ID (e.g., PU → SCM, PD1 → Operation)
    ├─ killSession
    └─ Output: 25 groups created with hierarchy
```

## D. Lark Account Linking (IT runs per-device or scripted)

```text
Link-LarkToGLPI.ps1 -LarkAccount "Dave_IT" [-Hostname "PC-001"]
    │
    ├─ Auto-detect VLAN from local IP → select App Token
    ├─ initSession
    ├─ Search Computer by hostname
    ├─ Search User by Lark account
    │    ├─ Found → PUT Computer.users_id = user ID
    │    └─ Not found → PUT Computer.comment = "Lark: Dave_IT"
    ├─ killSession
    └─ Exit code: 0 = success, 1 = failure
```

## E. CI Pipeline (GitHub Actions)

```text
Push/PR to main
    │
    ├─ Verify required files exist (10 critical files)
    ├─ PowerShell syntax check (all .ps1 files)
    ├─ Credential leak scan (regex for real tokens)
    ├─ Batch file inventory (list all .bat)
    └─ Pester test suite (Read-IniFile, Get-PCInfo)
```
