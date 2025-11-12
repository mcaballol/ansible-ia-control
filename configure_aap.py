#!/usr/bin/env python3
"""
Script para configurar recursos en Ansible Automation Platform
Lee las variables de vars.yml y crea proyecto, inventory y host
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


def get_organization_id(base_url, username, password):
    """Obtiene el ID de la organización Default"""
    url = f"{base_url}/api/controller/v2/organizations/"
    response = requests.get(url, auth=(username, password), verify=False)
    
    if response.status_code != 200:
        print(f"Error al obtener organizaciones: {response.status_code}")
        print(response.text)
        sys.exit(1)
    
    data = response.json()
    if data['count'] == 0:
        print("Error: No se encontraron organizaciones")
        sys.exit(1)
    
    # Buscar la organización Default
    for org in data['results']:
        if org.get('name') == 'Default':
            return org['id']
    
    # Si no encuentra Default, usar la primera
    return data['results'][0]['id']


def get_credential_id(base_url, username, password, cred_name='github'):
    """Obtiene el ID de la credencial especificada"""
    url = f"{base_url}/api/controller/v2/credentials/?name={cred_name}"
    response = requests.get(url, auth=(username, password), verify=False)
    
    if response.status_code != 200:
        print(f"Error al obtener credenciales: {response.status_code}")
        print(response.text)
        sys.exit(1)
    
    data = response.json()
    if data['count'] == 0:
        print(f"Error: No se encontró la credencial '{cred_name}'")
        sys.exit(1)
    
    return data['results'][0]['id']


def create_project(base_url, username, password, org_id, cred_id, project_name='demo-ia-proyecto', 
                   git_url='git@github.com:mcaballol/ansible-ia-control.git'):
    """Crea un proyecto en AAP"""
    url = f"{base_url}/api/controller/v2/projects/"
    payload = {
        "name": project_name,
        "organization": org_id,
        "scm_type": "git",
        "scm_url": git_url,
        "credential": cred_id
    }
    
    response = requests.post(url, auth=(username, password), json=payload, verify=False)
    
    if response.status_code == 201:
        project = response.json()
        print(f"✓ Proyecto '{project_name}' creado exitosamente (ID: {project['id']})")
        return project['id']
    elif response.status_code == 400:
        # Puede que el proyecto ya exista
        error_data = response.json()
        if 'name' in error_data and 'already exists' in str(error_data['name']):
            print(f"⚠ El proyecto '{project_name}' ya existe, actualizando configuración...")
            # Buscar el proyecto existente
            search_url = f"{base_url}/api/controller/v2/projects/?name={project_name}"
            search_response = requests.get(search_url, auth=(username, password), verify=False)
            if search_response.status_code == 200:
                search_data = search_response.json()
                if search_data['count'] > 0:
                    project_id = search_data['results'][0]['id']
                    # Actualizar el proyecto con la credencial
                    update_url = f"{base_url}/api/controller/v2/projects/{project_id}/"
                    update_response = requests.patch(update_url, auth=(username, password), json=payload, verify=False)
                    if update_response.status_code in [200, 201]:
                        print(f"✓ Proyecto existente actualizado (ID: {project_id})")
                        return project_id
                    else:
                        print(f"⚠ No se pudo actualizar el proyecto, usando existente (ID: {project_id})")
                        return project_id
        print(f"Error al crear proyecto: {response.status_code}")
        print(json.dumps(error_data, indent=2))
        sys.exit(1)
    else:
        print(f"Error al crear proyecto: {response.status_code}")
        print(response.text)
        sys.exit(1)


def create_inventory(base_url, username, password, org_id, inventory_name='demo-ia-inventory'):
    """Crea un inventory en AAP"""
    url = f"{base_url}/api/controller/v2/inventories/"
    payload = {
        "name": inventory_name,
        "organization": org_id
    }
    
    response = requests.post(url, auth=(username, password), json=payload, verify=False)
    
    if response.status_code == 201:
        inventory = response.json()
        print(f"✓ Inventory '{inventory_name}' creado exitosamente (ID: {inventory['id']})")
        return inventory['id']
    elif response.status_code == 400:
        # Puede que el inventory ya exista
        error_data = response.json()
        if 'name' in error_data and 'already exists' in str(error_data['name']):
            print(f"⚠ El inventory '{inventory_name}' ya existe, obteniendo información...")
            # Buscar el inventory existente
            search_url = f"{base_url}/api/controller/v2/inventories/?name={inventory_name}"
            search_response = requests.get(search_url, auth=(username, password), verify=False)
            if search_response.status_code == 200:
                search_data = search_response.json()
                if search_data['count'] > 0:
                    inventory_id = search_data['results'][0]['id']
                    print(f"✓ Inventory existente encontrado (ID: {inventory_id})")
                    return inventory_id
        print(f"Error al crear inventory: {response.status_code}")
        print(json.dumps(error_data, indent=2))
        sys.exit(1)
    else:
        print(f"Error al crear inventory: {response.status_code}")
        print(response.text)
        sys.exit(1)


def create_host(base_url, username, password, inventory_id, host_name='localhost'):
    """Crea un host en el inventory"""
    url = f"{base_url}/api/controller/v2/hosts/"
    payload = {
        "name": host_name,
        "inventory": inventory_id,
        "variables": "ansible_connection: local\n"
    }
    
    response = requests.post(url, auth=(username, password), json=payload, verify=False)
    
    if response.status_code == 201:
        host = response.json()
        print(f"✓ Host '{host_name}' creado exitosamente (ID: {host['id']})")
        return host['id']
    elif response.status_code == 400:
        # Puede que el host ya exista
        error_data = response.json()
        if 'name' in error_data and 'already exists' in str(error_data['name']):
            print(f"⚠ El host '{host_name}' ya existe en el inventory")
            # Verificar si existe en este inventory
            hosts_url = f"{base_url}/api/controller/v2/inventories/{inventory_id}/hosts/?name={host_name}"
            hosts_response = requests.get(hosts_url, auth=(username, password), verify=False)
            if hosts_response.status_code == 200:
                hosts_data = hosts_response.json()
                if hosts_data['count'] > 0:
                    host_id = hosts_data['results'][0]['id']
                    # Actualizar el host con la conexión local
                    update_url = f"{base_url}/api/controller/v2/hosts/{host_id}/"
                    update_response = requests.patch(update_url, auth=(username, password), json=payload, verify=False)
                    if update_response.status_code in [200, 201]:
                        print(f"✓ Host existente actualizado con conexión local (ID: {host_id})")
                    else:
                        print(f"⚠ No se pudo actualizar el host, usando existente (ID: {host_id})")
                    return host_id
        print(f"Error al crear host: {response.status_code}")
        print(json.dumps(error_data, indent=2))
        return None
    else:
        print(f"Error al crear host: {response.status_code}")
        print(response.text)
        return None


def main():
    """Función principal"""
    print("=" * 60)
    print("Configuración de Ansible Automation Platform")
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
    
    # Obtener organización
    print("2. Obteniendo organización...")
    org_id = get_organization_id(base_url, username, password)
    print(f"   Organización ID: {org_id}")
    print()
    
    # Obtener credencial
    print("3. Obteniendo credencial 'github'...")
    cred_id = get_credential_id(base_url, username, password, 'github')
    print(f"   Credencial ID: {cred_id}")
    print()
    
    # Crear proyecto
    print("4. Creando proyecto 'demo-ia-proyecto'...")
    project_id = create_project(base_url, username, password, org_id, cred_id)
    print()
    
    # Crear inventory
    print("5. Creando inventory 'demo-ia-inventory'...")
    inventory_id = create_inventory(base_url, username, password, org_id)
    print()
    
    # Crear host
    print("6. Agregando host 'localhost' al inventory...")
    host_id = create_host(base_url, username, password, inventory_id)
    print()
    
    print("=" * 60)
    print("✓ Configuración completada exitosamente")
    print("=" * 60)
    print()
    print("Resumen de recursos creados:")
    print(f"  - Proyecto: demo-ia-proyecto (ID: {project_id})")
    print(f"  - Inventory: demo-ia-inventory (ID: {inventory_id})")
    print(f"  - Host: localhost (ID: {host_id})")
    print()


if __name__ == '__main__':
    main()

