#!/bin/bash

# SEAX 2022-23 Q2
# OMAR BRIQA            -> omar.briqa@estudiantat.upc.edu
# ALEX PASCUAL BATET    -> alex.pascual.batet@estudiantat.upc.edu

function is_empty() {
    if [ -z "$1" ]; then
        return 7
    else
        return 5
    fi
}

# ENTRADA
#   -> iw_scan.info (output comanda iw [dev] scan)
# SORTIDA
#   -> xarxes.log
function select_info(){
    
    rm xarxes.log &> /dev/null
    touch xarxaWifi.log xarxes.log

    IFS=''
    while read -r line; do
        if [[ $line =~ ^BSS* ]]; then
            if [ $(cat xarxaWifi.log | wc -l) -ne 0 ]; then
                select_wifi
                rm xarxaWifi.log && touch xarxaWifi.log
            fi
            echo $line >> xarxaWifi.log
        else
            echo $line >> xarxaWifi.log
        fi

    done < iw_scan.info

    select_wifi
    rm xarxaWifi.log &> /dev/null
}

# Funció auxiliar de 'select_info'   
function select_wifi(){

    SSID=$(cat xarxaWifi.log | grep SSID: | cut -d: -f2 | sed 's/\n$//')
    if [[ -z "$SSID" || "$SSID" == *"\x00"* ]]; then SSID="."; fi
    CANAL=$(cat xarxaWifi.log | grep "DS Parameter set" | cut -d: -f2 | awk '{print $2}' | sed 's/\n$//')
    if [ -z "$CANAL" ]; then CANAL="-"; fi
    FREQ=$(cat xarxaWifi.log | grep freq: | cut -d: -f2 | sed 's/^ //' | sed 's/\n$//')
    SENYAL=$(cat xarxaWifi.log | grep signal: | cut -d: -f2 | awk '{print $1" "$2}' | sed 's/\n$//')
    VMAX=$(cat xarxaWifi.log | grep "Supported rates" | cut -d: -f2 | sed 's/^ //' | tr -d '*' | sed 's/\n$//' | sed 's/\n$//' | awk '{print $NF}')

    XIFRAT=""
    ALGORITMES=""
    PRIVACY=$(cat xarxaWifi.log | grep capability | grep Privacy)
    if [ -z "$PRIVACY" ]; then
        XIFRAT="sense"
        ALGORITMES="."
    else
        RSN=$(cat xarxaWifi.log | grep "RSN:")
        WPA=$(cat xarxaWifi.log | grep "WPA:")

        if [[ -z "$WPA" && -z "$RSN" ]]; then
            XIFRAT="WEP"
            ALGORITMES="."
            
        elif [[ ! -z "$WPA" && -z "$RSN" ]]; then            
            A_WPA=$(cat xarxaWifi.log | grep "WPA:" -A 4)
            WPA_GROUP=$(echo "$A_WPA" | grep "Group cipher:" | awk '{print $NF}' | sed 's/\n$//')
            WPA_PAIRWISE=$(echo "$A_WPA" | grep "Pairwise ciphers:" | awk '{print $NF}' | sed 's/\n$//')
            WPA_AUTH=$(echo "$A_WPA" | grep "Authentication suites:" | cut -d: -f 2- | sed 's/^ //' | sed 's/\n$//')
            
            XIFRAT="WPA"
            ALGORITMES=""$WPA_AUTH"-"$WPA_PAIRWISE"-"$WPA_GROUP""

        elif [[ -z "$WPA" && ! -z "$RSN" ]]; then
        	
            A_WPA2=$(cat xarxaWifi.log | grep "RSN:" -A 4)
            WPA2_GROUP=$(echo "$A_WPA2" | grep "Group cipher:" | awk '{print $NF}' | sed 's/\n$//')
            WPA2_PAIRWISE=$(echo "$A_WPA2" | grep "Pairwise ciphers:" | awk '{print $NF}' | sed 's/\n$//')
            WPA2_AUTH=$(echo "$A_WPA2" | grep "Authentication suites:" | cut -d: -f 2- | sed 's/^ //' | sed 's/\n$//')
            
            XIFRAT="WPA2"
            ALGORITMES=""$WPA2_AUTH"-"$WPA2_PAIRWISE"-"$WPA2_GROUP""
            
        elif [[ ! -z "$WPA" && ! -z "$RSN" ]]; then

            A_WPA=$(cat xarxaWifi.log | grep "WPA:" -A 4)
            WPA_GROUP=$(echo "$A_WPA" | grep "Group cipher:" | awk '{print $NF}' | sed 's/\n$//')
            WPA_PAIRWISE=$(echo "$A_WPA" | grep "Pairwise ciphers:" | awk '{print $NF}' | sed 's/\n$//')
            WPA_AUTH=$(echo "$A_WPA" | grep "Authentication suites:" | cut -d: -f 2- | sed 's/^ //' | sed 's/\n$//')

            A_WPA2=$(cat xarxaWifi.log | grep "RSN:" -A 4)
            WPA2_GROUP=$(echo "$A_WPA2" | grep "Group cipher:" | awk '{print $NF}' | sed 's/\n$//')
            WPA2_PAIRWISE=$(echo "$A_WPA2" | grep "Pairwise ciphers:" | awk '{print $NF}' | sed 's/\n$//')
            WPA2_AUTH=$(echo "$A_WPA2" | grep "Authentication suites:" | cut -d: -f 2- | sed 's/^ //' | sed 's/\n$//')

            ALGORITMES=""$WPA_AUTH"-"$WPA_PAIRWISE"-"$WPA_GROUP"/"$WPA2_AUTH"-"$WPA2_PAIRWISE"-"$WPA2_GROUP""
            XIFRAT="WPA/WPA2"
        fi
    fi

  	MAC=$(cat xarxaWifi.log | grep "^BSS" | cut -d'(' -f1 | cut -d' ' -f2 | sed 's/\n$//')
    MAC_MINI=$(echo $MAC | cut -d: -f 1,2,3 | sed 's/:/-/g')
    FABRICANT=$(cat MAC_info.info | grep "$(echo ${MAC_MINI^^})" | head -1 | cut -d')' -f 2- | sed 's/.*://;s/^[[:space:]]*//' | sed 's/.$//')
    if [ -z "$FABRICANT" ]; then
        FABRICANT="desconegut"
    fi

    WIFI=""$SSID"%"$CANAL"%"$FREQ" MHz%"$SENYAL"%"$VMAX" Mbps%"$XIFRAT"%"$ALGORITMES"%"$MAC"%"$FABRICANT""
    echo $WIFI >> xarxes.log

}

# ENTRADA 
#   -> dades
#   -> nom_interficie
function create_layout(){

    # ------------------------------ Arxius auxiliars ------------------------------------

    nom_interficie=$1
    touch limit.txt limitH.txt lineaBuida.txt header.txt log_interficie.log

    sup_esq="┌" && sup_drt="┐" && inf_esq="└" && inf_drt="┘" && lateral="│" && sup_inf="─"
    if [ $3 -eq 1 ]; then
        sup_esq="╔" && sup_drt="╗" && inf_esq="╚" && inf_drt="╝" && lateral="║" && sup_inf="═"
    fi

    rm log_interficie.log &> /dev/null

    if [[ $3 -eq 1 || $3 -eq 2 ]]; then 

        sed 's/^/  /' $2 | sed 's/$/  /' | column -t -s% > interficie.txt
        cat interficie.txt > "$2"

        # ------------------------------ Límits superiors ------------------------------------

        maxCol=$(wc -L interficie.txt | awk '{print $1}') && maxCol=$(($maxCol+5))
        
        for ((i = 1; i < $maxCol; i++)); do echo -n "$sup_inf" >> limit.txt; done
        for ((i = 3; i < $maxCol; i++)); do echo -n "-" >> limitH.txt; done

        sed 's/-/ /g' limitH.txt >> lineaBuida.txt
        printf "\n" >> limit.txt && printf "\n" >> limitH.txt && printf "\n" >> lineaBuida.txt

        sed "s/^/$sup_esq/" limit.txt | sed "s/$/$sup_drt/" > limitSuperior.txt
        cat limitSuperior.txt >> log_interficie.log
        sed "s/^/$lateral /" lineaBuida.txt | sed "s/$/ $lateral/" >> log_interficie.log
       
        # ---------------------------------- Capçalera ---------------------------------------

        if [ $3 -eq 2 ]; then

            echo "Configuració de la interfície $nom_interficie." >> titol.txt

            colT=$(wc -L titol.txt | awk '{print $1}') && colT=$(($colT+2)) && extra_pad=""
            for ((i = ini; i < $((($maxCol - $colT)/2)); i++)); do extra_pad=""$extra_pad" "; done
            echo "$extra_pad$(cat titol.txt)$extra_pad" > titolH.txt

            sed "s/^/$lateral /" limitH.txt | sed "s/$/ $lateral/" >> header.txt
            if [ $(wc -L titolH.txt | awk '{print $1}') -ne $(wc -L limitH.txt | awk '{print $1}') ]; then
                sed "s/^/$lateral /" titolH.txt | sed "s/$/$lateral/" >> header.txt
            else
                sed "s/^/$lateral /" titolH.txt | sed "s/$/ $lateral/" >> header.txt
            fi
            sed "s/^/$lateral /" limitH.txt | sed "s/$/ $lateral/" >> header.txt

            cat header.txt >> log_interficie.log

        else
            sed "s/^/$lateral /" limitH.txt | sed "s/$/ $lateral/" >> log_interficie.log
        fi

        # ---------------------------------- Contingut --------------------------------------

        IFS=''
        while read -r line; do
            extra_pad=""
            echo $line > linea.txt && nCol=$(wc -L linea.txt | awk '{print $1}') && nPad=$(($maxCol - $nCol - 2))
            for ((i = 0; i < $nPad; i++)); do extra_pad=""$extra_pad" "; done && extra_pad=""$extra_pad""$lateral""
            sed "s/^/$lateral /" linea.txt  | sed "s/$/$extra_pad/" >> log_interficie.log
        done < $2

        # ------------------------------ Límits inferiors ------------------------------------

        sed "s/^/$lateral /" limitH.txt | sed "s/$/ $lateral/" >> log_interficie.log
        sed "s/^/$lateral /" lineaBuida.txt | sed "s/$/ $lateral/" >> log_interficie.log
        sed "s/^/$inf_esq/" limit.txt | sed "s/$/$inf_drt/" > limitInferior.txt
        cat limitInferior.txt >> log_interficie.log
    
    elif [ $3 -eq 3 ]; then
        
        HEADER="SSID%canal%freqüència%senyal%v. max.%xifrat%algorismes xifrat%Adreça MAC%fabricant"
        rm xarxes_wifi.log &> /dev/null && touch xarxes_wifi.log

        echo $HEADER >> xarxes_wifi.log
        sort $2 >> xarxes_wifi.log

        num_xarxes=$(cat $2 | cut -d% -f1 | wc -l)
        num_canals=$(cat $2 | cut -d% -f2 | sort -u | wc -l)

        sed 's/^/  /' xarxes_wifi.log | column -t -s% > dades.txt
        cat dades.txt > "$2"

        # ------------------------------ Límits superiors ------------------------------------

        maxCol=$(wc -L $2 | awk '{print $1}') && maxCol=$(($maxCol+5))
        for ((i = 1; i < $maxCol; i++)); do echo -n "$sup_inf" >> limit.txt; done

        for ((i = 3; i < $maxCol; i++)); do echo -n "-" >> limitH.txt; done

        sed 's/-/ /g' limitH.txt >> lineaBuida.txt
        printf "\n" >> limit.txt && printf "\n" >> limitH.txt && printf "\n" >> lineaBuida.txt

        sed "s/^/$sup_esq/" limit.txt | sed "s/$/$sup_drt/" > limitSuperior.txt
        cat limitSuperior.txt >> log_interficie.log
        sed "s/^/$lateral /" lineaBuida.txt | sed "s/$/ $lateral/" >> log_interficie.log

        # ---------------------------------- Capçalera ---------------------------------------

        echo "S'ha detectat $num_xarxes xarxes en $num_canals canals a la interfície $nom_interficie." >> titol.txt

        colT=$(wc -L titol.txt | awk '{print $1}') && colT=$(($colT+2)) && extra_pad=""
        for ((i = ini; i < $((($maxCol - $colT)/2)); i++)); do extra_pad=""$extra_pad" "; done
        echo "$extra_pad$(cat titol.txt)$extra_pad" > titolH.txt

        sed "s/^/$lateral /" limitH.txt | sed "s/$/ $lateral/" >> header.txt
        if [ $(wc -L titolH.txt | awk '{print $1}') -ne $(wc -L limitH.txt | awk '{print $1}') ]; then
            sed "s/^/$lateral /" titolH.txt | sed "s/$/$lateral/" >> header.txt
        else
            sed "s/^/$lateral /" titolH.txt | sed "s/$/ $lateral/" >> header.txt
        fi
        sed "s/^/$lateral /" limitH.txt | sed "s/$/ $lateral/" >> header.txt

        cat header.txt >> log_interficie.log

        # ---------------------------------- Contingut --------------------------------------

        HEADER_V2=""
        touch limitH_inf.txt && echo -n "  " >> limitH_inf.txt
        for ((i = 1; i <= 9; i++)); do
            columna=$(cat xarxes_wifi.log | cut -d% -f$i | wc -L)
            titol=$(cat xarxes_wifi.log | cut -d% -f$i | head -1)
            mida_titol=$(echo $titol | wc -L)

            extra_pad="" && complete_pad=""
            for ((k = 0; k < $((($columna - $mida_titol)/2)); k++)); do extra_pad=""$extra_pad" "; done

            if [ $(($(($columna - $mida_titol))%2)) -eq 1 ]; then complete_pad=" "; fi

            HEADER_V2=""$HEADER_V2""$extra_pad""$complete_pad""$titol""$extra_pad""
            if [ $i -ne 9 ]; then HEADER_V2=""$HEADER_V2"%"; fi
            
            for ((j = 1; j <= columna; j++)); do echo -n "-" >> limitH_inf.txt; done

            if [ $i -ne 9 ]; then echo -n "  " >> limitH_inf.txt; fi

        done

        printf "\n" >> limitH_inf.txt

        HEADER_V2="  "$HEADER_V2""
        echo "$HEADER_V2" | column -t -s% > wifi.txt && cat limitH_inf.txt >> wifi.txt
        cat $2 | tail -$(($(wc $2 | awk '{print $1}')-1)) >> wifi.txt
        cat wifi.txt > $2

        IFS=''
        while read -r line; do
            extra_pad=""
            echo $line > linea.txt && nCol=$(wc -L linea.txt | awk '{print $1}') && nPad=$(($maxCol - $nCol - 2))
            for ((i = 0; i < $nPad; i++)); do extra_pad=""$extra_pad" "; done && extra_pad=""$extra_pad""$lateral""
            sed "s/^/$lateral /" linea.txt  | sed "s/$/$extra_pad/" >> log_interficie.log
        done < $2

        # ------------------------------ Límits inferiors ------------------------------------

        sed "s/^/$lateral /" limitH.txt | sed "s/$/ $lateral/" >> log_interficie.log
        sed "s/^/$lateral /" lineaBuida.txt | sed "s/$/ $lateral/" >> log_interficie.log
        sed "s/^/$inf_esq/" limit.txt | sed "s/$/$inf_drt/" > limitInferior.txt
        cat limitInferior.txt >> log_interficie.log
    fi

    rm *.txt xarxes.log xarxes_wifi.log &> /dev/null

}