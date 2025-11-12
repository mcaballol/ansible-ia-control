# Prompts y Instrucciones del Proyecto

Este archivo contiene los prompts e instrucciones utilizados para generar el contenido de este proyecto.

## Prompt 1: Configuración inicial de recursos en AAP

**Instrucción:**
```
Tengo este servidor de ansible automation platform @https://aap-aap.apps-crc.testing/api/controller/v2/ 
el usuario es demo-ia y la contraseña también. Podrías conectarte y crear algunos recursos que te estaré 
listando acá. Primero los recursos que generes que tengan prefijo demo-ia:

1. Un proyecto que descargue configuraciones de git@github.com:mcaballol/ansible-ia-control.git
2. Para autenticarte definele la credencial que se llama github
3. Genera un inventory que tenga un host que sea localhost
4. Otra cosa: la contraseña que te envié de aap y la url agregalas a un archivo de variables que listarás 
   en el gitignore de este directorio
```

**Resultado esperado:**
- Proyecto `demo-ia-proyecto` configurado con repositorio Git y credencial github
- Inventory `demo-ia-inventory` con host localhost
- Host localhost configurado con `ansible_connection: local` (para ejecución local)
- Archivo `vars.yml` con variables de configuración (excluido del gitignore)

---

## Prompt 2: Generar scripts de configuración

**Instrucción:**
```
Podrías generar el script que hace la configuración y que haga uso de los archivos donde pusiste los 
environmentes
```

**Resultado esperado:**
- Script bash (`configure_aap.sh`) que lee `vars.yml` y configura recursos en AAP
- Script Python (`configure_aap.py`) alternativo
- Scripts idempotentes que detectan recursos existentes

---

## Prompt 3: Ejecutar script y verificar configuración

**Instrucción:**
```
Podrías ejecutar el script sh y crear los recursos, verifica que hayan quedado bien configurados, ya que 
por ejemplo proyecto no tenía definida la credencial de git que se llama github
```

**Resultado esperado:**
- Ejecutar el script de configuración
- Verificar que todos los recursos estén correctamente configurados
- Asegurar que el proyecto tenga la credencial "github" asignada
- Corregir cualquier problema de configuración

**Nota importante:** En AAP v2, el campo correcto para la credencial SCM es `credential`, no `scm_credential`.

---

## Prompt 4: Crear playbook y job template

**Instrucción:**
```
Ahora crea un playbook que imprima el nombre de la máquina donde se está ejecutando el playbook, y datos 
de usos de memoria y cpu. Lo subes a git y este playbook lo configura en un template que se llame get-status. 
Recuerda utilizar el prefijo que estamos usando para este proyecto.
```

**Resultado esperado:**
- Playbook `get-status.yml` que muestra:
  - Nombre de la máquina (hostname)
  - Información de memoria (total, disponible, usada, porcentaje)
  - Información de CPU (procesadores, modelo, arquitectura)
  - Carga del sistema (uptime)
  - Resumen completo del sistema
- Playbook subido al repositorio Git
- Job template `demo-ia-get-status` creado en AAP
- Job template configurado con:
  - Playbook: `get-status.yml`
  - Inventory: `demo-ia-inventory`
  - Project: `demo-ia-proyecto`

---

## Convenciones del Proyecto

- **Prefijo:** Todos los recursos deben usar el prefijo `demo-ia`
- **Credenciales:** La credencial de GitHub se llama `github`
- **Variables:** Las credenciales y URLs se almacenan en `vars.yml` (excluido del control de versiones)
- **Idempotencia:** Los scripts deben ser idempotentes y detectar recursos existentes

---

## Estructura de Recursos en AAP

1. **Organización:** Default (ID: 1)
2. **Proyecto:** `demo-ia-proyecto`
   - Repositorio: `git@github.com:mcaballol/ansible-ia-control.git`
   - Credencial: `github`
3. **Inventory:** `demo-ia-inventory`
   - Host: `localhost` (con `ansible_connection: local`)
4. **Job Template:** `demo-ia-get-status`
   - Playbook: `get-status.yml`

---

## Notas Técnicas

- La API de AAP v2 usa el campo `credential` (no `scm_credential`) para asignar credenciales a proyectos
- Los scripts deben actualizar proyectos existentes si ya están creados
- El proyecto debe sincronizarse desde Git antes de crear job templates que usen sus playbooks
- Los playbooks se obtienen del proyecto sincronizado, no directamente del repositorio
- **Importante:** El host `localhost` debe configurarse con `ansible_connection: local` en sus variables para ejecutar playbooks localmente sin SSH

