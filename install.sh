#!/bin/bash
# ==============================================================================
#  INSTALADOR AUTÓNOMO DEL PANEL CHUMO - 100% LIBRE DE KEYS / LICENCIAS
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31m[!] ERROR: Este instalador requiere privilegios de ROOT.\e[0m"
  echo -e "\e[1;33m[TIP] Ejecuta 'sudo su' antes de correr este comando.\e[0m"
  exit 1
fi

echo -e "\e[1;32m=========================================================="
echo " 🛡️ INSTALANDO PANEL CHUMO EN TU SERVIDOR (SIN KEY)"
echo "==========================================================\e[0m"

# 1. Instalar paquetes y dependencias del sistema
echo -e "\e[1;34m[+] Actualizando repositorios e instalando paquetes básicos...\e[0m"
apt-get update -y
apt-get install -y curl wget net-tools python3 python3-pip tar unzip ufw iptables lsof bc jq dropbear stunnel4

# 2. Preparar directorios de trabajo oficiales
echo -e "\e[1;34m[+] Preparando directorios del sistema (/etc/adm-lite, /bin/ejecutar)...\e[0m"
mkdir -p /etc/adm-lite
mkdir -p /etc/ger-inst
mkdir -p /etc/cgh
mkdir -p /bin/ejecutar
mkdir -p /usr/bin/ejecutar

# 3. Descargar el repositorio desde GitHub si no estamos en la carpeta del script
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$INSTALL_DIR/core" ]; then
    echo -e "\e[1;34m[+] Clonando componentes desde el repositorio remoto...\e[0m"
    rm -rf /tmp/chumo_repo
    git clone https://github.com/JuandeMx/chumo.git /tmp/chumo_repo 2>/dev/null || wget -q https://github.com/JuandeMx/chumo/archive/refs/heads/main.zip -O /tmp/chumo.zip && unzip -q /tmp/chumo.zip -d /tmp/ && mv /tmp/chumo-main /tmp/chumo_repo
    INSTALL_DIR="/tmp/chumo_repo/chumo"
fi

# 4. Copiar archivos del núcleo (core) y módulos al sistema
echo -e "\e[1;34m[+] Desplegando scripts y ejecutables...\e[0m"
if [ -d "$INSTALL_DIR/core" ]; then
    cp -rf "$INSTALL_DIR/core/"* /etc/adm-lite/
    cp -rf "$INSTALL_DIR/core/"* /bin/ejecutar/
    cp -rf "$INSTALL_DIR/core/"* /usr/bin/ejecutar/
fi

if [ -d "$INSTALL_DIR/modules" ]; then
    cp -rf "$INSTALL_DIR/modules/"* /etc/adm-lite/
    cp -rf "$INSTALL_DIR/modules/"* /bin/ejecutar/
    cp -rf "$INSTALL_DIR/modules/"* /usr/bin/ejecutar/
fi

# 5. Enlazar comandos clave (/usr/bin/msg, /bin/ejecutar)
ln -sf /etc/adm-lite/msg /usr/bin/msg
ln -sf /etc/adm-lite/msg /bin/msg
ln -sf /etc/adm-lite/msg /bin/ejecutar/msg
touch /etc/sysctl.conf
touch /bin/ejecutar/v-new.log
touch /bin/ejecutar/exito
curl -4 -sL https://api.ipify.org > /bin/ejecutar/IPcgh 2>/dev/null || hostname -I | awk '{print $1}' > /bin/ejecutar/IPcgh

# 6. Aplicar permisos de ejecución
echo -e "\e[1;34m[+] Configurando permisos de ejecución...\e[0m"
chmod +x /etc/adm-lite/*
chmod +x /bin/ejecutar/* 2>/dev/null
chmod +x /usr/bin/msg /bin/msg

# 7. Crear accesos directos globales en la consola
ln -sf /etc/adm-lite/menu /usr/bin/menu
ln -sf /etc/adm-lite/menu /usr/bin/adm
ln -sf /etc/adm-lite/menu /usr/bin/cgh
ln -sf /etc/adm-lite/menu /usr/bin/chumo
chmod +x /usr/bin/menu /usr/bin/adm /usr/bin/cgh /usr/bin/chumo

echo -e "\e[1;32m=========================================================="
echo " ✅ INSTALACIÓN Y CORRECCIÓN COMPLETADA CON ÉXITO"
echo "=========================================================="
echo -e " Accede a tu panel en cualquier momento escribiendo:"
echo -e " 👉  \e[1;33mmenu\e[0m  o  \e[1;33mchumo\e[0m  o  \e[1;33madm\e[0m"
echo -e "==========================================================\e[0m"
