#!/bin/bash
# ==============================================================================
#  GESTOR AUTÉNTICO DE V2RAY / XRAY / X-UI - ChumoGH Plus v3.9.9
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m[!] Acceso Denegado. Solo root puede ejecutar ChumoGH V2Ray.\033[0m"
    exit 1
fi

source /bin/ejecutar/msg 2>/dev/null || source /etc/adm-lite/msg 2>/dev/null || source /etc/ADMcgh/msg 2>/dev/null

v2ray_cli_menu() {
    if [ -f /etc/adm-lite/v2r.bin ]; then
        /etc/adm-lite/v2r.bin
    elif [ -f /etc/adm-lite/xr.bin ]; then
        /etc/adm-lite/xr.bin
    else
        bash /etc/adm-lite/install_xui.sh
    fi
}

menu_v2ray_main() {
    while true; do
        clear
        msg -bar3
        echo -e "       \033[1;44;37m       ChumoGH  Plus      \033[0m"
        msg -bar3
        echo -e " \033[1;33m  GESTION Y CONTROL DE V2RAY / XRAY / X-UI  \033[0m"
        msg -bar3
        echo -e " \033[1;37m[1] > ADMINISTRADOR V2RAY CLI (NATIVO CHUMO)\033[0m"
        echo -e " \033[1;37m[2] > INSTALAR / GESTIONAR PANEL WEB X-UI\033[0m"
        echo -e " \033[1;37m[3] > REINICIAR SERVICIO V2RAY / XRAY\033[0m"
        echo -e " \033[1;37m[4] > ESTADO Y PUERTOS V2RAY\033[0m"
        msg -bar3
        echo -e " \033[1;37m[0] > [ REGRESAR ]\033[0m"
        msg -bar3
        echo -ne "\033[1;37m > Opcion : \033[0m"
        read opt_v2r

        case $opt_v2r in
            1)
                v2ray_cli_menu
                ;;
            2)
                bash /etc/adm-lite/install_xui.sh
                ;;
            3)
                systemctl restart v2ray 2>/dev/null || systemctl restart xray 2>/dev/null || systemctl restart x-ui 2>/dev/null
                echo -e "\033[1;32m[OK] Servicios V2Ray / Xray reiniciados.\033[0m"
                sleep 2
                ;;
            4)
                echo -e "\033[1;36mPuertos V2Ray / Xray activos:\033[0m"
                netstat -tlpn 2>/dev/null | grep -E 'v2ray|xray|x-ui'
                read -p " Presione Enter para regresar..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "\033[1;31mOpción inválida.\033[0m"
                sleep 1
                ;;
        esac
    done
}

menu_v2ray_main
