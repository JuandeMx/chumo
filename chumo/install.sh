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

# 2. Preparar directorios de trabajo oficiales (incluyendo /etc/ADMcgh)
echo -e "\e[1;34m[+] Preparando directorios del sistema (/etc/adm-lite, /etc/ADMcgh, /bin/ejecutar)...\e[0m"
mkdir -p /etc/adm-lite
mkdir -p /etc/ADMcgh
mkdir -p /etc/ger-inst
mkdir -p /etc/cgh
mkdir -p /bin/ejecutar
mkdir -p /usr/bin/ejecutar

# 3. Localizar directorios de instalación del repositorio
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$SCRIPT_DIR/chumo/core" ]; then
    INSTALL_DIR="$SCRIPT_DIR/chumo"
elif [ -d "$SCRIPT_DIR/core" ]; then
    INSTALL_DIR="$SCRIPT_DIR"
else
    echo -e "\e[1;34m[+] Descargando última versión fresca desde GitHub...\e[0m"
    rm -rf /tmp/chumo_download
    git clone https://github.com/JuandeMx/chumo.git /tmp/chumo_download
    INSTALL_DIR="/tmp/chumo_download/chumo"
fi

# Limpieza preventiva total de archivos legados obsoletos en el sistema
rm -rf /etc/adm-lite/* /etc/ADMcgh/* /bin/ejecutar/* 2>/dev/null
mkdir -p /etc/adm-lite /etc/ADMcgh /bin/ejecutar /usr/bin/ejecutar

# 4. Copiar archivos del núcleo (core) y módulos al sistema
echo -e "\e[1;34m[+] Desplegando scripts, módulos y proxies Python 3...\e[0m"
if [ -d "$INSTALL_DIR/core" ]; then
    cp -rf "$INSTALL_DIR/core/"* /etc/adm-lite/
    cp -rf "$INSTALL_DIR/core/"* /etc/ADMcgh/
    cp -rf "$INSTALL_DIR/core/"* /bin/ejecutar/
    cp -rf "$INSTALL_DIR/core/"* /usr/bin/ejecutar/
fi

if [ -d "$INSTALL_DIR/modules" ]; then
    cp -rf "$INSTALL_DIR/modules/"* /etc/adm-lite/
    cp -rf "$INSTALL_DIR/modules/"* /etc/ADMcgh/
    cp -rf "$INSTALL_DIR/modules/"* /bin/ejecutar/
    cp -rf "$INSTALL_DIR/modules/"* /usr/bin/ejecutar/
fi

# Copiar alias de módulos para compatibilidad total de llamadas
cp -f /etc/adm-lite/install_proxy_python.sh /etc/adm-lite/mx-proxies.sh 2>/dev/null
cp -f /etc/adm-lite/install_proxy_python.sh /etc/ADMcgh/mx-proxies.sh 2>/dev/null
cp -f /etc/adm-lite/install_ssl_python.sh /etc/adm-lite/mx-ssl-python.sh 2>/dev/null
cp -f /etc/adm-lite/install_dropbear.sh /etc/adm-lite/mx-dropbear.sh 2>/dev/null
cp -f /etc/adm-lite/install_openvpn.sh /etc/adm-lite/mx-openvpn.sh 2>/dev/null
cp -f /etc/adm-lite/install_stunnel4.sh /etc/adm-lite/mx-stunnel.sh 2>/dev/null

# Crear enlace simbólico de respaldo /etc/ADMcgh -> /etc/adm-lite para sincronizar cualquier cambio
cp -rf /etc/adm-lite/* /etc/ADMcgh/ 2>/dev/null

# Crear alias de archivos Python para que ningún script antiguo dé error 404/Missing File
for pyfile in PDirect.py PGet.py POpen.py PPriv.py PPub.py; do
    if [ -f "/etc/adm-lite/$pyfile" ]; then
        for target_dir in /etc/adm-lite /etc/ADMcgh /bin/ejecutar /root; do
            mkdir -p "$target_dir"
            cp -f "/etc/adm-lite/$pyfile" "$target_dir/$pyfile" 2>/dev/null
            cp -f "/etc/adm-lite/$pyfile" "$target_dir/${pyfile%.py}80.py" 2>/dev/null
            cp -f "/etc/adm-lite/$pyfile" "$target_dir/P3${pyfile}" 2>/dev/null
            cp -f "/etc/adm-lite/$pyfile" "$target_dir/P3${pyfile%.py}80.py" 2>/dev/null
            chmod +x "$target_dir/"*.py 2>/dev/null
        done
    fi
done

# 5. Enlazar comandos clave y parchar archivos faltantes en Ubuntu 24/26
echo -e "\e[1;34m[+] Parching archivos y ejecutables del sistema...\e[0m"
ln -sf /etc/adm-lite/msg /usr/bin/msg
ln -sf /etc/adm-lite/msg /bin/msg
ln -sf /etc/adm-lite/msg /bin/ejecutar/msg

touch /etc/sysctl.conf
echo "v3.9.9" > /etc/adm-lite/v-local.log
echo "v3.9.9" > /etc/ADMcgh/v-local.log
echo "v3.9.9" > /bin/ejecutar/v-local.log
echo "v3.9.9" > /bin/ejecutar/v-new.log
touch /bin/ejecutar/exito

curl -4 -sL https://api.ipify.org > /bin/ejecutar/IPcgh 2>/dev/null || hostname -I | awk '{print $1}' > /bin/ejecutar/IPcgh
cp /bin/ejecutar/IPcgh /etc/adm-lite/IPcgh 2>/dev/null
cp /bin/ejecutar/IPcgh /etc/ADMcgh/IPcgh 2>/dev/null

# Preservar menú limpio intacto

# 6. Aplicar permisos de ejecución
echo -e "\e[1;34m[+] Configurando permisos de ejecución...\e[0m"
chmod +x /etc/adm-lite/* 2>/dev/null
chmod +x /etc/ADMcgh/* 2>/dev/null
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
