#!/bin/bash

echo -e "\e[1;32m[+] Configurando la API de WhatsApp para ChumoGH...\e[0m"

# Dar permisos de ejecucion
chmod +x /etc/adm-lite/core/api_whatsapp.py

# Crear el servicio de systemd
cat > /etc/systemd/system/maximus-api.service << 'EOF'
[Unit]
Description=Maximus WhatsApp API Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /etc/adm-lite/core/api_whatsapp.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Recargar e iniciar
systemctl daemon-reload
systemctl enable maximus-api
systemctl restart maximus-api

# Abrir el puerto 8085 en el firewall
echo -e "\e[1;32m[+] Abriendo el puerto 8085 para la API...\e[0m"
ufw allow 8085/tcp >/dev/null 2>&1

echo -e "\e[1;36m=========================================================\e[0m"
echo -e "\e[1;32m   [âœ…] API INSTALADA Y CORRIENDO EN EL PUERTO 8085    \e[0m"
echo -e "\e[1;36m=========================================================\e[0m"
