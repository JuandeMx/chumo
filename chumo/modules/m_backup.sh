#!/bin/bash

[[ -e /bin/ejecutar/msg ]] && source /bin/ejecutar/msg || source <(curl -sSL https://raw.githubusercontent.com/ChumoGH/ADMcgh/main/Plugins/system/styles.cpp)



_Key='/etc/cghkey'

clear

[[ ! -e ${_Key} ]] && exit 

#Modificado el 06-04-2023

dir_user="/userDIR"
dir="/etc/adm-lite"

fun_ip () {
  if [[ -e /bin/ejecutar/IPcgh ]]; then
    IP="$(cat /bin/ejecutar/IPcgh)"
  else
    MEU_IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    MEU_IP2=$(wget -qO- ipv4.icanhazip.com)
    [[ "$MEU_IP" != "$MEU_IP2" ]] && IP="$MEU_IP2" && echo "$MEU_IP2" || IP="$MEU_IP" && echo "$MEU_IP"
    echo "$MEU_IP2" > /bin/ejecutar/IPcgh
	IP="$MEU_IP2"
  fi
local _netCAT="$(netstat -tunlp)"
_SFTP="$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND" | grep "LISTEN" | grep apache2)"
[[ -z ${_SFTP} ]] && _SFTP="$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND" | grep "LISTEN" | grep nginx)"
portFTP=$(echo -e "$_SFTP" |cut -d: -f2 | cut -d' ' -f1 | uniq)
[[ -z ${portFTP} ]] && portFTP='X0'
export portFTP=$(echo ${portFTP} | sed 's/\s\+/,/g' | cut -d , -f1)
}


removeonline(){
i=1
    [[ -d /var/www/html ]] && [[ -e /var/www/html/$arquivo_move ]] && rm -rf /var/www/html/$arquivo_move > /dev/null 2>&1
    [[ -e /var/www/$arquivo_move ]] && rm -rf /var/www/$arquivo_move > /dev/null 2>&1
    print_center -verd "${cor[5]}Extraxion Exitosa Exitosa"
    msg -bar3
	print_center -verd "SUBIENDO"
	subironline
}   
subironline(){
[ ! -d /var ] && mkdir /var
[ ! -d /var/www ] && mkdir /var/www
[ ! -d /var/www/html ] && mkdir /var/www/html
[ ! -e /var/www/html/index.html ] && touch /var/www/html/index.html
[ ! -e /var/www/index.html ] && touch /var/www/index.html
chmod -R 755 /var/www
cp $HOME/$arquivo_move /var/www/$arquivo_move
cp $HOME/$arquivo_move /var/www/html/$arquivo_move
cp $HOME/$arquivo_move /var/www/$arquivo_move.html
cp $HOME/$arquivo_move /var/www/html/$arquivo_move.html
service apache2 restart &>/dev/null
service nginx restart &>/dev/null
fun_ip
msg -bar3
print_center -verd "PARA RESTAURAR USA \n\n http://$IP:${portFTP}/$arquivo_move\n\n"
msg -bar3
print_center -verm2 "PARA VISUALIZAR EN LA WEB \n\n http://$IP:${portFTP}/$arquivo_move.html\n\n"
msg -bar3
print_center -verd "${cor[5]}Carga Exitosa!"
msg -bar3
read -p "PRESIONE ENTER PARA RETORNAR"
}
tittle
print_center -verm2 'ADVERTENCIA!!!\n RECUERDA QUE EL BACKUP DEBE SER ALMACENADO \n FUERA DEL VPS PARA EVITAR PERDIDAS \n UNA VEZ RESTAURADO EL SERVIDOR RECUPERA EL \n FICHERO, SEA ONLINE O LOCAL !'
msg -bar3
echo -e "\033[0;35m [${cor[2]}01\033[0;35m]\033[0;33m ${flech}${cor[3]} RESPALDAR USUARIOS   \033[0;31m[ $(msg -verm2 ' ONLINE') \033[0;31m]" 
echo -e "\033[0;35m [${cor[2]}02\033[0;35m]\033[0;33m ${flech}${cor[3]} RESTAURAR USUARIOS   \033[0;31m[ $(msg -verd ' ONLINE') \033[0;31m]" 
echo -e "\033[0;35m [${cor[2]}03\033[0;35m]\033[0;33m ${flech}${cor[3]} RESTAURAR USUARIOS   \033[0;31m[ $(msg -verd ' LOCAL') \033[0;31m]" 
msg -bar3
read -p "ECOJE: " option

function backup_de_usuarios(){
fun_ip
clear&&clear
msg -bar3
print_center -verd '  \e[97m\033[1;41m NOMBRE DE FICHERO WEB FILE\033[0m' 
msg -bar3
print_center -verm2 ' Este nombre sera el ARCHIVO FINAL \n PARA PODER SER RESTAURDO EN OTRO SERVIDOR \n Recuerda no colocar Espacios, ya que \n tambien sera el nombre del fichero WEB'
msg -bar3
print_center -verd ' NO SE RESPALDAN ** OPENVPN FILES **'
msg -bar3
echo -ne "[\033[1;31m${TTcent}\033[1;33m]\033[1;31m \033[1;33m"
echo -e "\033[1;33mINGRESA NOMBRE DEL FICHERO ( UsuarioXYZ ) "
msg -bar3
read -p " Ejemplo: ChumoGH : " name
[[ -z ${name} ]] && name='UsuarioXYZ'
bc="$HOME/$name"
arquivo_move="$name"
clear
i=1
[[ -e $bc ]] && rm $bc
echo -e "\033[1;37mHaciendo Backup de Usuarios...\033[0m"
msg -bar3
[[ -e /bin/ejecutar/token ]] && passTK=$(cat < /bin/ejecutar/token)
#for user in `awk -F : '$3 > 900 { print $1 }' /etc/passwd |grep -v "nobody" |grep -vi polkitd |grep -vi systemd-[a-z] |grep -vi systemd-[0-9] |sort`
for user in `cat "/etc/passwd"|grep 'home'|grep 'false'|grep -v 'syslog' | cut -d: -f1 |sort`
do
[[ -e $dir$dir_user/$user ]] && {
####################VALIDACION DE SCRIPT#####################
pass="$(cat $dir$dir_user/$user | grep "senha" | awk '{print $2}')"
limite=$(cat $dir$dir_user/$user | grep "limite" | awk '{print $2}')
[[ $limite = @(HWID|TOKEN) ]] && NameTKID=${pass} || NameTKID=${pass}
data=$(cat $dir$dir_user/$user | grep "data" | awk '{print $2}')
data_sec=$(date +%s)
data_user=$(chage -l "$user" |grep -i co |awk -F ":" '{print $2}')
data_user_sec=$(date +%s --date="$data_user")
variavel_soma=$(($data_user_sec - $data_sec))
dias_use=$(($variavel_soma / 86400))
if [[ "$dias_use" -le 0 ]]; 
then
dias_use=0
fi
sl=$((dias_use + 1))
i=$((i + 1))
[[ -z "$limite" ]] && limite="5"
echo -e "\033[1;31m [ SCRIPT ] \033[1;37m "
####################VALIDACION DE SCRIPT#####################
} || {
####################VALIDACION DE PASSWD#####################
linea=$(cat /etc/passwd | grep -w ${user})
limite="$(cat /etc/passwd | grep -w ${user} | awk -F ':' '{split($5, a, ","); print a[1]}')"
if [[ "${linea}" =~ ,([^:]+): ]]; then
        NameTKID="${BASH_REMATCH[1]}"
fi
[[ -z "$limite" ]] && limite="5"
data_sec=$(date +%s)
data_user=$(chage -l "$user" |grep -i co |awk -F ":" '{print $2}')
data_user_sec=$(date +%s --date="$data_user")
variavel_soma=$(($data_user_sec - $data_sec))
dias_use=$(($variavel_soma / 86400))
[[ "$dias_use" -le 0 ]] && dias_use=0
sl=$((dias_use + 1))
i=$((i + 1))
echo -e "\033[1;31m [ SYSTEM ] \033[1;37m"
#read -p "Introduzca la contraseña manualmente o pulse ENTER: " pass
#[[ -z "$pass" ]] && pass="$user"
####################VALIDACION DE PASSWD#####################
}
[[ $(echo $limite) = "HWID" ]] && echo "$user:$user:HWID:$sl:$NameTKID" >> $bc && echo -e "\033[1;37mUser $NameTKID \033[0;35m [\033[0;36m$limite\033[0;35m]\033[0;31m Backup [\033[1;31mOK\033[1;37m] con $sl DIAS\033[0m"
[[ $(echo $limite) = "TOKEN" ]] && echo "$user:$passTK:TOKEN:$sl:$NameTKID" >> $bc && echo -e "\033[1;37mUser $NameTKID \033[0;35m [\033[0;36m$limite\033[0;35m]\033[0;31m Backup [\033[1;31mOK\033[1;37m] con $sl DIAS\033[0m"
[[ "$limite" =~ ^[0-9]+$ ]] && echo "$user:$NameTKID:$limite:$sl:$NameTKID" >> $bc && echo -e "\033[1;37mUser $user \033[0;35m [\033[0;36mSSH\033[0;35m]\033[0;31m Backup [\033[1;31mOK\033[1;37m] con $sl DIAS\033[0m"
#sleep .2s
done
msg -bar3
echo -e "\033[1;31mBackup Completado !!!\033[0m"
echo " "
echo -e "\033[1;37mLos usuarios $i se encuentra en el archivo \033[1;31m $bc \033[1;37m"
}

extractor(){

echo hola

}


function restaurar_usuarios(){
cd $HOME
clear&&clear
msg -bar3
print_center -verd '  \e[97m\033[1;41m LINK DE FICHERO WEB FILE\033[0m' 
msg -bar3
print_center -verm2 ' AQUI VA EL ENLACE DEL FICHERO \n PARA PODER SER RESTAURDO PEGALO AQUI \n RECUERDA NO COLOCAR CARACTERES ESPECIALES'
msg -bar3
print_center -verd ' NO SE RESTAURAN ** OPENVPN FILES **'
msg -bar3
echo -ne "[\033[1;31m${TTcent}\033[1;33m]\033[1;31m \033[1;33m"
echo -ne "\033[1;33mINGRESA ENLACE DEL FICHERO "
read -p " : " url1
wget -q -O recovery $url1 && echo -e "\033[1;31m- \033[1;32mFile Exito!" || echo -e "\033[1;31m- \033[1;31mFile Fallo"
#echo -n "Escriba el directorio del archivo Backup: "
echo -e "\033[1;37mRestaurando Usuarios...\033[0m"
[[ -e $HOME/recovery ]] && arq="$HOME/recovery" || return 	
for user in `cat $arq`
do
USER=$(echo "$user" |awk -F : '{print $1}')
CLAVE=$(echo "$user" |awk -F : '{print $2}')
LIMITE=$(echo "$user" |awk -F : '{print $3}')
DIAS=$(echo "$user" |awk -F : '{print $4}')
NameTKID=$(echo "$user" |awk -F : '{print $5}')
valid=$(date '+%C%y-%m-%d' -d " +$DIAS days")
datexp=$(date "+%d/%m/%Y" -d " +$DIAS days")
if cat /etc/passwd |grep $USER: 1> /dev/null 2>/dev/null
then
echo -e "\033[1;37m\033[1;31m$USER \033[1;37mEXISTE: \033[1;31m${CLAVE}  [\033[1;31mFAILED\033[1;37m]\033[0m" > /dev/null
else
add_new_user "${USER}" "${CLAVE}" "${DIAS}" "${LIMITE}" n n "${NameTKID}"
	if [ $? = 1 ]; then
	  [[ ${LIMITE} = "HWID" ]] && {
	  echo "senha: $NameTKID" > /etc/adm-lite/userDIR/$USER
	  echo -e "\033[1;31m$NameTKID \033[1;37mRESTORE: \033[1;31m$LIMITE - \033[1;37m[\033[1;31mOk\033[1;37m] \033[1;37mcon\033[1;31m ${DIAS} \033[1;37m Dias\033[0m"
	  }
	  [[ ${LIMITE} = "TOKEN" ]] && {
	  echo "senha: $NameTKID" > /etc/adm-lite/userDIR/$USER
	  echo -e "\033[1;31m$NameTKID \033[1;37mRESTORE: \033[1;31m$LIMITE - \033[1;37m[\033[1;31mOk\033[1;37m] \033[1;37mcon\033[1;31m ${DIAS} \033[1;37m Dias\033[0m"
	  }
	  [[ ${LIMITE} =~ ^[0-9]+$ ]] && {
	  echo "senha: ${CLAVE}" > /etc/adm-lite/userDIR/$USER
	  echo -e "\033[1;31m$USER \033[1;37mRESTORE: \033[1;31m${CLAVE} - \033[1;37m[\033[1;31mOk\033[1;37m] \033[1;37mcon\033[1;31m ${DIAS} \033[1;37m Dias\033[0m"
	  }
	  echo "limite: $LIMITE" >> /etc/adm-lite/userDIR/$USER
	  echo "data: $valid" >> /etc/adm-lite/userDIR/$USER
	else
	  echo -e "\033[1;37m\033[1;31m$USER \033[1;37mESTADO  [\033[1;31mFAILED\033[1;37m]\033[0m" > /dev/null
	fi
fi
done
}

_resLOC () {

cd $HOME
echo "INGRESE LA RUTA LOCAL DONDE TIENES ALOJADO EL FICHERO " 
echo -e "  EJEMPLO : /root/file.txt "
read -p "Pega TU RUTA : " url1
[[ -e $url1 ]] && {
echo -e " FILE ENCONTRADO \n" 
arq="$url1"
} || {
echo -e " FILE NO FOUND \n"
return
}
#echo -n "Escriba el directorio del archivo Backup: "
echo -e "\033[1;37mRestaurando Usuarios de ... $arq\033[0m \n"
msg -bar3
i=1;
for user in `cat $arq`
do
USER=$(echo "$user" |awk -F : '{print $1}')
CLAVE=$(echo "$user" |awk -F : '{print $2}')
LIMITE=$(echo "$user" |awk -F : '{print $3}')
DIAS=$(echo "$user" |awk -F : '{print $4}')
NameTKID=$(echo "$user" |awk -F : '{print $5}')
valid=$(date '+%C%y-%m-%d' -d " +$DIAS days")
datexp=$(date "+%d/%m/%Y" -d " +$DIAS days")
if cat /etc/passwd |grep $USER: 1> /dev/null 2>/dev/null
then
echo -e "\033[1;37m\033[1;31m$USER \033[1;37mEXISTE: \033[1;31m${CLAVE}  [\033[1;31mFAILED\033[1;37m]\033[0m" > /dev/null
else
#add_new_user "${USER}" "${CLAVE}" "${DIAS}" "${LIMITE}" "${newfile}" "${ovpnauth}"
[[ -z ${CLAVE} ]] && CLAVE=$USER
add_new_user "${USER}" "${CLAVE}" "${DIAS}" "${LIMITE}" n n "${NameTKID}"
	if [ $? = 1 ]; then
	  [[ ${LIMITE} = "HWID" ]] && {
	  echo "senha: $NameTKID" > /etc/adm-lite/userDIR/$USER
	  echo -e "\033[1;31m$NameTKID \033[1;37mRESTORE: \033[1;31m$LIMITE - \033[1;37m[\033[1;31mOk\033[1;37m] \033[1;37mcon\033[1;31m ${DIAS} \033[1;37m Dias\033[0m"
	  }
	  [[ ${LIMITE} = "TOKEN" ]] && {
	  echo "senha: $NameTKID" > /etc/adm-lite/userDIR/$USER
	  echo -e "\033[1;31m$NameTKID \033[1;37mRESTORE: \033[1;31m$LIMITE - \033[1;37m[\033[1;31mOk\033[1;37m] \033[1;37mcon\033[1;31m ${DIAS} \033[1;37m Dias\033[0m"
	  }
	  [[ ${LIMITE} =~ ^[0-9]+$ ]] && {
	  echo "senha: ${CLAVE}" > /etc/adm-lite/userDIR/$USER
	  echo -e "\033[1;31m$USER \033[1;37mRESTORE: \033[1;31m${CLAVE} - \033[1;37m[\033[1;31mOk\033[1;37m] \033[1;37mcon\033[1;31m ${DIAS} \033[1;37m Dias\033[0m"
	  }
	  echo "limite: $LIMITE" >> /etc/adm-lite/userDIR/$USER
	  echo "data: $valid" >> /etc/adm-lite/userDIR/$USER
	else
	  echo -e "\033[1;37m\033[1;31m$USER \033[1;37mESTADO  [\033[1;31mFAILED\033[1;37m]\033[0m" > /dev/null
	fi
fi
i++;
done

}

if [ $option -eq 1 ]; then
backup_de_usuarios
msg -bar3
print_center -verm2 ' NOTA IMPORTANTE !!!\n RECUERDA RESPALDAR ESTE FICHERO!'
msg -bar3
print_center -verd ' Si esta usando maquina, Montalo Online\n Para luego usar el Link del Fichero, y puedas .\nDescargarlo desde cualquier sitio con acceso WEB\n  Ejemplo : http://ip-del-vps:portFTP/tu-fichero '
msg -bar3
read -p " PRESIONA ENTER PARA CARGAR ONLINE"
[[ -z $portFTP ]] && echo -e "SERVICIO FTP NO ACTIVO " || removeonline
fi

if [ $option -eq 2 ]; then
restaurar_usuarios
fi

if [ $option -eq 3 ]; then
_resLOC
fi

