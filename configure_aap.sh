#!/bin/bash
#
# Script para configurar recursos en Ansible Automation Platform
# Lee las variables de vars.yml y crea proyecto, inventory y host
#

set -e

VARS_FILE="vars.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para parsear YAML simple (solo para vars.yml básico)
parse_yaml() {
    local file=$1
    local key=$2
    
    grep "^${key}:" "$file" | sed "s/^${key}:[[:space:]]*\"\(.*\)\"/\1/" | sed "s/^${key}:[[:space:]]*\(.*\)/\1/"
}

# Función para hacer requests a la API
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -n "$data" ]; then
        curl -k -s -u "${AAP_USERNAME}:${AAP_PASSWORD}" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${AAP_URL}${endpoint}"
    else
        curl -k -s -u "${AAP_USERNAME}:${AAP_PASSWORD}" \
            -X "$method" \
            "${AAP_URL}${endpoint}"
    fi
}

# Función para obtener el ID de un recurso por nombre
get_resource_id() {
    local resource_type=$1
    local resource_name=$2
    
    local response=$(api_request "GET" "/api/controller/v2/${resource_type}/?name=${resource_name}")
    local id=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['results'][0]['id'] if data.get('count', 0) > 0 else '')" 2>/dev/null)
    echo "$id"
}

# Función para crear o obtener recurso
create_or_get_resource() {
    local resource_type=$1
    local resource_name=$2
    local payload=$3
    
    # Intentar crear
    local response=$(api_request "POST" "/api/controller/v2/${resource_type}/" "$payload")
    local status=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id', ''))" 2>/dev/null)
    
    if [ -n "$status" ]; then
        echo "$status"
    else
        # Si falla, intentar obtener el existente
        local existing_id=$(get_resource_id "$resource_type" "$resource_name")
        if [ -n "$existing_id" ] && [ "$resource_type" = "projects" ]; then
            # Si es un proyecto existente, actualizar con la credencial
            echo -e "${YELLOW}   ⚠ Proyecto existente encontrado, actualizando configuración...${NC}" >&2
            local update_response=$(api_request "PATCH" "/api/controller/v2/projects/${existing_id}/" "$payload")
            local updated_id=$(echo "$update_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id', ''))" 2>/dev/null)
            if [ -n "$updated_id" ]; then
                echo "$updated_id"
            else
                echo "$existing_id"
            fi
        else
            echo "$existing_id"
        fi
    fi
}

# Cargar variables
echo "============================================================"
echo "Configuración de Ansible Automation Platform"
echo "============================================================"
echo ""

if [ ! -f "$VARS_FILE" ]; then
    echo -e "${RED}Error: No se encuentra el archivo ${VARS_FILE}${NC}"
    exit 1
fi

echo "1. Cargando variables de ${VARS_FILE}..."
AAP_URL=$(parse_yaml "$VARS_FILE" "aap_url" | sed 's|/$||')
AAP_USERNAME=$(parse_yaml "$VARS_FILE" "aap_username")
AAP_PASSWORD=$(parse_yaml "$VARS_FILE" "aap_password")

if [ -z "$AAP_URL" ] || [ -z "$AAP_USERNAME" ] || [ -z "$AAP_PASSWORD" ]; then
    echo -e "${RED}Error: Faltan variables requeridas en ${VARS_FILE}${NC}"
    exit 1
fi

echo "   URL: ${AAP_URL}"
echo "   Usuario: ${AAP_USERNAME}"
echo ""

# Verificar conexión
echo "2. Verificando conexión con AAP..."
response=$(api_request "GET" "/api/controller/v2/me/")
if echo "$response" | grep -q "username"; then
    echo -e "${GREEN}   ✓ Conexión exitosa${NC}"
else
    echo -e "${RED}   ✗ Error de conexión${NC}"
    echo "$response"
    exit 1
fi
echo ""

# Obtener organización
echo "3. Obteniendo organización..."
org_response=$(api_request "GET" "/api/controller/v2/organizations/")
ORG_ID=$(echo "$org_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print([o['id'] for o in data['results'] if o.get('name') == 'Default'][0] if any(o.get('name') == 'Default' for o in data['results']) else data['results'][0]['id'])" 2>/dev/null)
if [ -z "$ORG_ID" ]; then
    echo -e "${RED}Error: No se pudo obtener la organización${NC}"
    exit 1
fi
echo "   Organización ID: ${ORG_ID}"
echo ""

# Obtener credencial
echo "4. Obteniendo credencial 'github'..."
cred_id=$(get_resource_id "credentials" "github")
if [ -z "$cred_id" ]; then
    echo -e "${RED}Error: No se encontró la credencial 'github'${NC}"
    exit 1
fi
echo "   Credencial ID: ${cred_id}"
echo ""

# Crear proyecto
echo "5. Creando proyecto 'demo-ia-proyecto'..."
project_payload=$(cat <<EOF
{
    "name": "demo-ia-proyecto",
    "organization": ${ORG_ID},
    "scm_type": "git",
    "scm_url": "git@github.com:mcaballol/ansible-ia-control.git",
    "credential": ${cred_id}
}
EOF
)
project_id=$(create_or_get_resource "projects" "demo-ia-proyecto" "$project_payload")
if [ -n "$project_id" ]; then
    echo -e "${GREEN}   ✓ Proyecto 'demo-ia-proyecto' (ID: ${project_id})${NC}"
else
    echo -e "${RED}   ✗ Error al crear proyecto${NC}"
    exit 1
fi
echo ""

# Crear inventory
echo "6. Creando inventory 'demo-ia-inventory'..."
inventory_payload=$(cat <<EOF
{
    "name": "demo-ia-inventory",
    "organization": ${ORG_ID}
}
EOF
)
inventory_id=$(create_or_get_resource "inventories" "demo-ia-inventory" "$inventory_payload")
if [ -n "$inventory_id" ]; then
    echo -e "${GREEN}   ✓ Inventory 'demo-ia-inventory' (ID: ${inventory_id})${NC}"
else
    echo -e "${RED}   ✗ Error al crear inventory${NC}"
    exit 1
fi
echo ""

# Crear host
echo "7. Agregando host 'localhost' al inventory..."
host_payload=$(cat <<EOF
{
    "name": "localhost",
    "inventory": ${inventory_id},
    "variables": "ansible_connection: local\n"
}
EOF
)
host_response=$(api_request "POST" "/api/controller/v2/hosts/" "$host_payload")
host_id=$(echo "$host_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id', ''))" 2>/dev/null)

if [ -n "$host_id" ]; then
    echo -e "${GREEN}   ✓ Host 'localhost' creado (ID: ${host_id})${NC}"
else
    # Verificar si ya existe
    existing_host=$(api_request "GET" "/api/controller/v2/inventories/${inventory_id}/hosts/?name=localhost")
    existing_id=$(echo "$existing_host" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['results'][0]['id'] if data.get('count', 0) > 0 else '')" 2>/dev/null)
    if [ -n "$existing_id" ]; then
        echo -e "${YELLOW}   ⚠ Host 'localhost' ya existe, actualizando configuración...${NC}"
        # Actualizar el host con la conexión local
        update_response=$(api_request "PATCH" "/api/controller/v2/hosts/${existing_id}/" "$host_payload")
        updated_id=$(echo "$update_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id', ''))" 2>/dev/null)
        if [ -n "$updated_id" ]; then
            echo -e "${GREEN}   ✓ Host 'localhost' actualizado (ID: ${updated_id})${NC}"
            host_id="$updated_id"
        else
            echo -e "${YELLOW}   ⚠ No se pudo actualizar, usando existente (ID: ${existing_id})${NC}"
            host_id="$existing_id"
        fi
    else
        echo -e "${RED}   ✗ Error al crear host${NC}"
        echo "$host_response"
    fi
fi
echo ""

echo "============================================================"
echo -e "${GREEN}✓ Configuración completada exitosamente${NC}"
echo "============================================================"
echo ""
echo "Resumen de recursos:"
echo "  - Proyecto: demo-ia-proyecto (ID: ${project_id})"
echo "  - Inventory: demo-ia-inventory (ID: ${inventory_id})"
echo "  - Host: localhost (ID: ${host_id})"
echo ""

