#!/bin/bash
# ==============================================================================
#  INSTALADOR OFICIAL DESBLOQUEADO (ADMcgh / CGH V3.9.9) - SIN KEY
# ==============================================================================
# Este script instala el panel completo extraído sin depender de @GEN_KEY_CGH_BOT
# ni de servidores remotos de licencias.

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31m[!] ERROR: Este instalador requiere privilegios de ROOT.\e[0m"
  echo -e "\e[1;33m[TIP] Ejecuta 'sudo su' antes de correr este comando.\e[0m"
  exit 1
fi

echo -e "\e[1;32m=========================================================="
echo " 🛡️ INSTALADOR PANEL CHUMOGH / ADMCGH V3.9.9 (LIBRE)"
echo "==========================================================\e[0m"

# 1. Actualizar repositorios e instalar dependencias básicas
echo -e "\e[1;34m[+] Instalando paquetes y dependencias del sistema...\e[0m"
apt-get update -y
apt-get install -y curl wget net-tools python3 python3-pip tar unzip ufw iptables lsof bc jq dropbear stunnel4

# 2. Crear directorios oficiales del panel
echo -e "\e[1;34m[+] Creando estructura de directorios /etc/adm-lite...\e[0m"
mkdir -p /etc/adm-lite
mkdir -p /etc/ger-inst
mkdir -p /etc/cgh

# 3. Desplegar los componentes del panel desde el paquete extraído
DIR_ORIGEN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/panel_extraido_completo"

if [ -d "$DIR_ORIGEN/adm-lite" ]; then
    cp -r "$DIR_ORIGEN/adm-lite/"* /etc/adm-lite/
fi

if [ -d "$DIR_ORIGEN/modulos_desempaquetados" ]; then
    cp -r "$DIR_ORIGEN/modulos_desempaquetados/"* /etc/adm-lite/
fi

# 4. Configurar permisos ejecutables
echo -e "\e[1;34m[+] Configurando permisos ejecutables...\e[0m"
chmod +x /etc/adm-lite/*
chmod +x /etc/adm-lite/*.sh 2>/dev/null
chmod +x /etc/adm-lite/*.py 2>/dev/null

# 5. Enlazar comandos globales del sistema (menu, adm, cgh)
ln -sf /etc/adm-lite/menu /usr/bin/menu
ln -sf /etc/adm-lite/menu /usr/bin/adm
ln -sf /etc/adm-lite/menu /usr/bin/cgh
ln -sf /etc/adm-lite/menu /usr/bin/MX
chmod +x /usr/bin/menu /usr/bin/adm /usr/bin/cgh /usr/bin/MX

echo -e "\e[1;32m=========================================================="
echo " ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE (SIN LICENCIA/KEY)"
echo "=========================================================="
echo -e " Escribe cualquiera de estos comandos para abrir tu panel:"
echo -e " 👉  \e[1;33mmenu\e[0m  o  \e[1;33madm\e[0m  o  \e[1;33mcgh\e[0m"
echo -e "==========================================================\e[0m"
