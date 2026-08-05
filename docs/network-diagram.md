# Network Design (Public Showcase)

This repository intentionally omits production IP ranges, VLAN identifiers,
hostnames, and firewall rules. Those values belong in private deployment
configuration and internal operations documentation.

## Logical Flow

```text
Managed endpoints
       |
       | GLPI Agent inventory / registration
       v
GLPI application service
       |
       +--> Asset and inventory database
       |
       +--> Optional notification webhook

IT operator scripts ----> GLPI REST API
```

## Deployment Boundaries

- Endpoint subnets and their GLPI application tokens are configured only in
  the ignored `glpi/glpi_config.ini` file.
- The public template uses RFC 5737 documentation ranges only.
- The deployment must allow endpoint-to-GLPI connectivity for configured agent
  and portal endpoints.
- Notification webhook URLs must stay in ignored local configuration.
