#!/bin/bash
vFechaHoy=$(date +%Y%m%d-%H:%M:%S)
vArchivoCsv='/home/carlosfranz/Documents/MyCode/telematica/sandbox/amonitor.csv'
vDominios=('www.yahoo.com' 'sed.ucla.edu.ve' 'www.ucla.edu.ve')
vDns='8.8.8.8'

creaCsv(){
echo $1','$2','$3','$4','$5','$6 >> ${vArchivoCsv}
}

obtienePuertaDeEnlace(){
   gateway=$(ip route get $vDns | awk '{print $3}')
}

verificaOperatividad(){    
    vResult=$(ping -qc1 $1 2>&1 | awk -F'/' 'END{ print (/^rtt/? "SI "$5" ms":"NO") }')
}

creaLineaCsv(){
    vNroDeDominios=${#vDominios[@]}
    for ((vIndice = 0; vIndice < ${vNroDeDominios}; vIndice++)); do                
        verificaOperatividad "${vDominios[$vIndice]}"
        obtienePuertaDeEnlace        
        creaCsv $HOSTNAME ${vDominios[$vIndice]} $vFechaHoy $gateway $vResult:0:3 $vResult:4:10 
        sleep 5
    done
}

if test -f "$vArchivoCsv"; then
creaLineaCsv
else
creaCsv 'HOSTNAME' 'DOMINIO' 'FECHA' 'Puerta De Enlace' 'Operativo' 'T. respuesta'
creaLineaCsv
fi


