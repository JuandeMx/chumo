#!/bin/bash
# ==============================================================================
#  DESOFUSCADOR Y EXTRACTOR SIN KEY - ADMcgh / CGH V3.9.9
# ==============================================================================

DIR_ACTUAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVO_ENTRADA="$DIR_ACTUAL/setup_ofuscado.sh"
ARCHIVO_SALIDA="$DIR_ACTUAL/setup_descriptado_sin_key.sh"

echo "=========================================================="
echo " 🔓 EXTRAYENDO CÓDIGO FUENTE DE SETUP SIN VALIDAR KEY"
echo "=========================================================="

if [ ! -f "$ARCHIVO_ENTRADA" ]; then
    echo "[+] Descargando instalador directamente desde servidor remoto..."
    curl -sL "https://plus.ltmcgh.site/main/setup" -o "$ARCHIVO_ENTRADA"
fi

echo "[+] Procesando archivo ofuscado ($(wc -c < "$ARCHIVO_ENTRADA") bytes)..."

# Interceptamos la ejecución para evitar que contacte a @GEN_KEY_CGH_BOT
sed -e 's/eval /echo /g' \
    -e 's/\. <(/cat <(/g' \
    -e 's/bash -c/echo -c/g' \
    "$ARCHIVO_ENTRADA" > "$DIR_ACTUAL/setup_hooked.tmp"

chmod +x "$DIR_ACTUAL/setup_hooked.tmp"

echo "[+] Decodificando matriz de variables de memoria..."
bash "$DIR_ACTUAL/setup_hooked.tmp" > "$ARCHIVO_SALIDA" 2>/dev/null

# Limpiamos archivo temporal
rm -f "$DIR_ACTUAL/setup_hooked.tmp"

if [ -s "$ARCHIVO_SALIDA" ]; then
    echo "[+] Extracción exitosa!"
    echo "[+] Código fuente desofuscado guardado en:"
    echo "    $ARCHIVO_SALIDA"
else
    echo "[!] Utilizando traza profunda de variables..."
    PS4='+ ' bash -x "$DIR_ACTUAL/setup_ofuscado.sh" 2> "$DIR_ACTUAL/trace.log"
    grep -v '^+ ____=' "$DIR_ACTUAL/trace.log" | grep -v '^+ _______\[' | grep '^+ ' | sed 's/^+ //' > "$ARCHIVO_SALIDA"
    echo "[+] Traza completada y guardada en $ARCHIVO_SALIDA"
fi

echo "=========================================================="
echo " ✅ LISTO: Puedes inspeccionar y modificar $ARCHIVO_SALIDA"
echo "=========================================================="
