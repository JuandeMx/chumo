#!/bin/bash
# ==============================================================================
#  GESTOR COMPLETO DE USUARIOS (SSH / SSL / OVPN / HYSTERIA) - ChumoGH Plus
# ==============================================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

USER_DB="/etc/adm-lite/users.db"
mkdir -p /etc/adm-lite
touch "$USER_DB"

ui_hr() { echo -e "${CYAN}=======================================================${NC}"; }
ui_subhr() { echo -e "${CYAN}-------------------------------------------------------${NC}"; }
ui_pause() { read -p " Presione Enter para regresar..." ; }

menu_usuarios() {
    while true; do
        clear
        ui_hr
        echo -e "${YELLOW}           CONTROL Y GESTION DE USUARIOS SSH / SSL / OVPN${NC}"
        ui_hr
        echo -e "  ${CYAN}[1] >${GREEN} CREAR USUARIO (VIP / Temporal / HWID)${NC}"
        echo -e "  ${CYAN}[2] >${RED} ELIMINAR USUARIO${NC}"
        echo -e "  ${CYAN}[3] >${WHITE} RENOVAR VENCIMIENTO / EXTENDER DIAS${NC}"
        echo -e "  ${CYAN}[4] >${YELLOW} CAMBIAR CONTRASEÑA DE USUARIO${NC}"
        echo -e "  ${CYAN}[5] >${WHITE} BLOQUEAR / DESBLOQUEAR USUARIO${NC}"
        ui_subhr
        echo -e "  ${CYAN}[6] >${GREEN} LISTAR Y DETALLES DE TODOS LOS USUARIOS${NC}"
        echo -e "  ${CYAN}[7] >${WHITE} MONITOR DE CONEXIONES EN TIEMPO REAL${NC}"
        echo -e "  ${CYAN}[8] >${RED} PURGAR Y LIMPIAR USUARIOS EXPIRADOS${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] > REGRESAR AL MENÚ PRINCIPAL${NC}"
        ui_hr
        echo -ne "${YELLOW} > Selecciona una opción : ${NC}"
        read opt_user

        case $opt_user in
            1)
                echo -e "\n${YELLOW} MODO DE CREACION DE USUARIO${NC}"
                echo -e "  ${CYAN}[1]${NC} Usuario VIP (Por Dias)"
                echo -e "  ${CYAN}[2]${NC} Usuario Temporal (Por Horas)"
                echo -e "  ${CYAN}[3]${NC} Usuario HWID (Bloqueo de Dispositivo)"
                read -p " Opción: " tipo
                
                read -p " Nombre del Usuario: " user
                [ -z "$user" ] && continue
                if grep -qw "^$user:" "$USER_DB" || id "$user" &>/dev/null; then
                    echo -e "${RED}[!] Error: El usuario $user ya existe en el sistema.${NC}"
                    sleep 2
                    continue
                fi

                read -p " Contrasena: " pass
                [ -z "$pass" ] && pass="1234"

                if [[ "$tipo" == "2" ]]; then
                    read -p " Horas de Duración [24]: " horas
                    [ -z "$horas" ] && horas=24
                    read -p " Limite de Conexiones [1]: " limit
                    [ -z "$limit" ] && limit=1
                    
                    exp_date=$(date -d "+$horas hours" +%Y-%m-%d)
                    linux_exp=$(date -d "+2 days" +%Y-%m-%d)
                    useradd -e $linux_exp -s /bin/false -M $user 2>/dev/null
                    echo "$user:$pass" | chpasswd
                    echo "$user:$pass:$exp_date:OFF:$limit" >> "$USER_DB"
                    echo -e "${GREEN}[OK] Usuario temporal $user creado por $horas horas.${NC}"
                    ui_pause
                elif [[ "$tipo" == "3" ]]; then
                    read -p " Hardware ID / Token del Cliente: " hwid_val
                    [ -z "$hwid_val" ] && hwid_val="OFF"
                    read -p " Dias de Duración [30]: " dias
                    [ -z "$dias" ] && dias=30
                    read -p " Limite de Conexiones [1]: " limit
                    [ -z "$limit" ] && limit=1

                    exp_date=$(date -d "+$dias days" +%Y-%m-%d)
                    linux_exp=$(date -d "+$((dias + 1)) days" +%Y-%m-%d)
                    useradd -e $linux_exp -s /bin/false -M $user 2>/dev/null
                    echo "$user:$pass" | chpasswd
                    echo "$user:$pass:$exp_date:$hwid_val:$limit" >> "$USER_DB"
                    echo -e "${GREEN}[OK] Usuario HWID $user creado por $dias dias (Token: $hwid_val).${NC}"
                    ui_pause
                else
                    read -p " Dias de Duración [30]: " dias
                    [ -z "$dias" ] && dias=30
                    read -p " Limite de Conexiones [1]: " limit
                    [ -z "$limit" ] && limit=1

                    exp_date=$(date -d "+$dias days" +%Y-%m-%d)
                    linux_exp=$(date -d "+$((dias + 1)) days" +%Y-%m-%d)
                    useradd -e $linux_exp -s /bin/false -M $user 2>/dev/null
                    echo "$user:$pass" | chpasswd
                    echo "$user:$pass:$exp_date:OFF:$limit" >> "$USER_DB"
                    echo -e "${GREEN}[OK] Usuario VIP $user creado por $dias dias.${NC}"
                    ui_pause
                fi
                ;;

            2)
                echo -e "\n${RED} ELIMINAR USUARIO${NC}"
                read -p " Nombre del Usuario a borrar: " user
                [ -z "$user" ] && continue
                
                userdel -f "$user" 2>/dev/null
                sed -i "/^$user:/d" "$USER_DB" 2>/dev/null
                echo -e "${GREEN}[OK] Usuario $user eliminado del sistema.${NC}"
                ui_pause
                ;;

            3)
                echo -e "\n${YELLOW} RENOVAR / EXTENDER USUARIO${NC}"
                read -p " Nombre del Usuario: " user
                [ -z "$user" ] && continue
                if ! grep -qw "^$user:" "$USER_DB"; then
                    echo -e "${RED}[!] Usuario no encontrado en la base de datos.${NC}"
                    sleep 2
                    continue
                fi

                read -p " Dias a Anadir [30]: " dias
                [ -z "$dias" ] && dias=30

                old_exp=$(grep -w "^$user" "$USER_DB" | cut -d: -f3)
                current_sec=$(date +%s)
                old_sec=$(date -d "$old_exp" +%s 2>/dev/null || echo 0)

                if [ "$old_sec" -gt "$current_sec" ]; then
                    new_exp=$(date -d "$old_exp + $dias days" +%Y-%m-%d)
                else
                    new_exp=$(date -d "+$dias days" +%Y-%m-%d)
                fi

                chage -E $new_exp $user 2>/dev/null
                sed -i "/^$user:/ s/:${old_exp}:/:${new_exp}:/" "$USER_DB"
                echo -e "${GREEN}[OK] Usuario $user renovado exitosamente hasta $new_exp.${NC}"
                ui_pause
                ;;

            4)
                echo -e "\n${YELLOW} CAMBIAR CONTRASEÑA${NC}"
                read -p " Nombre del Usuario: " user
                [ -z "$user" ] && continue
                read -p " Nueva Contrasena: " pass
                [ -z "$pass" ] && continue

                echo "$user:$pass" | chpasswd
                old_line=$(grep -w "^$user" "$USER_DB")
                if [ -n "$old_line" ]; then
                    old_pass=$(echo "$old_line" | cut -d: -f2)
                    sed -i "/^$user:/ s/:${old_pass}:/:${pass}:/" "$USER_DB"
                fi
                echo -e "${GREEN}[OK] Contrasena actualizada para $user.${NC}"
                ui_pause
                ;;

            5)
                echo -e "\n${YELLOW} BLOQUEAR / DESBLOQUEAR USUARIO${NC}"
                read -p " Nombre del Usuario: " user
                [ -z "$user" ] && continue

                if passwd -S "$user" 2>/dev/null | grep -q "L"; then
                    passwd -u "$user" 2>/dev/null
                    echo -e "${GREEN}[OK] Usuario $user DESBLOQUEADO.${NC}"
                else
                    passwd -l "$user" 2>/dev/null
                    echo -e "${RED}[OK] Usuario $user BLOQUEADO.${NC}"
                fi
                ui_pause
                ;;

            6)
                echo -e "\n${CYAN} DETALLES DE USUARIOS EN EL SISTEMA${NC}"
                ui_subhr
                printf "%-15s %-12s %-12s %-8s\n" "USUARIO" "PASSWORD" "EXPIRACION" "LIMITE"
                ui_subhr
                if [ -f "$USER_DB" ]; then
                    while IFS=: read -r u p e h l; do
                        [ -z "$u" ] && continue
                        printf "%-15s %-12s %-12s %-8s\n" "$u" "$p" "$e" "$l"
                    done < "$USER_DB"
                else
                    echo -e "${YELLOW}No hay usuarios registrados.${NC}"
                fi
                ui_subhr
                ui_pause
                ;;

            7)
                echo -e "\n${GREEN} MONITOR DE CONEXIONES ACTIVAS (SSH / PROXY)${NC}"
                ui_subhr
                netstat -tnpa 2>/dev/null | grep ESTABLISHED | grep -E 'sshd|python' | awk '{print $5, $7}'
                ui_subhr
                ui_pause
                ;;

            8)
                echo -e "\n${RED} LIMPIANDO USUARIOS EXPIRADOS...${NC}"
                today=$(date +%Y-%m-%d)
                today_sec=$(date +%s)
                
                if [ -f "$USER_DB" ]; then
                    while IFS=: read -r u p e h l; do
                        [ -z "$u" ] && continue
                        exp_sec=$(date -d "$e" +%s 2>/dev/null || echo 0)
                        if [ "$exp_sec" -gt 0 ] && [ "$today_sec" -gt "$exp_sec" ]; then
                            userdel -f "$u" 2>/dev/null
                            sed -i "/^$u:/d" "$USER_DB" 2>/dev/null
                            echo -e "${RED}[-] Usuario expirado eliminado: $u${NC}"
                        fi
                    done < "$USER_DB"
                fi
                echo -e "${GREEN}[OK] Limpieza completada.${NC}"
                ui_pause
                ;;

            0)
                break
                ;;

            *)
                echo -e "${RED}Opción inválida.${NC}"
                sleep 1
                ;;
        esac
    done
}

menu_usuarios
