# 🖥 Windows IT Automation Toolkit (GLPI Deployment & Inventory)

A production-oriented Windows IT automation toolkit designed to streamline endpoint onboarding, inventory collection, and asset registration in enterprise environments.

---

## 🚀 Overview

This project automates repetitive IT operations in real-world environments:

- Endpoint inventory collection
- GLPI Agent deployment (silent install)
- User-to-device registration
- Portable (USB-based) deployment workflows

Designed for enterprise environments with:

- Network share integration
- Administrator privilege handling
- Scalable batch automation workflows

---

## 🧠 Use Cases

- Enterprise device onboarding
- IT asset registration (GLPI)
- Service desk automation
- Field IT deployment (USB toolkit)

---

## ⚙️ Key Features

### 🧾 Automated Inventory Collection

- Collects hardware information via PowerShell
- Generates per-user device reports
- Standardizes asset data collection

---

### 📦 Silent GLPI Agent Deployment

- Installs GLPI Agent using `msiexec`
- Automatically configures GLPI server endpoint
- Triggers inventory after installation

---

### 🔐 Admin Elevation Handling

- Detects administrator privileges
- Automatically relaunches script with elevated rights

---

### 💻 Network + USB Deployment

- Supports deployment via network share (UNC Path)
- Portable execution via USB (offline environments)

---

### ⚡ IT Operations Utilities

- Restart / Shutdown scripts
- File unblock automation
- Lightweight IT support tools

---

## 🏗 Architecture (Workflow)

User Input (User name)  
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

---

## 🌐 Infrastructure Overview

Client Machines (Office / Factory)  
        │  
        ▼  
Company LAN (192.168.x.x)  
        │  
        ▼  
GLPI Server (Apache + PHP + MariaDB)  
        │  
        ▼  
Asset Database  

---

## 🛠 Tech Stack

- Windows Batch Scripting
- PowerShell
- GLPI Agent
- MSI Deployment (`msiexec`)
- Windows Networking (UNC Path, LAN)
- Python (PySimpleGUI - Prototype)

---

## 📊 Example Output

Computer Name: ENG-PC-01
User: natthawat
OS: Windows 11 Pro
CPU: Intel Core i5-10400
RAM: 16 GB


---

## 🔒 Security Considerations

- Internal IPs and server paths should be configurable
- Avoid hardcoding network paths in production
- Restrict script usage to authorized IT staff
- Use environment variables or config files for sensitive data

---

## 📈 Result / Impact

- Reduced manual IT onboarding time
- Standardized asset registration process
- Improved visibility of IT infrastructure
- Scalable deployment across multiple endpoints

---

## 🚀 Future Improvements

- Centralized configuration (JSON / ENV)
- Logging & monitoring system
- Python-based GUI deployment tool
- CI/CD pipeline for script validation

---

## 📷 Screenshots / Diagrams

> Add diagrams in `/docs`

- docs/architecture.png
- docs/workflow.png
- docs/network-diagram.png

---

## 🧩 Related Knowledge

This project aligns with practical IT operations such as:

- Network troubleshooting workflows :contentReference[oaicite:0]{index=0}
- Asset management processes
- IT infrastructure automation

---

## 📝 Resume Summary

Developed a Windows-based IT automation toolkit for endpoint onboarding, inventory collection, and GLPI agent deployment, improving operational efficiency and standardizing IT asset management.
IP Address: [INTERNAL-IP-REDACTED]
