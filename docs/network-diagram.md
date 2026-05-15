# Network Diagram

## Logical Network Layout

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                           PJPARAWOOD Network                             │
│                                                                          │
│  ┌─────────────────┐                          ┌──────────────────────┐  │
│  │ VLAN1 (Office)  │                          │   GLPI Server        │  │
│  │ [INTERNAL-IP-REDACTED]/24  │─────────┐               │   IP: 192.168.1.x    │  │
│  │ - IT, HR, AC    │         │               │                      │  │
│  └─────────────────┘         │               │   Services:          │  │
│                               │               │   ├─ :80  Apache     │  │
│  ┌─────────────────┐         │    ┌──────┐   │   ├─ :443 HTTPS      │  │
│  │ VLAN2 (Prod)    │         ├───▶│ Core │──▶│   ├─ :3306 MariaDB   │  │
│  │ [INTERNAL-IP-REDACTED]/24  │─────────┤    │Switch│   │   └─ GLPI REST API   │  │
│  │ - Factory floor  │         │    └──────┘   │      /apirest.php    │  │
│  └─────────────────┘         │               └──────────────────────┘  │
│                               │                                          │
│  ┌─────────────────┐         │               ┌──────────────────────┐  │
│  │ VLAN100         │─────────┤               │   Registration       │  │
│  │ [INTERNAL-IP-REDACTED]/24│         │               │   Portal             │  │
│  └─────────────────┘         │               │   /register.php      │  │
│                               │               │   (same server or    │  │
│  ┌─────────────────┐         │               │    separate vhost)   │  │
│  │ VLAN101         │─────────┘               └──────────────────────┘  │
│  │ [INTERNAL-IP-REDACTED]/24│                                                    │
│  └─────────────────┘                                                    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                    │
                    │ Internet (outbound only)
                    ▼
          ┌─────────────────┐
          │  Lark API       │
          │  (Webhook URL)  │
          └─────────────────┘
```

## Data Flow

```text
┌──────────┐   HTTP POST    ┌──────────────┐   REST API    ┌──────────┐
│ Employee │ ─────────────▶ │ register.php │ ────────────▶ │ GLPI DB  │
│ Browser  │   (form data)  │              │  (JSON)       │          │
└──────────┘                └──────────────┘               └──────────┘

┌──────────┐   GLPI Agent   ┌──────────────┐   Inventory   ┌──────────┐
│ Endpoint │ ─────────────▶ │ GLPI Server  │ ────────────▶ │ GLPI DB  │
│ (PC)     │   (XML/JSON)   │ :80/443      │   (auto)      │          │
└──────────┘                └──────────────┘               └──────────┘

┌──────────┐   PowerShell   ┌──────────────┐   Webhook    ┌──────────┐
│ IT       │ ─────────────▶ │ GLPI API     │ ───────────▶ │ Lark     │
│ Operator │   (REST calls) │              │  (optional)   │          │
└──────────┘                └──────────────┘               └──────────┘
```

## Ports & Protocols

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| Endpoints | GLPI Server | 80/443 | HTTP/S | Agent inventory push |
| Endpoints | GLPI Server | 80/443 | HTTP/S | Registration portal |
| IT Workstation | GLPI Server | 80/443 | HTTP/S | API scripts |
| GLPI Server | Lark API | 443 | HTTPS | Webhook notifications |
| Endpoints | GLPI Server | ICMP | Ping | Connectivity check |

## Firewall Requirements

- Allow inbound 80/443 to GLPI Server from all VLANs
- Allow outbound 443 from GLPI Server to `open.larksuite.com` (Lark webhook)
- ICMP (ping) allowed between endpoints and GLPI Server
