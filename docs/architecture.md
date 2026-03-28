# Architecture

```text
User/IT Operator
    |
    v
portable/endpoint_toolkit.bat
    |
    +--> inventory/inventory.bat --> inventory/Get-PCInfo.ps1 --> output/inventory/*.txt
    |
    +--> glpi/install_glpi.bat --> msiexec + glpi-agent inventory push
    |
    +--> logs/toolkit.log
```
