#!/bin/bash
# Instalador DinÃ¡mico Dropbear SSH

echo -e "\e[1;36m=========================================================\e[0m"
echo -e "\e[1;33m             INSTALADOR DROPBEAR SSH\e[0m"
echo -e "\e[1;36m=========================================================\e[0m"
read -p " Â¿En quÃ© puerto deseas instalar Dropbear SSH? (ej: 44, 443, etc): " drop_port

if [[ -z "$drop_port" ]]; then
    echo -e "\e[1;31mâŒ Cancelado. Puerto invÃ¡lido.\e[0m"
    sleep 2
    exit 1
fi

echo -e "\n\e[1;32m[+] Instalando y configurando motor Dropbear en puerto $drop_port...\e[0m"

# Instalar paquete Dropbear del sistema para obtener configuraciones e integraciÃ³n de systemd
DEBIAN_FRONTEND=noninteractive apt-get install -y dropbear 2>/dev/null

# Compilar Dropbear con soporte para algoritmos antiguos (compatibilidad con HTTP Custom)
echo -e "\e[1;33m[+] Compilando Dropbear desde cÃ³digo fuente con algoritmos heredados (KEX, Ciphers)...\e[0m"
mkdir -p /var/log/ChumoGH
echo "=== Iniciando compilaciÃ³n de Dropbear ===" > /var/log/ChumoGH/dropbear_compile.log

echo -e "\e[1;33m[+] Instalando dependencias de compilaciÃ³n...\e[0m"
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential zlib1g-dev wget bzip2 libcrypt-dev libpam0g-dev >> /var/log/ChumoGH/dropbear_compile.log 2>&1; then
    echo -e "\e[1;31mâŒ Error al instalar dependencias de compilaciÃ³n.\e[0m"
    echo -e "\e[1;33m--- DETALLE DEL ERROR DE DEPENDENCIAS ---\e[0m"
    tail -n 15 /var/log/ChumoGH/dropbear_compile.log
    exit 1
fi

cd /tmp
rm -rf dropbear-2022.83*
echo -e "\e[1;33m[+] Descargando cÃ³digo fuente de Dropbear 2022.83...\\e[0m"
if wget -q https://matt.ucc.asn.au/dropbear/releases/dropbear-2022.83.tar.bz2 || wget -q https://dropbear.nl/mirror/releases/dropbear-2022.83.tar.bz2; then
    tar -xf dropbear-2022.83.tar.bz2 >> /var/log/ChumoGH/dropbear_compile.log 2>&1
    cd dropbear-2022.83
    
    # Escribir localoptions.h - SOLO macros vÃ¡lidas del default_options.h oficial con #undef para evitar advertencias/errores
    cat <<'LOCALOPT' > localoptions.h
#ifndef DROPBEAR_LOCALOPTIONS_H
#define DROPBEAR_LOCALOPTIONS_H

/* Habilitar CBC mode (deshabilitado por defecto) */
#undef DROPBEAR_ENABLE_CBC_MODE
#define DROPBEAR_ENABLE_CBC_MODE 1

/* Habilitar 3DES (deshabilitado por defecto) */
#undef DROPBEAR_3DES
#define DROPBEAR_3DES 1

/* Habilitar SHA1 HMAC (deshabilitado por defecto en nuevas versiones) */
#undef DROPBEAR_SHA1_HMAC
#define DROPBEAR_SHA1_HMAC 1

#undef DROPBEAR_SHA1_96_HMAC
#define DROPBEAR_SHA1_96_HMAC 1

/* Habilitar RSA con SHA1 (requerido para clientes antiguos como HTTP Custom) */
#undef DROPBEAR_RSA_SHA1
#define DROPBEAR_RSA_SHA1 1

/* Habilitar DH Group14 SHA1 y SHA256 (compatibilidad) */
#undef DROPBEAR_DH_GROUP14_SHA1
#define DROPBEAR_DH_GROUP14_SHA1 1

#undef DROPBEAR_DH_GROUP14_SHA256
#define DROPBEAR_DH_GROUP14_SHA256 1

/* Habilitar DSS (algunos clientes antiguos lo requieren) */
#undef DROPBEAR_DSS
#define DROPBEAR_DSS 1

/* Aumentar lÃ­mites de Banner para soportar HTML banners grandes */
#undef MAX_BANNER_SIZE
#define MAX_BANNER_SIZE 16384

/* Habilitar soporte PAM y deshabilitar PASSWORD directo */
#undef DROPBEAR_SVR_PAM_AUTH
#define DROPBEAR_SVR_PAM_AUTH 1

#undef DROPBEAR_SVR_PASSWORD_AUTH
#define DROPBEAR_SVR_PASSWORD_AUTH 0

#endif /* DROPBEAR_LOCALOPTIONS_H */
LOCALOPT

    # Modificar sysoptions.h directamente ya que no tiene guardas #ifndef
    sed -i 's/#define MAX_BANNER_SIZE 2050/#define MAX_BANNER_SIZE 16384/g' sysoptions.h
    sed -i 's/#define MAX_BANNER_LINES 20/#define MAX_BANNER_LINES 100/g' sysoptions.h

    echo -e "\e[1;33m[+] Configurando entorno (./configure --enable-pam)...\\e[0m"
    echo "[+] Ejecutando ./configure --enable-pam..." >> /var/log/ChumoGH/dropbear_compile.log
    if ! ./configure --enable-pam >> /var/log/ChumoGH/dropbear_compile.log 2>&1; then
        echo -e "\e[1;31mâŒ Error en la configuraciÃ³n de Dropbear (./configure).\\e[0m"
        echo -e "\e[1;33m--- DETALLE DEL ERROR DE CONFIGURACIÃ“N ---\\e[0m"
        tail -n 25 /var/log/ChumoGH/dropbear_compile.log
        cd /tmp
        exit 1
    fi
    
    echo -e "\e[1;33m[+] Compilando binarios (make PROGRAMS='dropbear dropbearkey')...\\e[0m"
    echo "[+] Ejecutando make..." >> /var/log/ChumoGH/dropbear_compile.log
    if make clean >> /var/log/ChumoGH/dropbear_compile.log 2>&1 && make PROGRAMS="dropbear dropbearkey" -j$(nproc) >> /var/log/ChumoGH/dropbear_compile.log 2>&1; then
        systemctl stop dropbear.socket 2>/dev/null || true
        systemctl stop dropbear 2>/dev/null || true
        cp -f dropbear /usr/sbin/dropbear
        cp -f dropbearkey /usr/bin/dropbearkey
        [ -f dropbearconvert ] && cp -f dropbearconvert /usr/bin/dropbearconvert
        
        # Crear configuraciÃ³n PAM para Dropbear si no existe
        mkdir -p /etc/pam.d
        cat <<'PAMEOF' >/etc/pam.d/dropbear
@include common-auth
@include common-account
@include common-session
account optional pam_exec.so stdout /etc/adm-lite/core/maximus_banner.sh
PAMEOF

        echo -e "\e[1;32m[âœ“] Dropbear optimizado y compilado exitosamente (Soporte PAM activo).\\e[0m"
    else
        echo -e "\e[1;31mâŒ Error al compilar (make). Se usarÃ¡ el binario predeterminado del sistema.\\e[0m"
        echo -e "\e[1;33m--- DETALLE DEL ERROR DE COMPILACIÃ“N (Ãšltimas 30 lÃ­neas) ---\\e[0m"
        tail -n 30 /var/log/ChumoGH/dropbear_compile.log
        cd /tmp
        exit 1
    fi
else
    echo -e "\e[1;31mâŒ No se pudo descargar el cÃ³digo fuente. Se usarÃ¡ el binario predeterminado del sistema.\\e[0m"
    exit 1
fi
cd /tmp





# Generar llaves criptogrÃ¡ficas de Dropbear (por si falta)
mkdir -p /etc/dropbear
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key 2>/dev/null
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key 2>/dev/null
dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key 2>/dev/null

# Limpiar config vieja y escribir la correcta
cat > /etc/default/dropbear << DROPCONF
NO_START=0
DROPBEAR_PORT=$drop_port
DROPBEAR_EXTRA_ARGS="-b /etc/dropbear/banner -K 30 -I 0"
DROPBEAR_BANNER="/etc/dropbear/banner"
DROPBEAR_RECEIVE_WINDOW=65536
DROPCONF

# Autorizar shells para usuarios tÃºnel
grep -q "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells


# Desactivar socket mode (Ubuntu 24.04 mitigaciÃ³n)
systemctl stop dropbear.socket 2>/dev/null || true
systemctl disable dropbear.socket 2>/dev/null || true
systemctl mask dropbear.socket 2>/dev/null || true

# Eliminar posible override.conf conflictivo
rm -f /etc/systemd/system/dropbear.service.d/override.conf 2>/dev/null

# Abrir ufw
ufw allow ${drop_port}/tcp 2>/dev/null

# Aplicar persistencia
systemctl daemon-reload
systemctl enable dropbear 2>/dev/null
systemctl restart dropbear
echo -e "\e[1;32m[âœ“] Dropbear activo en puerto $drop_port.\e[0m"
sleep 3
