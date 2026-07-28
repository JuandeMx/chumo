#!/bin/bash
# ChumoGH - Web Dedicated SSL Installer
# RECREA LA LÃ“GICA DE terminal PERO SIN PROMPTS

MODE_OPT=$1
SSL_PORT=$2
[ -z "$SSL_PORT" ] && SSL_PORT=443

# 1. Configurar ConexiÃ³n segÃºn Modo
case $MODE_OPT in
    1) # DIRECTO
        # AutodetecciÃ³n rÃ¡pida
        BACKEND_PORT=22
        if systemctl is-active --quiet dropbear; then
            BACKEND_PORT=$(grep "DROPBEAR_PORT=" /etc/default/dropbear 2>/dev/null | cut -d= -f2 | tr -d '"')
            [ -z "$BACKEND_PORT" ] && BACKEND_PORT=44
        fi
        CONNECT_TARGET="127.0.0.1:$BACKEND_PORT"
        ;;
    2) # PROXY (Puerto 80)
        PROXY_PORT=80
        bash /etc/adm-lite/modules/install_mx-proxy.sh $PROXY_PORT > /dev/null 2>&1
        CONNECT_TARGET="127.0.0.1:$PROXY_PORT"
        ;;
    3) # UNIVERSAL (Puerto 8080)
        # Sincronizamos con la terminal para usar 8080 o 80 segÃºn preferencia
        PROXY_PORT=8080
        bash /etc/adm-lite/modules/install_mx-proxy.sh $PROXY_PORT > /dev/null 2>&1
        CONNECT_TARGET="127.0.0.1:$PROXY_PORT"
        ;;
    *)
        exit 1
        ;;
esac

# 2. InstalaciÃ³n y Certificado
apt-get install stunnel4 -y > /dev/null 2>&1
mkdir -p /etc/stunnel
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=ChumoGH/O=Maximus/C=US" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem >/dev/null 2>&1

# 3. Generar ConfiguraciÃ³n
cat > /etc/stunnel/stunnel.conf << EOF
cert = /etc/stunnel/stunnel.pem
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
socket = l:SO_KEEPALIVE=1
socket = r:SO_KEEPALIVE=1
TIMEOUTclose = 0
TIMEOUTconnect = 20
TIMEOUTidle = 28800

sslVersion = all
options = NO_SSLv2
options = NO_SSLv3
ciphers = HIGH:!aNULL:!MD5

[maximus-ssl]
client = no
accept = $SSL_PORT
connect = $CONNECT_TARGET
EOF

# 4. Iniciar Servicios
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null
[ ! -f /etc/default/stunnel4 ] && echo "ENABLED=1" > /etc/default/stunnel4
ufw allow $SSL_PORT/tcp 2>/dev/null
systemctl daemon-reload
systemctl enable --now stunnel4 > /dev/null 2>&1
systemctl restart stunnel4 > /dev/null 2>&1

echo "SUCCESS"
