#!/bin/bash
#
# Script para limpiar recursos creados en Ansible Automation Platform
# Elimina job templates, hosts, inventories y proyectos con prefijo demo-ia
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

# Función para parsear YAML simple
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

# Función para eliminar un recurso
delete_resource() {
    local resource_type=$1
    local resource_name=$2
    local resource_id=$3
    
    if [ -z "$resource_id" ]; then
        resource_id=$(get_resource_id "$resource_type" "$resource_name")
    fi
    
    if [ -z "$resource_id" ]; then
        echo -e "${YELLOW}   ⚠ ${resource_type} '${resource_name}' no encontrado${NC}"
        return 1
    fi
    
    local response=$(api_request "DELETE" "/api/controller/v2/${resource_type}/${resource_id}/")
    local status_code=$(echo "$response" | python3 -c "import sys; print('204' if sys.stdin.read() == '' else '200')" 2>/dev/null || echo "200")
    
    if [ "$status_code" = "204" ] || [ -z "$response" ]; then
        echo -e "${GREEN}   ✓ ${resource_type} '${resource_name}' eliminado (ID: ${resource_id})${NC}"
        return 0
    else
        echo -e "${RED}   ✗ Error al eliminar ${resource_type} '${resource_name}'${NC}"
        echo "$response"
        return 1
    fi
}

# Cargar variables
echo "============================================================"
echo "Limpieza de Recursos en Ansible Automation Platform"
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

# Confirmación
echo "3. Recursos que se eliminarán:"
echo "   - Job Template: demo-ia-get-status"
echo "   - Host: localhost (del inventory demo-ia-inventory)"
echo "   - Inventory: demo-ia-inventory"
echo "   - Proyecto: demo-ia-proyecto"
echo ""
read -p "¿Deseas continuar con la eliminación? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Operación cancelada."
    exit 0
fi
echo ""

# Eliminar job template
echo "4. Eliminando job template 'demo-ia-get-status'..."
delete_resource "job_templates" "demo-ia-get-status"
echo ""

# Obtener inventory ID para eliminar el host
echo "5. Obteniendo inventory 'demo-ia-inventory'..."
inventory_id=$(get_resource_id "inventories" "demo-ia-inventory")
if [ -n "$inventory_id" ]; then
    echo "   Inventory ID: ${inventory_id}"
    
    # Obtener host localhost del inventory
    echo "6. Obteniendo host 'localhost' del inventory..."
    host_response=$(api_request "GET" "/api/controller/v2/inventories/${inventory_id}/hosts/?name=localhost")
    host_id=$(echo "$host_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['results'][0]['id'] if data.get('count', 0) > 0 else '')" 2>/dev/null)
    
    if [ -n "$host_id" ]; then
        echo "   Host ID: ${host_id}"
        echo "7. Eliminando host 'localhost'..."
        delete_resource "hosts" "localhost" "$host_id"
    else
        echo -e "${YELLOW}   ⚠ Host 'localhost' no encontrado${NC}"
    fi
    echo ""
    
    # Eliminar inventory
    echo "8. Eliminando inventory 'demo-ia-inventory'..."
    delete_resource "inventories" "demo-ia-inventory" "$inventory_id"
else
    echo -e "${YELLOW}   ⚠ Inventory 'demo-ia-inventory' no encontrado${NC}"
fi
echo ""

# Eliminar proyecto
echo "9. Eliminando proyecto 'demo-ia-proyecto'..."
delete_resource "projects" "demo-ia-proyecto"
echo ""

echo "============================================================"
echo -e "${GREEN}✓ Limpieza completada${NC}"
echo "============================================================"
echo ""

