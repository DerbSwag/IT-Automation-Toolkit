# RUNBOOK — IT-Automation-Toolkit

> Proven procedures for Windows IT automation (100+ users daily)
> Updated: 2026-06-15

## Quick Reference

| Item | Value |
|------|-------|
| Platform | Windows (Batch + PowerShell) |
| Purpose | Endpoint onboarding, GLPI asset mgmt, inventory, Lark integration |
| Users | IT team (daily production use) |
| GLPI | Company GLPI instance |

---

## Procedures

### 1. Onboard New Endpoint

**When:** New PC arrives, needs to be registered in GLPI + configured

```batch
run_onboard.bat
```
- Collects hardware info, registers in GLPI, applies baseline config
- Verify: check GLPI web UI for new asset entry

### 2. Inventory Collection

**When:** Periodic or on-demand inventory refresh

```batch
run_inventory.bat
```

### 3. Lark Notification Issues

**When:** Lark bot not sending alerts

**Check:**
- Webhook URL still valid (Lark admin → bot settings)
- Network: can the machine reach `open.larksuite.com`?
- Script error log: check last run output

### 4. GLPI API Connection Failed

**When:** Script reports "API error" or "401"

**Fix:**
- Verify API token in config file
- Check GLPI API is enabled (Setup → General → API)
- Test: `curl -H "Authorization: user_token <TOKEN>" <GLPI_URL>/apirest.php/initSession`

---

## Secrets & Security

- GLPI API token: in config (gitignored)
- Lark webhook URL: in config (gitignored)
- ห้าม commit: API tokens, user credentials

---

## Related Docs

- `README.md` — usage instructions and features
