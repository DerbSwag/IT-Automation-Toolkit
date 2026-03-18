🖥 Windows IT Automation Toolkit (GLPI Deployment & Inventory)

A production-oriented Windows IT automation toolkit designed to streamline endpoint onboarding, inventory collection, and asset registration in enterprise environments.

🚀 Overview

This project automates repetitive IT operations including:

Endpoint inventory collection

GLPI Agent deployment (silent install)

User/device registration

Portable (USB-based) deployment workflows

Designed for real-world IT environments with network shares, admin elevation, and batch automation workflows.

⚙️ Key Features
🧾 Automated Inventory Collection

Collects PC information using PowerShell

Generates per-user device reports

Standardizes asset data collection

📦 Silent GLPI Agent Deployment

Installs GLPI Agent via msiexec

Configures server endpoint automatically

Runs inventory immediately after installation

🔐 Admin Elevation Handling

Detects admin rights

Automatically relaunches scripts with elevated privileges

💻 Network + USB Deployment Support

Works via network share

Supports portable USB execution for field environments

⚡ IT Operations Utilities

Restart / Shutdown scripts

File unblock automation

Lightweight inventory scripts

🏗 Architecture (Workflow)
User Input (Lark Account)
        ↓
Batch Script (Admin Elevation)
        ↓
PowerShell (Get-PCInfo.ps1)
        ↓
Save Inventory Output
        ↓
Install GLPI Agent (Silent)
        ↓
Send Data to GLPI Server
🧠 Use Cases

Enterprise device onboarding

IT asset registration

Service desk automation

Field IT operations (USB deployment)

🛠 Tech Stack

Windows Batch Scripting

PowerShell

GLPI Agent

msiexec (Silent Deployment)

Network Share / File Systems

🔒 Security Notes

Replace internal IPs and server URLs with placeholders

Avoid exposing internal network paths

Use configuration files for production environments

🚀 Future Improvements

Centralized configuration (JSON / ENV)

Logging & monitoring integration

Python-based GUI installer

CI/CD for script validation
