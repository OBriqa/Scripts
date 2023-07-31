#!/bin/bash

# SEAX 2022-23 Q2
# OMAR BRIQA            
# ALEX PASCUAL BATET

HELP="
    info_inet.sh    | Script que analitza i mostra dades sobre les diferents interfícies de xarxa del sistema.
                    | El resultat de l'analisis s'emmagatzema al fitxer 'log_inet.log'
        
    DEPENDENCIES    | ipcalc, whois, dig, traceroute, curl
                    | arxiu relació MAC - FABRICANT             -> https://standards-oui.ieee.org/oui/oui.txt
                    | utilities.sh                              -> funcions auxiliars

    USAGE           | possibles execucions:
                            -> ./info_inet.sh                   -> execució per defecte
                            -> ./info_inet.sh -h, --help        -> mostra ajuda
"

USAGE="USAGE | possibles execucions: 
        ./info_inet.sh
        ./info_inet.sh -h, --help"
VERSIO="1.1.15"
LAST_DATE="07/03/2023"

if [[ $# -ge 2 ]]; then
    echo "$USAGE"
    exit 1
fi 

if [[ $# -eq 1 ]]; then
    if [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "$HELP"
    else
        echo "$USAGE"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------

NOCOLOR='\033[0m'
GROC='\033[1;93m'
VERD='\033[1;92m'
VERMELL='\033[1;91m'

# ---------------------------------------------------------------------------------------------------------

if [ $(id $(whoami) --user) -ne 0 ]; then
    echo -e "${VERMELL}Has de ser usuari root per executar aquest script.${NOCOLOR}" 
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------

echo "Per executar el script 'info_inet.sh' necessitem aquestes aplicacions: [ipcalc, whois]"
echo -e "També necessitem descarregar una base de dades amb informació necessaria pel funcionmanent del script.\n"

echo -e "En cas de no disposar-les, vols que s'instalin? [${VERD}Sí${NOCOLOR} -> Prem ${VERD}1${NOCOLOR} | ${VERMELL}No${NOCOLOR} -> Prem ${VERMELL}0${NOCOLOR}]"
read input

if [[ $input -eq "1" ]]; then

    if [[ -z $(dpkg -l | grep ipcalc) ]]; then
        echo -ne "${GROC}[EN PROCES]${NOCOLOR} Instal·lació de dependències... [ipcalc]\r"
        apt-get install ipcalc > /dev/null
        echo -e "${VERD}[FINALITZAT]${NOCOLOR} Instal·lació de dependències... [ipcalc]"
    else
        echo -e "${VERD}[COMPROVAT]${NOCOLOR} L'aplicació [ipcalc] ja està instalada!"
    fi

    if [[ -z $(dpkg -l | grep whois) ]]; then
        echo -ne "${GROC}[EN PROCES]${NOCOLOR} Instal·lació de dependències... [whois]\r"
        apt-get install whois > /dev/null
        echo -e "${VERD}[FINALITZAT]${NOCOLOR} Instal·lació de dependències... [whois]"
    else
        echo -e "${VERD}[COMPROVAT]${NOCOLOR} L'aplicació [whois] ja està instalada!"
    fi

    if [ ! -f "MAC_info.info" ]; then
        echo -ne "${GROC}[EN PROCES]${NOCOLOR} Descarregant base de dades de OUI-IEEE...\r"
        wget -q https://standards-oui.ieee.org/oui/oui.txt -O MAC_info.info
        echo -e "${VERD}[FINALITZAT]${NOCOLOR} Descarregant base de dades de OUI-IEEE d'informació sobre adreçes MAC..."
    else
        echo -e "${VERD}[COMPROVAT]${NOCOLOR} La base de dades de OUI-IEE amb informació sobre adreçes MAC ja està descarregada!"
    fi

else
    echo -e "${VERMELL}Sense aquestes aplicacions no es pot executar el script.${NOCOLOR}"
    exit 0
fi

source utilities.sh
rm info_inet.log log_inet.log &> /dev/null && touch log_inet.log

echo
# ---------------------------------------------------------------------------------------------------------

DATA_INI=$(date +'%d/%m/%Y')
HORA_INI=$(date +'%T')
ROUT="router.lan"
USUARI=$(whoami)
NOM_EQUIP=$(cat /etc/hostname)
NOM_SO=$(cat /etc/*-release | grep PRETTY_NAME | cut -d'=' -f2 | sed 's/"//g')

# ---------------------------------------------------------------------------------------------------------

iterator=1
interficie=$(ip link | grep "^$iterator: ")
while [ ! -z "$interficie" ]
do

    NOM_INTERFICIE=$(ip link | grep "^$iterator: "| cut -d: -f2 | sed 's/ //g')
    NOM_ORIGINAL_INTERFICIE=$(udevadm info /sys/class/net/$NOM_INTERFICIE | grep ID_NET_NAME_PATH | cut -d'=' -f2)
    if [ -z "$NOM_ORIGINAL_INTERFICIE" ]; then
        NOM_ORIGINAL_INTERFICIE=$NOM_INTERFICIE
    fi
    FABRICANT=$(udevadm info /sys/class/net/$NOM_INTERFICIE | grep ID_VENDOR_FROM_DATABASE | cut -d'=' -f2)
    if [ "$NOM_INTERFICIE" == "lo" ]; then
        FABRICANT='-'
    fi 
    MAC=$(cat /sys/class/net/$NOM_INTERFICIE/address)
    ESTAT_INTERFICIE=$(cat /sys/class/net/$NOM_INTERFICIE/operstate)
    # RESPONENT / NO RESPONENT
    MTU=$(cat /sys/class/net/$NOM_INTERFICIE/mtu)

    touch $NOM_INTERFICIE.txt

    IP_P=$(ip address show $NOM_INTERFICIE | grep 'inet\b' | awk '{print $2}' | cut -d'/' -f1)

    echo "Interfície:%$NOM_INTERFICIE [$NOM_ORIGINAL_INTERFICIE]" >> $NOM_INTERFICIE.txt
    echo "Fabricant:%$FABRICANT" >> $NOM_INTERFICIE.txt
    echo "Adreça MAC:%$MAC" >> $NOM_INTERFICIE.txt
    (ping -c 4 $IP_P) &> /dev/null && P_1=$(echo $?)
    if [ $P_1 == 0 ];then
        if [[ $ESTAT_INTERFICIE == "up" || $ESTAT_INTERFICIE == "unknown" ]]; then 
            echo "Estat de la interfície:%$ESTAT_INTERFICIE (responent...)" >> $NOM_INTERFICIE.txt
        else
            echo "Estat de la interfície:%$ESTAT_INTERFICIE (responent... sense senyal)" >> $NOM_INTERFICIE.txt
        fi
    else
        echo "Estat de la interfície:%$ESTAT_INTERFICIE (no responent...)" >> $NOM_INTERFICIE.txt
    fi
    echo "Mode de la interfície:%normal, amb mtu $MTU" >> $NOM_INTERFICIE.txt

    echo "%" >> $NOM_INTERFICIE.txt

# ---------------------------------------------------------------------------------------------------------
    
    wireless=$(iw dev | grep "Interface $NOM_INTERFICIE")
    
    if [ ! -z "$wireless" ]; then
    
        DISPOSITIU=$(iw dev | grep $NOM_INTERFICIE -B 1 | head -1 | sed 's/#//')
    	MODE_TREBALL=$(iw dev $NOM_INTERFICIE info | grep type | awk '{print $2}')
        POTENCIA_TR=$(iw dev $NOM_INTERFICIE info | grep txpower | awk '{print $2" "$3}')

        echo "Dispositiu Wi-Fi:%$DISPOSITIU" >> $NOM_INTERFICIE.txt
        echo "Mode de treball:%$MODE_TREBALL" >> $NOM_INTERFICIE.txt
        echo "Potència de transmissió:%$POTENCIA_TR" >> $NOM_INTERFICIE.txt

        if [ $(iw dev $NOM_INTERFICIE link | wc -l) -gt 1 ]; then

            echo "%" >> $NOM_INTERFICIE.txt

            SSID=$(iw dev $NOM_INTERFICIE link | grep SSID: | cut -d: -f 2- | sed 's/^ //' | sed 's/\n$//')
            FREQ=$(iw dev $NOM_INTERFICIE link | grep freq | awk '{print $2}')
            CANAL=$(iw dev $NOM_INTERFICIE info | grep channel | awk '{print $2}')
            SENYAL=$(iw dev $NOM_INTERFICIE link | grep signal | awk '{print $2" "$3}')
            PUNT_ACCES=$(iw dev $NOM_INTERFICIE link | grep 'Connected to' | awk '{print $3}')
            VEL_R=$(iw dev $NOM_INTERFICIE link | grep 'rx bitrate' | awk '{print $3" "$4}')
            VEL_T=$(iw dev $NOM_INTERFICIE link | grep 'tx bitrate' | awk '{print $3" "$4}')

            echo "SSID de la xarxa:%$SSID" >> $NOM_INTERFICIE.txt
            echo "Canal de treball:%$CANAL ($FREQ MHz)" >> $NOM_INTERFICIE.txt
            echo "Nivell de senyal:%$SENYAL" >> $NOM_INTERFICIE.txt
            echo "Punt d'accés associat:%$PUNT_ACCES" >> $NOM_INTERFICIE.txt
            echo "Vel. Wi-Fi Recepció:%$VEL_R" >> $NOM_INTERFICIE.txt
            echo "Vel. Wi-Fi Transmissió:%$VEL_T" >> $NOM_INTERFICIE.txt

            echo "%" >> $NOM_INTERFICIE.txt

        else
            CONNEXIO="No associat"
            echo "Connexió a xarxa:%$CONNEXIO" >> $NOM_INTERFICIE.txt
            echo "%" >> $NOM_INTERFICIE.txt
        fi

  	fi

# ---------------------------------------------------------------------------------------------------------

    echo -ne "${GROC}[EN PROCES]${NOCOLOR} Obtenint informació de l'adreçament... [$NOM_INTERFICIE]\r"
    
    CONFIG_ADR="-"
    DHCP_CONFIG=$(cat /etc/network/interfaces | grep $NOM_INTERFICIE | grep dhcp)
    IP_ADDRESS=$(ip address show $NOM_INTERFICIE | grep 'inet\b' | awk '{print $2}')
    
    if [[ -z "$DHCP_CONFIG" || $DHCP_CONFIG =~ ^# ]]; then # la linea esta comentada
        IP_STATIC_CONFIG=$(cat /etc/network/interfaces | grep address)
        if [[ -z "$IP_STATIC_CONFIG" || $IP_STATIC_CONFIG =~ ^# ]]; then
            if [ -z "$IP_ADDRESS" ]; then
            	CONFIG_ADR="no configurat"
            else
				CONFIG_ADR="estàtic (des de consola)"
            fi
        else
            CONFIG_ADR="estàtic (fitxer /etc/network/interfaces)"
        fi
    else
        if [ -z "$wireless" ]; then
            DHCP_SERVER=$(cat /var/lib/dhcp/dhclient.leases | awk "/$NOM_INTERFICIE/,/^$/" | grep dhcp-server-identifier | head -1 | awk '{print $3}' | sed 's/;//')
        else
            DHCP_SERVER=$(ip route | grep $NOM_INTERFICIE | grep default | cut -d' ' -f3)
            if [ -z "$DHCP_SERVER" ]; then DHCP_SERVER=$(ip route | grep default | head -1 | cut -d' ' -f3); fi
        fi
        CONFIG_ADR="dinàmic (DHCP $DHCP_SERVER)"
    fi

    
    if [ ! -z "$IP_ADDRESS" ]; then

        IP=$(ipcalc -b -c -n $IP_ADDRESS | grep Address: | sed 's/ //g' | cut -d: -f2)
        NETMASK=$(ipcalc -b -c -n $IP_ADDRESS | grep Netmask: | sed 's/ //g' | cut -d: -f2 | cut -d'=' -f1)
        WILDCARD=$(ipcalc -b -c -n $IP_ADDRESS | grep Wildcard: | sed 's/ //g' | cut -d: -f2)
        NETWORK=$(ipcalc -b -c -n $IP_ADDRESS | grep Network: | sed 's/ //g' | cut -d: -f2)
        HOSTMIN=$(ipcalc -b -c -n $IP_ADDRESS | grep HostMin: | sed 's/ //g' | cut -d: -f2)
        HOSTMAX=$(ipcalc -b -c -n $IP_ADDRESS | grep HostMax: | sed 's/ //g' | cut -d: -f2)
        BROADCAST=$(ipcalc -b -c -n $IP_ADDRESS | grep Broadcast: | sed 's/ //g' | cut -d: -f2)
        D_GATEWAY=$(ip route | grep $NOM_INTERFICIE | grep default | cut -d' ' -f3)
        if [ -z "$D_GATEWAY" ]; then D_GATEWAY=$(ip route | grep default | head -1 | cut -d' ' -f3); fi
        NOM_DNS=$(dig -x $IP | awk '/AUTHORITY SECTION:/,/^$/' | sed -n 2p | awk '{print }') &> /dev/null 
    
    else
        NOM_DNS='-'
    fi

    if [ "$NOM_INTERFICIE" == "lo" ]; then
        echo "Adreçament:%loopback (fitxer /etc/network/interfaces)" >> $NOM_INTERFICIE.txt
    else
        echo "Adreçament:%$CONFIG_ADR" >> $NOM_INTERFICIE.txt
    fi
	
    if [ "$CONFIG_ADR" == "no configurat" ]; then
        echo "Adreça IP / màscara:%-" >> $NOM_INTERFICIE.txt
        echo "Adreça de xarxa:%-" >> $NOM_INTERFICIE.txt
        echo "Adreça broadcast:%-" >> $NOM_INTERFICIE.txt
        echo "Gateway per defecte:%-" >> $NOM_INTERFICIE.txt
    else
        echo "Adreça IP / màscara:%$IP_ADDRESS ($NETWORK $NETMASK)" >> $NOM_INTERFICIE.txt
        echo "Adreça de xarxa:%$NETWORK [$HOSTMIN - $HOSTMAX]" >> $NOM_INTERFICIE.txt
        echo "Adreça broadcast:%$BROADCAST ($WILDCARD)" >> $NOM_INTERFICIE.txt
        echo "Gateway per defecte:%$D_GATEWAY" >> $NOM_INTERFICIE.txt
    fi

    if [ "$NOM_INTERFICIE" == "lo" ]; then
        echo "Nom DNS:%localhost." >> $NOM_INTERFICIE.txt
    else
        is_empty $NOM_DNS || [ $? -eq 7 ] && NOM_DNS='-'
        echo "Nom DNS:%$NOM_DNS" >> $NOM_INTERFICIE.txt
    fi

    echo "%" >> $NOM_INTERFICIE.txt

    echo -e "${VERD}[FINALITZAT]${NOCOLOR} Obtenint informació de l'adreçament... [$NOM_INTERFICIE]" 

# ---------------------------------------------------------------------------------------------------------

    curl ident.me &> publicIp.txt
    IP_PUBLICA=$(cat publicIp.txt | tail -1) # 85.62.187.56
    DNS_CMPNY=$(dig -x $IP_PUBLICA | awk '/ANSWER SECTION:/,/^$/' | sed -n 2p | awk '{print $5 " " $6}')
    if [ -z "$DNS_CMPNY" ]; then
        DNS_CMPNY=$(dig -x $IP_PUBLICA | awk '/AUTHORITY SECTION:/,/^$/' | sed -n 2p | awk '{print $5 " " $6}')
    fi

    ENTITY=$(whois $IP_PUBLICA | grep -B 1 "country:" | head -1 | sed 's/.*://;s/^[[:space:]]*//')
    COUNTRY=$(whois $IP_PUBLICA | grep "country:" | head -1 | sed 's/.*://;s/^[[:space:]]*//')
    NETNAME=$(whois $IP_PUBLICA | grep "netname:" | head -1 | sed 's/.*://;s/^[[:space:]]*//')
    NETWORK_CMPNY=$(whois $IP_PUBLICA | grep "route:" | head -1 | sed 's/.*://;s/^[[:space:]]*//')
    RANGE=$(whois $IP_PUBLICA | grep "inetnum:" | head -1 | sed 's/.*://;s/^[[:space:]]*//')
    NAT_DETECTAT="NAT detectat"

    touch traceroute.txt

    echo -ne "${GROC}[EN PROCES]${NOCOLOR} Traçant rutes... [$NOM_INTERFICIE]\r"
    traceroute $IP_PUBLICA --max-hops=10 > traceroute.txt
    echo -e "${VERD}[FINALITZAT]${NOCOLOR} Traçant rutes... [$NOM_INTERFICIE]"
    
    NUM_ROUTERS=$(cat traceroute.txt | grep -E "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | wc -l)
    ROUTE="$D_GATEWAY ($D_GATEWAY) -> $IP_PUBLICA ($IP_PUBLICA)"
    if [ ! -z "$wireless" ]; then
        ROUTE="$D_GATEWAY ($ROUT) -> $IP_PUBLICA ($DNS)"
    fi
    if [ $NUM_ROUTERS -gt 2 ]; then
        ROUTE="$IP_PUBLICA ($DNS_CMPNY)"
    fi

    RUTAS=$(ip route | grep $NOM_INTERFICIE)

    if [ "$NOM_INTERFICIE" != "lo" ]; then
        
        DNS="$DNS_CMPNY"
        if [ -z "$DNS_CMPNY" ]; then DNS='-'; fi

        echo "Adreça IP pública:%$IP_PUBLICA [$DNS]" >> $NOM_INTERFICIE.txt
        if [[ "$IP_PUBLICA" == "$IP" ]]; then
            #No detectat
            NAT_DETECTAT="NAT no detectat"
            echo "Detecció de NAT:%$NAT_DETECTAT" >> $NOM_INTERFICIE.txt
        else
            echo "Detecció de NAT:%$NAT_DETECTAT, $NUM_ROUTERS routers involucrats [$ROUTE] " >> $NOM_INTERFICIE.txt
        fi
        if [ ! -z "$wireless" ]; then
            echo "Consulta sobre:%$IP_PUBLICA $DNS" >> $NOM_INTERFICIE.txt
        else
            echo "Nom del domini:%$DNS_CMPNY" >> $NOM_INTERFICIE.txt
        fi
        echo "Xarxes de l'entitat:%$NETNAME $NETWORK_CMPNY [$RANGE]" >> $NOM_INTERFICIE.txt
        echo "Entitat propietària:%$ENTITY [$COUNTRY]" >> $NOM_INTERFICIE.txt
        
        echo "%" >> $NOM_INTERFICIE.txt
    fi
  
# ---------------------------------------------------------------------------
    
    if [ ! -z "$RUTAS" ]; then

        RUTAS=$(echo $RUTAS | sed 's/^/%/')

        echo "Rutes incolucrades:"$RUTAS" " >> $NOM_INTERFICIE.txt
        echo "%" >> $NOM_INTERFICIE.txt
    fi

# ---------------------------------------------------------------------------------------------------------

    echo -ne "${GROC}[EN PROCES]${NOCOLOR} Obtenint informació del tràfic de dades... [$NOM_INTERFICIE]\r"

    BYTES_REBUTS=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $2}')
    PQTS_REBUTS=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $3}')
    PQTS_ERRONIS_R=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $4}')
    PQTS_DESCARTATS_R=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $5}')
    PQTS_PERDUTS_R=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $7}')

    BYTES_TRANSMESOS=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $10}')
    PQTS_TRANSMESOS=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $11}')
    PQTS_ERRONIS_T=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $12}')
    PQTS_DESCARTATS_T=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $13}')
    PQTS_PERDUTS_T=$(cat /proc/net/dev | grep $NOM_INTERFICIE | awk '{print $15}')

    TRAFIC_REBUT="$BYTES_REBUTS bytes [$PQTS_REBUTS paquets] ($PQTS_ERRONIS_R erronis, $PQTS_DESCARTATS_R descartats i $PQTS_PERDUTS_R perduts)"
    TRAFIC_TRANSMES="$BYTES_TRANSMESOS bytes [$PQTS_TRANSMESOS paquets] ($PQTS_ERRONIS_T erronis, $PQTS_DESCARTATS_T descartats i $PQTS_PERDUTS_T perduts)"

    echo "Tràfic rebut:%$TRAFIC_REBUT" >> $NOM_INTERFICIE.txt
    echo "Tràfic transmès:%$TRAFIC_TRANSMES" >> $NOM_INTERFICIE.txt
    
    # ---------------------------------------------------------------------------------------------------------
    
    RX_BYTES=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/rx_bytes)
    RX_PACKETS=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/rx_packets)

    TX_BYTES=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/tx_bytes)
    TX_PACKETS=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/tx_packets)

    sleep 2

    RX_BYTES_2=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/rx_bytes)
    RX_PACKETS_2=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/rx_packets)

    TX_BYTES_2=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/tx_bytes)
    TX_PACKETS_2=$(cat /sys/class/net/$NOM_INTERFICIE/statistics/tx_packets)

    BYTES_R=$((($RX_BYTES_2 - $RX_BYTES)/2))
    PAQUETS_R=$((($RX_PACKETS_2 - $RX_PACKETS)/2))

    BYTES_T=$((($TX_BYTES_2 - $TX_BYTES)/2))
    PAQUETS_T=$((($TX_PACKETS_2 - $TX_PACKETS)/2))

    echo "Velocitat de Recepeció:%$BYTES_R bytes/s [$PAQUETS_R paquets/s]" >> $NOM_INTERFICIE.txt
    echo "Velocitat de Transmissió:%$BYTES_T bytes/s [$PAQUETS_T paquets/s]" >> $NOM_INTERFICIE.txt

    echo -e "${VERD}[FINALITZAT]${NOCOLOR} Obtenint informació del tràfic de dades... [$NOM_INTERFICIE]"

# ---------------------------------------------------------------------------------------------------------
  
    iterator=$(($iterator+1))
    interficie=$(ip link | grep "^$iterator: ")

    echo >> $NOM_INTERFICIE.txt
 
    layout_type=2
    info=""$NOM_INTERFICIE".txt"

    create_layout $NOM_INTERFICIE $info $layout_type
    cat log_interficie.log >> log_inet.log
    echo >> log_inet.log

    if [ ! -z "$wireless" ]; then
    
        echo -ne "${GROC}[EN PROCES]${NOCOLOR} Escanejant xarxes... [$NOM_INTERFICIE]\r"
        iw $NOM_INTERFICIE scan > iw_scan.info
        echo -e "${VERD}[FINALITZAT]${NOCOLOR} Escanejant xarxes... [$NOM_INTERFICIE]"

        select_info

        layout_type=3 && info="xarxes.log"
        create_layout $NOM_INTERFICIE $info $layout_type

        cat log_interficie.log >> log_inet.log
        echo >> log_inet.log

        cp iw_scan.info /altres
        rm iw_scan.info
    fi

    rm *.txt log_interficie.log &> /dev/null

    echo

done

touch descripcio.txt

echo "Analisi de les interficies del sistema realitzada per l'usuari "$USUARI" de l'equip $NOM_EQUIP" >> descripcio.txt
echo "Sistema operatiu $NOM_SO" >> descripcio.txt
echo "Versió del script $VERSIO compilada el $LAST_DATE." >> descripcio.txt

DATA_FI=$(date +'%d/%m/%Y')
HORA_FI=$(date +'%T')

TEMPS_TOTAL=$(($(date -d $HORA_FI +%s) - $(date -d $HORA_INI +%s)))

echo "Analisi iniciada en data $DATA_INI a les $HORA_INI i finalitzada en data $DATA_FI a les $HORA_FI ["$TEMPS_TOTAL"s]." >> descripcio.txt

layout_type=1
info="descripcio.txt"

create_layout $NOM_INTERFICIE $info $layout_type
cat log_interficie.log > descripcio.txt && rm log_interficie.log

cat log_inet.log >> descripcio.txt
mv descripcio.txt log_inet.log

rm *.txt &> /dev/null