#!/bin/bash
# ChumoGH - Dropbear Manager
# Adapta la lÃ³gica de Chumo LATAM a la estÃ©tica de Maximus

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

ui_hr() { echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"; }
ui_subhr() { echo -e "${CYAN}â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${NC}"; }
ui_prompt() { echo -ne "${YELLOW}$1${NC}"; }
ui_pause() { read -p "Presiona Enter para continuar..." ; }
ui_header() {
    clear
    ui_hr
    echo -e "${YELLOW}           $1${NC}"
    ui_hr
}

# Obtiene la lista de puertos en uso
mportas() {
    unset portas
    portas_var=$(lsof -V -i tcp -P -n 2>/dev/null | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN")
    while read -r port; do
        var1=$(echo "$port" | awk '{print $1}')
        var2=$(echo "$port" | awk '{print $9}' | awk -F ":" '{print $2}')
        if [[ -n "$var1" && -n "$var2" ]]; then
            if ! echo -e "$portas" | grep -q "$var1 $var2"; then
                portas+="$var1 $var2\n"
            fi
        fi
    done <<<"$portas_var"
    echo -e "$portas"
}

activar_dropbear() {
    ui_header "INSTALAR / CONFIGURAR DROPBEAR"
    
    echo -e "${WHITE}Puedes activar varios puertos de forma secuencial (separados por espacio)${NC}"
    echo -e "Ejemplo: ${GREEN}22 44 80 443${NC}\n"
    
    read -p "Digite los Puertos: " -e -i "442 444" DPORT
    
    TTOTAL2=($DPORT)
    PORT2=""
    for ((i = 0; i < ${#TTOTAL2[@]}; i++)); do
        if [[ -z "$(mportas | grep -w "${TTOTAL2[$i]}")" ]]; then
            echo -e "${YELLOW}â–¶ Puerto Elegido: ${GREEN}${TTOTAL2[$i]} OK${NC}"
            PORT2="$PORT2 ${TTOTAL2[$i]}"
        else
            # Permitir si ya es dropbear el que lo tiene abierto
            if mportas | grep -q "dropbear ${TTOTAL2[$i]}"; then
                echo -e "${YELLOW}â–¶ Puerto Elegido: ${GREEN}${TTOTAL2[$i]} OK (Ya es Dropbear)${NC}"
                PORT2="$PORT2 ${TTOTAL2[$i]}"
            else
                echo -e "${YELLOW}â–¶ Puerto Elegido: ${RED}${TTOTAL2[$i]} FAIL (En Uso)${NC}"
            fi
        fi
    done
    
    if [[ -z "$PORT2" ]]; then
        echo -e "${RED}âŒ NingÃºn puerto vÃ¡lido fue elegido.${NC}"
        ui_pause
        return 1
    fi
    
    ui_hr
    echo -e "${YELLOW}[+] Instalando dependencias de Dropbear...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install dropbear -y >/dev/null 2>&1
    
    echo -e "${YELLOW}[+] Compilando Dropbear desde cÃ³digo fuente para compatibilidad con HTTP Custom...${NC}"
    mkdir -p /var/log/ChumoGH
    echo "=== Iniciando compilaciÃ³n de Dropbear ===" > /var/log/ChumoGH/dropbear_compile.log

    echo -e "${YELLOW}[+] Instalando dependencias de compilaciÃ³n...${NC}"
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential zlib1g-dev wget bzip2 libcrypt-dev libpam0g-dev >> /var/log/ChumoGH/dropbear_compile.log 2>&1; then
        echo -e "${RED}âŒ Error al instalar dependencias de compilaciÃ³n.${NC}"
        echo -e "${YELLOW}--- DETALLE DEL ERROR DE DEPENDENCIAS ---${NC}"
        tail -n 15 /var/log/ChumoGH/dropbear_compile.log
        ui_pause
        return 1
    fi

    cd /tmp
    rm -rf dropbear-2022.83*
    echo -e "${YELLOW}[+] Descargando cÃ³digo fuente de Dropbear 2022.83...${NC}"
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

/* Habilitar SHA1 HMAC (requerido para clientes como HTTP Custom) */
#undef DROPBEAR_SHA1_HMAC
#define DROPBEAR_SHA1_HMAC 1

#undef DROPBEAR_SHA1_96_HMAC
#define DROPBEAR_SHA1_96_HMAC 1

/* Habilitar RSA con SHA1 (requerido para clientes antiguos) */
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

        echo -e "${YELLOW}[+] Configurando entorno (./configure --enable-pam)...${NC}"
        echo "[+] Ejecutando ./configure --enable-pam..." >> /var/log/ChumoGH/dropbear_compile.log
        if ! ./configure --enable-pam >> /var/log/ChumoGH/dropbear_compile.log 2>&1; then
            echo -e "${RED}âŒ Error en la configuraciÃ³n de Dropbear (./configure).${NC}"
            echo -e "${YELLOW}--- DETALLE DEL ERROR DE CONFIGURACIÃ“N ---${NC}"
            tail -n 25 /var/log/ChumoGH/dropbear_compile.log
            cd /tmp
            ui_pause
            return 1
        fi
        
        echo -e "${YELLOW}[+] Compilando binarios (make)...${NC}"
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

            echo -e "${GREEN}âœ“ Dropbear optimizado y compilado exitosamente (Soporte PAM activo).${NC}"
        else
            echo -e "${RED}âŒ Error al compilar (make). Se usarÃ¡ el binario predeterminado del sistema.${NC}"
            echo -e "${YELLOW}--- DETALLE DEL ERROR DE COMPILACIÃ“N (Ãšltimas 30 lÃ­neas) ---${NC}"
            tail -n 30 /var/log/ChumoGH/dropbear_compile.log
            cd /tmp
            ui_pause
            return 1
        fi
    else
        echo -e "${RED}âŒ No se pudo descargar el cÃ³digo fuente. Se usarÃ¡ el binario predeterminado del sistema.${NC}"
        ui_pause
        return 1
    fi
    cd /tmp

    mkdir -p /etc/dropbear
    touch /etc/dropbear/banner
    
    # Escribir configuraciÃ³n
    cat <<EOF >/etc/default/dropbear
NO_START=0
DROPBEAR_EXTRA_ARGS="-b /etc/dropbear/banner -K 30 -I 0 VAR"
DROPBEAR_BANNER="/etc/dropbear/banner"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

    # Reemplazar argumentos con los puertos correspondientes
    for dpts in $PORT2; do
        sed -i "s/VAR/-p $dpts VAR/g" /etc/default/dropbear
    done
    sed -i "s/VAR//g" /etc/default/dropbear
    
    # Agregar shell falso si no existe
    grep -q "^/bin/false" /etc/shells || echo "/bin/false" >>/etc/shells
    
    # Generar host keys
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
    
    # Desactivar socket mode (Ubuntu 24.04 mitigaciÃ³n)
    systemctl stop dropbear.socket >/dev/null 2>&1 || true
    systemctl disable dropbear.socket >/dev/null 2>&1 || true
    systemctl mask dropbear.socket >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/dropbear.service.d/override.conf 2>/dev/null
    
    # Abrir puertos en el firewall
    for dpts in $PORT2; do
        ufw allow $dpts/tcp >/dev/null 2>&1
    done
    
    # Reiniciar servicios
    systemctl daemon-reload
    service ssh restart >/dev/null 2>&1
    
    # Encender Dropbear
    sed -i "s/NO_START=1/NO_START=0/g" /etc/default/dropbear 2>/dev/null
    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear >/dev/null 2>&1
    
    ui_hr
    echo -e "${GREEN}âœ“ DROPBEAR INSTALADO/CONFIGURADO CON Ã‰XITO EN PUERTOS: $PORT2${NC}"
    ui_pause
}

desactivar_dropbear() {
    ui_header "DESINSTALAR DROPBEAR"
    echo -e "${YELLOW}[+] Deteniendo Dropbear...${NC}"
    systemctl stop dropbear >/dev/null 2>&1
    systemctl disable dropbear >/dev/null 2>&1
    
    echo -e "${YELLOW}[+] Eliminando paquetes de Dropbear...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge dropbear -y >/dev/null 2>&1
    killall -9 dropbear >/dev/null 2>&1
    rm -rf /etc/dropbear/* >/dev/null 2>&1
    rm -f /etc/default/dropbear 2>/dev/null
    
    ui_hr
    echo -e "${GREEN}âœ“ DROPBEAR DESINSTALADO CON Ã‰XITO${NC}"
    ui_pause
}

while true; do
    ui_header "DROPBEAR MANAGER"
    echo -e "  ${CYAN}[1]>${WHITE} INSTALAR / CONFIGURAR DROPBEAR${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} DESINSTALAR DROPBEAR${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt "Selecciona una opciÃ³n: "
    read -r opcao
    
    case $opcao in
        1) activar_dropbear ;;
        2) desactivar_dropbear ;;
        0) break ;;
        *) continue ;;
    esac
done
