#!/bin/bash
# ChumoGH - Cloudflare Dynamic DNS Updater (Multi-Subdominio)
# Comprueba la IP pÃºblica cada 5 min y actualiza registros A en Cloudflare

CONFIG_FILE="/etc/adm-lite/cloudflare.conf"
LOG_FILE="/var/log/ChumoGH/cloudflare-ddns.log"
IP_FILE="/etc/adm-lite/.last_ip"

mkdir -p "$(dirname "$LOG_FILE")"

# Colores para consola interactiva
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# FunciÃ³n de log dual (Archivo + Consola interactiva si corresponde)
log_msg() {
    local TYPE="$1"
    local MSG="$2"
    echo "[$(date)] [$TYPE] $MSG" >> "$LOG_FILE"
    
    # Si la salida es una terminal (interactivo), imprimir formateado con colores
    if [ -t 1 ]; then
        case "$TYPE" in
            "INFO") echo -e "${CYAN}[INFO]${NC} $MSG" ;;
            "OK") echo -e "${GREEN}[OK]${NC} $MSG" ;;
            "WARN") echo -e "${YELLOW}[WARN]${NC} $MSG" ;;
            "ERROR") echo -e "${RED}[ERROR]${NC} $MSG" ;;
            *) echo -e "$MSG" ;;
        esac
    fi
}

# Cargar configuraciÃ³n
if [ ! -f "$CONFIG_FILE" ]; then
    log_msg "ERROR" "No existe el archivo de configuraciÃ³n: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ]; then
    log_msg "ERROR" "Faltan Token o ZoneID en $CONFIG_FILE"
    exit 1
fi

# Obtener IP pÃºblica actual del VPS
IP_ACTUAL=$(curl -s --max-time 10 https://api.ipify.org)
[ -z "$IP_ACTUAL" ] && IP_ACTUAL=$(curl -s --max-time 10 https://ipv4.icanhazip.com)
if [ -z "$IP_ACTUAL" ]; then
    log_msg "ERROR" "No se pudo obtener la IP pÃºblica actual del VPS."
    exit 1
fi

# Leer la IP anterior guardada localmente
IP_ANTERIOR=""
[ -f "$IP_FILE" ] && IP_ANTERIOR=$(cat "$IP_FILE")

# Si la IP no cambiÃ³ fÃ­sicamente, y no se borrÃ³ el cachÃ© manualmente, salir
if [ "$IP_ACTUAL" == "$IP_ANTERIOR" ] && [ -f "$IP_FILE" ]; then
    log_msg "INFO" "La IP pÃºblica del VPS no ha cambiado ($IP_ACTUAL). Saliendo."
    exit 0
fi

log_msg "INFO" "Verificando/Actualizando registros en Cloudflare. IP anterior: '$IP_ANTERIOR' â†’ IP actual: '$IP_ACTUAL'"

# Obtener registros tipo A de la zona
ALL_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&per_page=100" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

SUCCESS=$(echo "$ALL_RECORDS" | jq -r '.success' 2>/dev/null)
if [ "$SUCCESS" != "true" ]; then
    log_msg "ERROR" "La consulta de la API de Cloudflare fallÃ³. Verifica tus credenciales (Token/ZoneID)."
    if [ -t 1 ]; then
        echo -e "${RED}Detalle del error:${NC} $ALL_RECORDS"
    fi
    exit 1
fi

# Contar cuÃ¡ntos registros A hay
TOTAL=$(echo "$ALL_RECORDS" | jq '.result | length' 2>/dev/null)
if [ -z "$TOTAL" ] || [ "$TOTAL" -eq 0 ]; then
    log_msg "WARN" "No se encontraron registros tipo A en esta Zona de Cloudflare."
    exit 0
fi

UPDATED=0

# Recorrer registros A
for i in $(seq 0 $(($TOTAL - 1))); do
    RECORD_ID=$(echo "$ALL_RECORDS" | jq -r ".result[$i].id")
    RECORD_NAME=$(echo "$ALL_RECORDS" | jq -r ".result[$i].name")
    RECORD_IP=$(echo "$ALL_RECORDS" | jq -r ".result[$i].content")
    RECORD_PROXIED=$(echo "$ALL_RECORDS" | jq -r ".result[$i].proxied")

    DEBE_ACTUALIZAR=false
    if [ -n "$CF_RECORD_NAME" ]; then
        # Caso 1: Se configurÃ³ un dominio especÃ­fico. Lo actualizamos si el nombre coincide y la IP es distinta.
        if [ "$RECORD_NAME" == "$CF_RECORD_NAME" ]; then
            if [ "$RECORD_IP" != "$IP_ACTUAL" ]; then
                DEBE_ACTUALIZAR=true
            else
                log_msg "INFO" "El registro '$RECORD_NAME' ya apunta correctamente a la IP actual ($IP_ACTUAL)."
            fi
        fi
    else
        # Caso 2: No se configurÃ³ dominio especÃ­fico. Actualiza los registros que apunten a la IP anterior del VPS.
        if [ "$RECORD_IP" == "$IP_ANTERIOR" ] || [ -z "$IP_ANTERIOR" ]; then
            if [ "$RECORD_IP" != "$IP_ACTUAL" ]; then
                DEBE_ACTUALIZAR=true
            fi
        fi
    fi

    if [ "$DEBE_ACTUALIZAR" == "true" ]; then
        log_msg "INFO" "Actualizando '$RECORD_NAME' de '$RECORD_IP' a '$IP_ACTUAL'..."
        
        UPDATE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$IP_ACTUAL\",\"ttl\":120,\"proxied\":$RECORD_PROXIED}")

        UPD_OK=$(echo "$UPDATE" | jq -r '.success' 2>/dev/null)
        if [ "$UPD_OK" == "true" ]; then
            log_msg "OK" "Registro '$RECORD_NAME' actualizado con Ã©xito a '$IP_ACTUAL'."
            UPDATED=$(($UPDATED + 1))
        else
            log_msg "ERROR" "Error al actualizar registro '$RECORD_NAME': $UPDATE"
        fi
    fi
done

# Guardar la IP actual como referencia local de cachÃ©
echo "$IP_ACTUAL" > "$IP_FILE"

log_msg "OK" "SincronizaciÃ³n completada. Se actualizaron $UPDATED de $TOTAL registros tipo A."
