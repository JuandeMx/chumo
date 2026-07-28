#!/bin/bash
# ==============================================================================
#  GESTOR DE USUARIOS AUTÃ‰NTICO DE CHUMOGH PLUS (V3.9.9)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m[!] Acceso Denegado. Solo root puede usar ChumoGH Plus.\033[0m"
    exit 1
fi

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
source /bin/ejecutar/msg 2>/dev/null || source /etc/adm-lite/msg 2>/dev/null || source /etc/ADMcgh/msg 2>/dev/null

USER_DB="/etc/adm-lite/users.db"
mkdir -p /etc/adm-lite
touch "$USER_DB"

menu_usuarios() {
    while true; do
        clear
        msg -bar3
        echo -e "       \033[1;44;37m       ChumoGH  Plus      \033[0m"
        msg -bar3
        echo -e " \033[1;33m  CONTROL Y GESTION DE USUARIOS (SSH/SSL/OVPN)  \033[0m"
        msg -bar3
        echo -e " \033[1;37m[1] > CREAR USUARIO (VIP / TEMPORAL / HWID)\033[0m"
        echo -e " \033[1;37m[2] > ELIMINAR USUARIO\033[0m"
        echo -e " \033[1;37m[3] > RENOVAR USUARIO / EXTENDER DIAS\033[0m"
        echo -e " \033[1;37m[4] > CAMBIAR CONTRASEÃ‘A\033[0m"
        echo -e " \033[1;37m[5] > BLOQUEAR / DESBLOQUEAR USUARIO\033[0m"
        echo -e " \033[1;37m[6] > LISTAR DETALLES DE USUARIOS\033[0m"
        echo -e " \033[1;37m[7] > MONITOR DE CONEXIONES EN VIVO\033[0m"
        echo -e " \033[1;37m[8] > ELIMINAR USUARIOS VENCIDOS\033[0m"
        msg -bar3
        echo -e " \033[1;37m[0] > [ REGRESAR ]\033[0m"
        msg -bar3
        echo -ne "\033[1;37m > Opcion : \033[0m"
        read opt_user

        case $opt_user in
            1)
                echo -e "\n\033[1;33m MODO DE CREACION DE USUARIO\033[0m"
                echo -e "  \033[1;36m[1]\033[0m Usuario VIP (Por Dias)"
                echo -e "  \033[1;36m[2]\033[0m Usuario Temporal (Por Horas)"
                echo -e "  \033[1;36m[3]\033[0m Usuario HWID (Token / App)"
                echo -ne "\033[1;37m > Selecciona tipo : \033[0m"
                read tipo
                
                echo -ne "\033[1;37m Nombre del Usuario: \033[0m"
                read user
                [ -z "$user" ] && continue
                if grep -qw "^$user:" "$USER_DB" || id "$user" &>/dev/null; then
                    echo -e "\033[1;31m[!] Error: El usuario $user ya existe.\033[0m"
                    sleep 2
                    continue
                fi

                echo -ne "\033[1;37m Contrasena: \033[0m"
                read pass
                [ -z "$pass" ] && pass="1234"

                if [[ "$tipo" == "2" ]]; then
                    echo -ne "\033[1;37m Horas de Duracion [24]: \033[0m"
                    read horas
                    [ -z "$horas" ] && horas=24
                    echo -ne "\033[1;37m Limite de Conexiones [1]: \033[0m"
                    read limit
                    [ -z "$limit" ] && limit=1
                    
                    exp_date=$(date -d "+$horas hours" +%Y-%m-%d)
                    linux_exp=$(date -d "+2 days" +%Y-%m-%d)
                    useradd -e $linux_exp -s /bin/false -M $user 2>/dev/null
                    echo "$user:$pass" | chpasswd
                    echo "$user:$pass:$exp_date:OFF:$limit" >> "$USER_DB"
                    echo -e "\033[1;32m[OK] Usuario temporal $user creado por $horas horas.\033[0m"
                    read -p " Presione Enter para continuar..."
                elif [[ "$tipo" == "3" ]]; then
                    echo -ne "\033[1;37m HWID / Token: \033[0m"
                    read hwid_val
                    [ -z "$hwid_val" ] && hwid_val="OFF"
                    echo -ne "\033[1;37m Dias de Duracion [30]: \033[0m"
                    read dias
                    [ -z "$dias" ] && dias=30
                    echo -ne "\033[1;37m Limite de Conexiones [1]: \033[0m"
                    read limit
                    [ -z "$limit" ] && limit=1

                    exp_date=$(date -d "+$dias days" +%Y-%m-%d)
                    linux_exp=$(date -d "+$((dias + 1)) days" +%Y-%m-%d)
                    useradd -e $linux_exp -s /bin/false -M $user 2>/dev/null
                    echo "$user:$pass" | chpasswd
                    echo "$user:$pass:$exp_date:$hwid_val:$limit" >> "$USER_DB"
                    echo -e "\033[1;32m[OK] Usuario HWID $user creado por $dias dias.\033[0m"
                    read -p " Presione Enter para continuar..."
                else
                    echo -ne "\033[1;37m Dias de Duracion [30]: \033[0m"
                    read dias
                    [ -z "$dias" ] && dias=30
                    echo -ne "\033[1;37m Limite de Conexiones [1]: \033[0m"
                    read limit
                    [ -z "$limit" ] && limit=1

                    exp_date=$(date -d "+$dias days" +%Y-%m-%d)
                    linux_exp=$(date -d "+$((dias + 1)) days" +%Y-%m-%d)
                    useradd -e $linux_exp -s /bin/false -M $user 2>/dev/null
                    echo "$user:$pass" | chpasswd
                    echo "$user:$pass:$exp_date:OFF:$limit" >> "$USER_DB"
                    echo -e "\033[1;32m[OK] Usuario VIP $user creado por $dias dias.\033[0m"
                    read -p " Presione Enter para continuar..."
                fi
                ;;

            2)
                echo -e "\n\033[1;31m ELIMINAR USUARIO\033[0m"
                echo -ne "\033[1;37m Nombre del Usuario a borrar: \033[0m"
                read user
                [ -z "$user" ] && continue
                
                userdel -f "$user" 2>/dev/null
                sed -i "/^$user:/d" "$USER_DB" 2>/dev/null
                echo -e "\033[1;32m[OK] Usuario $user eliminado del sistema.\033[0m"
                read -p " Presione Enter para continuar..."
                ;;

            3)
                echo -e "\n\033[1;33m RENOVAR USUARIO\033[0m"
                echo -ne "\033[1;37m Nombre del Usuario: \033[0m"
                read user
                [ -z "$user" ] && continue
                if ! grep -qw "^$user:" "$USER_DB"; then
                    echo -e "\033[1;31m[!] Usuario no encontrado.\033[0m"
                    sleep 2
                    continue
                fi

                echo -ne "\033[1;37m Dias a Anadir [30]: \033[0m"
                read dias
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
                echo -e "\033[1;32m[OK] Usuario $user renovado hasta $new_exp.\033[0m"
                read -p " Presione Enter para continuar..."
                ;;

            4)
                echo -e "\n\033[1;33m CAMBIAR CONTRASEÃ‘A\033[0m"
                echo -ne "\033[1;37m Nombre del Usuario: \033[0m"
                read user
                [ -z "$user" ] && continue
                echo -ne "\033[1;37m Nueva Contrasena: \033[0m"
                read pass
                [ -z "$pass" ] && continue

                echo "$user:$pass" | chpasswd
                old_line=$(grep -w "^$user" "$USER_DB")
                if [ -n "$old_line" ]; then
                    old_pass=$(echo "$old_line" | cut -d: -f2)
                    sed -i "/^$user:/ s/:${old_pass}:/:${pass}:/" "$USER_DB"
                fi
                echo -e "\033[1;32m[OK] Contrasena actualizada para $user.\033[0m"
                read -p " Presione Enter para continuar..."
                ;;

            5)
                echo -e "\n\033[1;33m BLOQUEAR / DESBLOQUEAR USUARIO\033[0m"
                echo -ne "\033[1;37m Nombre del Usuario: \033[0m"
                read user
                [ -z "$user" ] && continue

                if passwd -S "$user" 2>/dev/null | grep -q "L"; then
                    passwd -u "$user" 2>/dev/null
                    echo -e "\033[1;32m[OK] Usuario $user DESBLOQUEADO.\033[0m"
                else
                    passwd -l "$user" 2>/dev/null
                    echo -e "\033[1;31m[OK] Usuario $user BLOQUEADO.\033[0m"
                fi
                read -p " Presione Enter para continuar..."
                ;;

            6)
                echo -e "\n\033[1;36m DETALLES DE USUARIOS EN EL SISTEMA\033[0m"
                msg -bar3
                printf "\033[1;37m%-15s %-12s %-12s %-8s\033[0m\n" "USUARIO" "PASSWORD" "EXPIRACION" "LIMITE"
                msg -bar3
                if [ -f "$USER_DB" ]; then
                    while IFS=: read -r u p e h l; do
                        [ -z "$u" ] && continue
                        printf "%-15s %-12s %-12s %-8s\n" "$u" "$p" "$e" "$l"
                    done < "$USER_DB"
                else
                    echo -e "\033[1;33mNo hay usuarios registrados.\033[0m"
                fi
                msg -bar3
                read -p " Presione Enter para continuar..."
                ;;

            7)
                echo -e "\n\033[1;32m MONITOR DE CONEXIONES ACTIVAS\033[0m"
                msg -bar3
                netstat -tnpa 2>/dev/null | grep ESTABLISHED | grep -E 'sshd|python' | awk '{print $5, $7}'
                msg -bar3
                read -p " Presione Enter para continuar..."
                ;;

            8)
                echo -e "\n\033[1;31m LIMPIANDO USUARIOS EXPIRADOS...\033[0m"
                today_sec=$(date +%s)
                
                if [ -f "$USER_DB" ]; then
                    while IFS=: read -r u p e h l; do
                        [ -z "$u" ] && continue
                        exp_sec=$(date -d "$e" +%s 2>/dev/null || echo 0)
                        if [ "$exp_sec" -gt 0 ] && [ "$today_sec" -gt "$exp_sec" ]; then
                            userdel -f "$u" 2>/dev/null
                            sed -i "/^$u:/d" "$USER_DB" 2>/dev/null
                            echo -e "\033[1;31m[-] Usuario expirado eliminado: $u\033[0m"
                        fi
                    done < "$USER_DB"
                fi
                echo -e "\033[1;32m[OK] Limpieza completada.\033[0m"
                read -p " Presione Enter para continuar..."
                ;;

            0)
                break
                ;;

            *)
                echo -e "\033[1;31mOpciÃ³n invÃ¡lida.\033[0m"
                sleep 1
                ;;
        esac
    done
}

menu_usuarios