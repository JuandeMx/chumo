#!/bin/bash
# Instalador DinÃ¡mico SlowDNS (DNSTT)

echo -e "\e[1;36m=========================================================\e[0m"
echo -e "\e[1;33m             INSTALADOR SLOWDNS (TÃºnel DNS)\e[0m"
echo -e "\e[1;36m=========================================================\e[0m"
read -p " Â¿En quÃ© puerto pÃºblico deseas recibir SlowDNS? (Tradicional: 53): " dns_port
if [[ -z "$dns_port" ]]; then dns_port=53; fi

read -p " Â¿Hacia quÃ© puerto local debe enviar los datos descubiertos? (ej: 22 ssh, 80 proxy): " fwd_port
if [[ -z "$fwd_port" ]]; then fwd_port=22; fi

read -p " Â¿QuÃ© dominio NS administrarÃ¡ la conexiÃ³n? (ej: slow.vpsmx.store): " ns_dom
if [[ -z "$ns_dom" ]]; then ns_dom="slow.vpsmx.store"; fi

echo -e "\n\e[1;32m[+] Compilando e Instalando SlowDNS ($dns_port -> $fwd_port)...\e[0m"

# Liberar el puerto 53 (Evitar choque con systemd-resolved)
if [[ "$dns_port" == "53" ]]; then
    echo -e "\e[1;33m    â†’ Liberando puerto 53 (Desactivando systemd-resolved)...\e[0m"
    systemctl stop systemd-resolved 2>/dev/null
    systemctl disable systemd-resolved 2>/dev/null
    rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
fi

# Instalar Go moderno (1.21.6) asegurando compilaciÃ³n correcta
if ! command -v go &>/dev/null || [[ $(go version | awk '{print $3}' | sed 's/go//;s/\..*//') -lt 1 || $(go version | awk '{print $3}' | awk -F'.' '{print $2}') -lt 18 ]]; then
    echo -e "\e[1;33m    â†’ Instalando compilador Go moderno (1.21.6)...\e[0m"
    cd /tmp
    wget -q https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
    rm -f go1.21.6.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    grep -q "/usr/local/go/bin" /etc/profile || echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
fi

echo -e "\e[1;33m    â†’ Instalando motor real DNSTT-Server desde fuente oficial...\e[0m"
rm -f /usr/local/bin/slowdns 2>/dev/null
rm -rf /tmp/dnstt-src
git clone https://www.bamsoftware.com/git/dnstt.git /tmp/dnstt-src 2>/dev/null || git clone https://github.com/www-dt/dnstt.git /tmp/dnstt-src 2>/dev/null
echo -e "\e[1;33m    â†’ Compilando motor...\e[0m"
cd /tmp/dnstt-src/dnstt-server
go build -o /usr/local/bin/slowdns 2>/dev/null
rm -rf /tmp/dnstt-src
chmod +x /usr/local/bin/slowdns 2>/dev/null

# Generar llaves Hexadecimales (x25519) reales para DNSTT
echo -e "\e[1;33m    â†’ Generando llaves criptogrÃ¡ficas x25519 (DNSTT Native)...\e[0m"
mkdir -p /etc/adm-lite/slowdns

if [ ! -f /etc/adm-lite/slowdns/server.key ]; then
    /usr/local/bin/slowdns -gen-key -privkey-file /etc/adm-lite/slowdns/server.key -pubkey-file /etc/adm-lite/slowdns/server.pub
fi

echo "$ns_dom" > /etc/adm-lite/slowdns/ns-domain.conf

# Crear servicio dinÃ¡mico
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
echo -e "\e[1;32m[âœ“] SlowDNS instalado y activo en puerto $dns_port.\e[0m"
echo -e "\e[1;36mâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•\e[0m"
echo -e "\e[1;33m ðŸ”‘ TU LLAVE PÃšBLICA (CÃ³piala a HTTP Custom / Injector):\e[0m"
if [ -f /etc/adm-lite/slowdns/server.pub ]; then
    echo -e "\e[1;37m    $(cat /etc/adm-lite/slowdns/server.pub)\e[0m"
else
    echo -e "\e[1;31m    Error: No se encontrÃ³ la llave.\e[0m"
fi
echo -e "\e[1;33m ðŸŒ DOMINIO NS:\e[0m"
echo -e "\e[1;37m    $ns_dom\e[0m"
echo -e "\e[1;36mâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•\e[0m"
sleep 5
