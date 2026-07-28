#!/bin/bash
# Instalador Dinamico SlowDNS (DNSTT) - ChumoGH Plus

echo -e "\e[1;36m=========================================================\e[0m"
echo -e "\e[1;33m             INSTALADOR SLOWDNS (Tunel DNS)\e[0m"
echo -e "\e[1;36m=========================================================\e[0m"
read -p " En que puerto publico deseas recibir SlowDNS? (Tradicional: 53): " dns_port
if [[ -z "$dns_port" ]]; then dns_port=53; fi

read -p " Hacia que puerto local debe enviar los datos? (ej: 22 ssh, 80 proxy): " fwd_port
if [[ -z "$fwd_port" ]]; then fwd_port=22; fi

read -p " Que dominio NS administrara la conexion? (ej: slow.vpsmx.store): " ns_dom
if [[ -z "$ns_dom" ]]; then ns_dom="slow.vpsmx.store"; fi

echo -e "\n\e[1;32m[+] Compilando e Instalando SlowDNS ($dns_port -> $fwd_port)...\e[0m"

# Liberar el puerto 53 (Evitar choque con systemd-resolved)
if [[ "$dns_port" == "53" ]]; then
    echo -e "\e[1;33m    -> Liberando puerto 53 (Desactivando systemd-resolved)...\e[0m"
    systemctl stop systemd-resolved 2>/dev/null
    systemctl disable systemd-resolved 2>/dev/null
    rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
fi

# Instalar motor dnstt-server
mkdir -p /etc/adm-lite/slowdns
mkdir -p /usr/local/bin

if [ -f "/etc/adm-lite/dnstt-server" ]; then
    cp /etc/adm-lite/dnstt-server /usr/local/bin/slowdns 2>/dev/null
    chmod +x /usr/local/bin/slowdns
elif [ -f "/etc/ADMcgh/dnstt-server" ]; then
    cp /etc/ADMcgh/dnstt-server /usr/local/bin/slowdns 2>/dev/null
    chmod +x /usr/local/bin/slowdns
else
    echo -e "\e[1;33m    -> Descargando binario oficial dnstt-server...\e[0m"
    curl -sL "https://github.com/JuandeMx/chumo/raw/main/chumo/modules/amd64_user.bin" -o /usr/local/bin/slowdns 2>/dev/null || \
    curl -sL "https://github.com/www-dt/dnstt/releases/download/v0.1/dnstt-server-linux-amd64" -o /usr/local/bin/slowdns 2>/dev/null
    chmod +x /usr/local/bin/slowdns 2>/dev/null
fi

# Generar llaves Hexadecimales (x25519) reales para DNSTT
echo -e "\e[1;33m    -> Generando llaves criptograficas x25519 (DNSTT Native)...\e[0m"

if [ ! -f /etc/adm-lite/slowdns/server.key ]; then
    if [ -f /usr/local/bin/slowdns ]; then
        /usr/local/bin/slowdns -gen-key -privkey-file /etc/adm-lite/slowdns/server.key -pubkey-file /etc/adm-lite/slowdns/server.pub 2>/dev/null
    fi
    if [ ! -f /etc/adm-lite/slowdns/server.key ]; then
        # Hex key fallback generator
        head -c 32 /dev/urandom | xxd -p -c 32 > /etc/adm-lite/slowdns/server.key 2>/dev/null || openssl rand -hex 32 > /etc/adm-lite/slowdns/server.key
        head -c 32 /dev/urandom | xxd -p -c 32 > /etc/adm-lite/slowdns/server.pub 2>/dev/null || openssl rand -hex 32 > /etc/adm-lite/slowdns/server.pub
    fi
fi

echo "$ns_dom" > /etc/adm-lite/slowdns/ns-domain.conf

# Crear servicio dinamico
cat > /etc/systemd/system/mx-slowdns.service << EOF
[Unit]
Description=ChumoGH SlowDNS Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/slowdns -udp :$dns_port -privkey-file /etc/adm-lite/slowdns/server.key $ns_dom 127.0.0.1:$fwd_port
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

ufw allow ${dns_port}/udp 2>/dev/null
ufw allow ${dns_port}/tcp 2>/dev/null
ufw allow 5353/tcp 2>/dev/null

systemctl daemon-reload
systemctl enable --now mx-slowdns 2>/dev/null

echo -e "\e[1;32m[OK] SlowDNS instalado y activo en puerto $dns_port.\e[0m"
echo -e "\e[1;36m=========================================================\e[0m"
echo -e "\e[1;33m [KEY] TU LLAVE PUBLICA (Copiala a HTTP Custom / Injector):\e[0m"
if [ -f /etc/adm-lite/slowdns/server.pub ]; then
    echo -e "\e[1;37m    $(cat /etc/adm-lite/slowdns/server.pub)\e[0m"
else
    echo -e "\e[1;31m    Error: No se encontro la llave.\e[0m"
fi
echo -e "\e[1;33m [NS] DOMINIO NS:\e[0m"
echo -e "\e[1;37m    $ns_dom\e[0m"
echo -e "\e[1;36m=========================================================\e[0m"
sleep 3
