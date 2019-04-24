#!/usr/bin/env bash
function join_by() { local IFS="$1"; shift; echo "$*"; }
function repeatTab() { Length="$1"; let reps=6-${Length}; myString="$(printf "%${reps}s")"; echo ${myString// /"\t"}; }

function Helptext {
    echo -ne "\t usage: qpParser.sh [options] (qpWave|qpAdm)\n\n"
    echo -ne "This programme will parse the output of all qpWave/qpAdm output files in the folder and print out a summary.\n\n"
    echo -ne "options:\n"
    echo -ne "-h, --help\t\tPrint this text and exit.\n"
    echo -ne "-d, --details\t\tWhen parsing qpWave, the tail difference for each rank will be printed (only n-1 rank is printed by default). When parsing qpAdm, the full list of right populations is displayed, instead of the qpWave directory for the model.\n"
}

TEMP=`getopt -q -o dh --long details,help -n 'qpParser.sh' -- "$@"`
eval set -- "$TEMP"

if [ $? -ne 0 ]
then
    Helptext
fi

while true ; do
    case "$1" in
        -d|--details) Details="TRUE"; shift 2;;
        -h|--help) Helptext; exit 0 ;;
        *) break;;
    esac
done


fn0="$PWD"
Type="$(echo ${fn0/*qp/qp} | cut -d "/" -f1)"
OutGroup="${fn0/*${Type}\//}"

while read r; do
    unset Lefts
    unset Rights
    unset temp3
    unset temp4
    switch1='off'

## qpAdm Parser
    if [[ $Type == "qpAdm" ]]; then
        switch2='off'
        temp=$(grep -n "0  0" ${r} | tr -s " ")
        temp1=$(echo $temp | sed -e 's/ /\t/g' | cut -f 6-)
        let ResultLine=$(echo $temp | sed -e 's/ /\t/g' | cut -f 1 | rev | cut -c 2- | rev)+1
        temp=$(grep -n "errors:" ${r} | tr -s " " | sed -e 's/ /\t/g' )
        temp2=$(echo $temp | sed -e 's/ /\t/g' | cut -f 4-)
        let ErrorLine=$(echo $temp | sed -e 's/ /\t/g' | cut -f 1 | rev | cut -c 2- | rev)+1
        while read f; do
            if [[ ${switch2} == 'on' && ${f} == "" ]]; then
                break
            elif [[ ${switch2} == 'on' ]]; then
                Rights+=("$f")
            elif [[ ${f} == "right pops:" ]]; then
                switch2='on'
            elif [[ ${switch1} == 'on' && ${f} != "" ]]; then
                Lefts+=("$f")
            elif [[ ${f} == "left pops:" ]]; then
                switch1='on'
            fi
        done < <(cat ${r})
        if [[ ${temp1} == *"..." ]] && [[ ${temp2} == *"..." ]]; then
            temp1=${temp1%...}
            temp2=${temp2%...}
            temp3=$(sed "${ResultLine}q;d" ${r} | tr -s " " | sed -e 's/ /\t/g' | cut -f 2-)
            temp4=$(sed "${ErrorLine}q;d" ${r} | tr -s " " | sed -e 's/ /\t/g' | cut -f 2-)
        fi
        ProportionsPrint="${temp1}${temp3}"
        ProportionsPrint="${ProportionsPrint%infeasible}"
        sample=${Lefts[0]}
        Sources=(${Lefts[@]:1})
        joinSources=$(join_by , ${Sources[@]})
        if [[ ${#Sources[@]} -lt 5 ]]; then
            let Length=${#Sources[@]}+1
            Buffer=$(repeatTab ${Length})
        fi
        if [[ $Details == "TRUE" ]]; then
            OutGroup=$(join_by , ${Rights[@]})
        fi
        # echo -e "${ProportionsPrint%  }"
        echo -e "${sample}\t${OutGroup}\t${joinSources}\t${ProportionsPrint%	}\t${Buffer}${temp2}${temp4}"

## qpWave parsing
    elif [[ $Type == "qpWave" ]]; then
        switch2='off'
        temp3=($(grep taildiff $r | tr -s " " | sed -e 's/ /\t/g' | rev | cut -f1 | rev))
        while read f; do
            if [[ ${switch2} == 'on' && ${f} == "" ]]; then
                break
            elif [[ ${switch2} == 'on' ]]; then
                Rights+=("$f")
            elif [[ ${f} == "right pops:" ]]; then
                switch2='on'
            elif [[ ${switch1} == 'on' && ${f} != "" ]]; then
                Lefts+=("$f")
            elif [[ ${f} == "left pops:" ]]; then
                switch1='on'
            fi
        done < <(cat ${r})
        joinLefts=$(join_by , ${Lefts[@]})
        joinRights=$(join_by , ${Rights[@]})
        if [[ $Details == "TRUE" ]]; then
            for i in `seq 0 1 $(expr ${#temp3[@]} - 1)`; do 
                echo -e "${OutGroup}\t${joinRights}\t${joinLefts}\t${temp3[-i-1]}\twaves: $(expr ${#temp3[@]} - `expr ${i}`)"
            done
            echo ""
        else
            echo -e "${OutGroup}\t${joinRights}\t${joinLefts}\t${temp3[-1]}"
        fi
    fi
done < <(ls -1 ${fn0}/*.out)
