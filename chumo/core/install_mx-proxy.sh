#!/bin/bash
# Instalador DinÃ¡mico Proxy Python

echo -e "\e[1;36m=========================================================\e[0m"
echo -e "\e[1;33m          INSTALADOR PROXY PYTHON (CLOUDFRONT)\e[0m"
echo -e "\e[1;36m=========================================================\e[0m"
proxy_port=$1
if [[ -z "$proxy_port" ]]; then
    read -p " Â¿En quÃ© puerto deseas instalar el Proxy Python? (ej: 80): " proxy_port
fi

if [[ -z "$proxy_port" ]]; then
    echo -e "\e[1;31mâŒ Cancelado. Puerto invÃ¡lido.\e[0m"
    sleep 2
    exit 1
fi

# Compatibilidad: si llega como rango (ej: 80-80), tomamos el primer puerto
proxy_port="${proxy_port%%-*}"

# ValidaciÃ³n estricta (el motor Python solo acepta un puerto numÃ©rico)
if ! [[ "$proxy_port" =~ ^[0-9]+$ ]]; then
    echo -e "\e[1;31mâŒ Puerto invÃ¡lido. Usa un nÃºmero (ej: 80).\e[0m"
    sleep 2
    exit 1
fi

if [ "$proxy_port" -lt 1 ] || [ "$proxy_port" -gt 65535 ]; then
    echo -e "\e[1;31mâŒ Puerto fuera de rango (1-65535).\e[0m"
    sleep 2
    exit 1
fi

echo -e "\n\e[1;32m[+] Limpiando puerto $proxy_port y configurando Proxy...\e[0m"
fuser -k "$proxy_port/tcp" 2>/dev/null

# Creamos el servicio systemd dinÃ¡micamente con el puerto
cat > /etc/systemd/system/mx-proxy.service << EOF
[Unit]
Description=ChumoGH Python Proxy Port $proxy_port
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/adm-lite/core
ExecStart=/usr/bin/python3 /etc/adm-lite/core/PDirect.py $proxy_port
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Abrir en el firewall
ufw allow ${proxy_port}/tcp 2>/dev/null

# Aplicar servicio
systemctl daemon-reload
systemctl enable --now mx-proxy 2>/dev/null
systemctl restart mx-proxy 2>/dev/null

echo -e "\e[1;32m[âœ“] Proxy Python instalado y activo en el puerto $proxy_port.\e[0m"
sleep 3
