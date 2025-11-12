# ansible-ia-control

Repositorio para configurar recursos en Ansible Automation Platform.

## Configuración

1. Configurar variables en `vars.yml`:
```yaml
aap_url: "https://aap-aap.apps-crc.testing"
aap_username: "demo-ia"
aap_password: "demo-ia"
```

2. Ejecutar el script de configuración:

**Opción 1: Script Bash (recomendado, sin dependencias)**
```bash
./configure_aap.sh
```

**Opción 2: Script Python**
```bash
pip install -r requirements.txt
python3 configure_aap.py
```

## Recursos creados

El script crea los siguientes recursos en AAP:

- **Proyecto**: `demo-ia-proyecto`
  - Repositorio: `git@github.com:mcaballol/ansible-ia-control.git`
  - Credencial: `github`

- **Inventory**: `demo-ia-inventory`
  - Host: `localhost`

## Notas

- El archivo `vars.yml` está excluido del control de versiones (ver `.gitignore`)
- El script es idempotente: si los recursos ya existen, los detecta y continúa
