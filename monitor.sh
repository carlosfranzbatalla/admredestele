#!/bin/bash
vFechaHoy=$(date +%Y%m%d-%H:%M:%S)
vArchivoCsv='/home/carlosfranz/Documents/MyCode/telematica/sandbox/amonitor.csv'
vDominios=('www.yahoo.com' 'sed.ucla.edu.ve' 'www.ucla.edu.ve')

creaCsv(){
echo $1','$2','$3','$4','$5','$6 >> ${vArchivoCsv}
}

obtienePuertaDeEnlace(){
   gateway=$(ip route show 0.0.0.0/0 | awk '{print $3}')
}

verificaOperatividad(){    
    taman=$(ping -qc1 $1 2>&1 | awk -F'/' 'END{ print (/^rtt/? "SI "$5" ms":"NO") }')
}

creaLineaCsv(){
    vNroDeDominios=${#vDominios[@]}
    for ((vIndice = 0; vIndice < ${vNroDeDominios}; vIndice++)); do                
        verificaOperatividad "${vDominios[$vIndice]}"
        obtienePuertaDeEnlace        
        creaCsv $HOSTNAME ${vDominios[$vIndice]} $vFechaHoy $gateway $taman:0:3 $taman:4:10 
        sleep 5
    done
}

if test -f "$vArchivoCsv"; then
creaLineaCsv
else
creaCsv 'HOSTNAME' 'DOMINIO' 'FECHA' 'Puerta De Enlace' 'Operativo' 'T. respuesta'
creaLineaCsv
fi


