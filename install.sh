#!/bin/bash
# ==============================================================================
#  INSTALADOR AUTÓNOMO Y PARCHE DE COMPATIBILIDAD UBUNTU 22.04 / 24.04 / 26.04
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31m[!] ERROR: Este instalador requiere privilegios de ROOT.\e[0m"
  echo -e "\e[1;33m[TIP] Ejecuta 'sudo su' antes de correr este comando.\e[0m"
  exit 1
fi

echo -e "\e[1;32m=========================================================="
echo " 🛡️ INSTALANDO PANEL CHUMO COMPATIBLE CON UBUNTU 22-26"
echo "==========================================================\e[0m"

# 1. Instalar paquetes y dependencias del sistema (Incluye SCREEN, PYTHON3, LSOF, PSMISC)
echo -e "\e[1;34m[+] Actualizando repositorios e instalando paquetes básicos (screen, python3, etc.)...\e[0m"
apt-get update -y
apt-get install -y curl wget net-tools python3 python3-pip tar unzip ufw iptables lsof bc jq dropbear stunnel4 screen procps psmisc python-is-python3 2>/dev/null || apt-get install -y screen python3 python3-pip net-tools lsof bc jq dropbear stunnel4 psmisc

# Enlazar python3 como comando universal 'python' y 'python2'
ln -sf /usr/bin/python3 /usr/bin/python 2>/dev/null
ln -sf /usr/bin/python3 /usr/bin/python2 2>/dev/null

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
echo -e "\e[1;34m[+] Desplegando scripts, módulos y proxies Python 3...\e[0m"
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

# Crear alias de archivos Python para que ningún script antiguo dé error 404/Missing File
for pyfile in PDirect.py PGet.py POpen.py PPriv.py PPub.py; do
    if [ -f "/etc/adm-lite/$pyfile" ]; then
        cp -f "/etc/adm-lite/$pyfile" "/etc/adm-lite/${pyfile%.py}80.py" 2>/dev/null
        cp -f "/etc/adm-lite/$pyfile" "/etc/adm-lite/P3${pyfile}" 2>/dev/null
        cp -f "/etc/adm-lite/$pyfile" "/etc/adm-lite/P3${pyfile%.py}80.py" 2>/dev/null

        cp -f "/etc/adm-lite/$pyfile" "/bin/ejecutar/${pyfile%.py}80.py" 2>/dev/null
        cp -f "/etc/adm-lite/$pyfile" "/bin/ejecutar/P3${pyfile}" 2>/dev/null
        cp -f "/etc/adm-lite/$pyfile" "/bin/ejecutar/P3${pyfile%.py}80.py" 2>/dev/null

        cp -f "/etc/adm-lite/$pyfile" "/root/$pyfile" 2>/dev/null
        cp -f "/etc/adm-lite/$pyfile" "/root/${pyfile%.py}80.py" 2>/dev/null
        cp -f "/etc/adm-lite/$pyfile" "/root/P3${pyfile}" 2>/dev/null
        cp -f "/etc/adm-lite/$pyfile" "/root/P3${pyfile%.py}80.py" 2>/dev/null
    fi
done

# 5. Enlazar comandos clave y parchar archivos faltantes en Ubuntu 24/26
echo -e "\e[1;34m[+] Parching archivos y ejecutables del sistema...\e[0m"
ln -sf /etc/adm-lite/msg /usr/bin/msg
ln -sf /etc/adm-lite/msg /bin/msg
ln -sf /etc/adm-lite/msg /bin/ejecutar/msg

touch /etc/sysctl.conf
echo "v3.9.9" > /etc/adm-lite/v-local.log
echo "v3.9.9" > /bin/ejecutar/v-local.log
echo "v3.9.9" > /bin/ejecutar/v-new.log
touch /bin/ejecutar/exito

curl -4 -sL https://api.ipify.org > /bin/ejecutar/IPcgh 2>/dev/null || hostname -I | awk '{print $1}' > /bin/ejecutar/IPcgh
cp /bin/ejecutar/IPcgh /etc/adm-lite/IPcgh 2>/dev/null

# Fix para garantizar que el menú reconozca 'msg' y 'selection_fun'
if [ -f /etc/adm-lite/menu ]; then
    sed -i '1s|^|source /bin/ejecutar/msg 2>/dev/null\n|' /etc/adm-lite/menu
fi

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
echo " ✅ INSTALACIÓN Y OPTIMIZACIÓN UBUNTU 22/24/26 COMPLETADA"
echo "=========================================================="
echo -e " Accede a tu panel en cualquier momento escribiendo:"
echo -e " 👉  \e[1;33mmenu\e[0m  o  \e[1;33mchumo\e[0m  o  \e[1;33madm\e[0m"
echo -e "==========================================================\e[0m"
