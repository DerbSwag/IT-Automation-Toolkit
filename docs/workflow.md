# Workflow

1. Validate config and required files.
2. Ensure administrator privileges.
3. Collect device inventory via PowerShell (CIM/WMI fallback).
4. Install GLPI Agent silently (or skip if already installed).
5. Trigger GLPI inventory submission.
6. Write centralized logs for audit trail.
