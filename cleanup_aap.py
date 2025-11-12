#!/usr/bin/env python3
"""
Script para limpiar recursos creados en Ansible Automation Platform
Elimina job templates, hosts, inventories y proyectos con prefijo demo-ia
"""

import yaml
import json
import requests
import sys
import os
from urllib3.exceptions import InsecureRequestWarning

# Deshabilitar warnings de SSL para certificados autofirmados
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


def load_vars(vars_file='vars.yml'):
    """Carga las variables del archivo vars.yml"""
    if not os.path.exists(vars_file):
        print(f"Error: No se encuentra el archivo {vars_file}")
        sys.exit(1)
    
    with open(vars_file, 'r') as f:
        vars_data = yaml.safe_load(f)
    
    required_vars = ['aap_url', 'aap_username', 'aap_password']
    for var in required_vars:
        if var not in vars_data:
            print(f"Error: Falta la variable '{var}' en {vars_file}")
            sys.exit(1)
    
    return vars_data


def get_resource_id(base_url, username, password, resource_type, resource_name):
    """Obtiene el ID de un recurso por nombre"""
    url = f"{base_url}/api/controller/v2/{resource_type}/?name={resource_name}"
    response = requests.get(url, auth=(username, password), verify=False)
    
    if response.status_code != 200:
        return None
    
    data = response.json()
    if data['count'] == 0:
        return None
    
    return data['results'][0]['id']


def delete_resource(base_url, username, password, resource_type, resource_name, resource_id=None):
    """Elimina un recurso"""
    if resource_id is None:
        resource_id = get_resource_id(base_url, username, password, resource_type, resource_name)
    
    if resource_id is None:
        print(f"⚠ {resource_type} '{resource_name}' no encontrado")
        return False
    
    url = f"{base_url}/api/controller/v2/{resource_type}/{resource_id}/"
    response = requests.delete(url, auth=(username, password), verify=False)
    
    if response.status_code in [204, 200]:
        print(f"✓ {resource_type} '{resource_name}' eliminado (ID: {resource_id})")
        return True
    else:
        print(f"✗ Error al eliminar {resource_type} '{resource_name}': {response.status_code}")
        if response.text:
            print(response.text)
        return False


def main():
    """Función principal"""
    print("=" * 60)
    print("Limpieza de Recursos en Ansible Automation Platform")
    print("=" * 60)
    print()
    
    # Cargar variables
    print("1. Cargando variables de vars.yml...")
    vars_data = load_vars()
    base_url = vars_data['aap_url'].rstrip('/')
    username = vars_data['aap_username']
    password = vars_data['aap_password']
    print(f"   URL: {base_url}")
    print(f"   Usuario: {username}")
    print()
    
    # Verificar conexión
    print("2. Verificando conexión con AAP...")
    url = f"{base_url}/api/controller/v2/me/"
    response = requests.get(url, auth=(username, password), verify=False)
    if response.status_code == 200:
        print("   ✓ Conexión exitosa")
    else:
        print(f"   ✗ Error de conexión: {response.status_code}")
        sys.exit(1)
    print()
    
    # Confirmación
    print("3. Recursos que se eliminarán:")
    print("   - Job Template: demo-ia-get-status")
    print("   - Host: localhost (del inventory demo-ia-inventory)")
    print("   - Inventory: demo-ia-inventory")
    print("   - Proyecto: demo-ia-proyecto")
    print()
    confirm = input("¿Deseas continuar con la eliminación? (s/N): ")
    if confirm.lower() != 's':
        print("Operación cancelada.")
        sys.exit(0)
    print()
    
    # Eliminar job template
    print("4. Eliminando job template 'demo-ia-get-status'...")
    delete_resource(base_url, username, password, "job_templates", "demo-ia-get-status")
    print()
    
    # Obtener inventory ID para eliminar el host
    print("5. Obteniendo inventory 'demo-ia-inventory'...")
    inventory_id = get_resource_id(base_url, username, password, "inventories", "demo-ia-inventory")
    if inventory_id:
        print(f"   Inventory ID: {inventory_id}")
        
        # Obtener host localhost del inventory
        print("6. Obteniendo host 'localhost' del inventory...")
        hosts_url = f"{base_url}/api/controller/v2/inventories/{inventory_id}/hosts/?name=localhost"
        hosts_response = requests.get(hosts_url, auth=(username, password), verify=False)
        if hosts_response.status_code == 200:
            hosts_data = hosts_response.json()
            if hosts_data['count'] > 0:
                host_id = hosts_data['results'][0]['id']
                print(f"   Host ID: {host_id}")
                print("7. Eliminando host 'localhost'...")
                delete_resource(base_url, username, password, "hosts", "localhost", host_id)
            else:
                print("   ⚠ Host 'localhost' no encontrado")
        print()
        
        # Eliminar inventory
        print("8. Eliminando inventory 'demo-ia-inventory'...")
        delete_resource(base_url, username, password, "inventories", "demo-ia-inventory", inventory_id)
    else:
        print("   ⚠ Inventory 'demo-ia-inventory' no encontrado")
    print()
    
    # Eliminar proyecto
    print("9. Eliminando proyecto 'demo-ia-proyecto'...")
    delete_resource(base_url, username, password, "projects", "demo-ia-proyecto")
    print()
    
    print("=" * 60)
    print("✓ Limpieza completada")
    print("=" * 60)
    print()


if __name__ == '__main__':
    main()

