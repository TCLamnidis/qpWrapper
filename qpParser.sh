#!/usr/bin/env bash
function join_by() { local IFS="$1"; shift; echo "$*"; }
function repeatTab() { Length="$1"; let reps=6-${Length}; myString="$(printf "%${reps}s")"; echo ${myString// /"\t"}; }

function Helptext {
    echo -ne "\t usage: qpParser.sh [options] (qpWave|qpAdm)\n\n"
    echo -ne "This programme will parse the output of all qpWave/qpAdm output files in the folder and print out a summary.\n\n"
    echo -ne "options:\n"
    echo -ne "-h, --help\t\tPrint this text and exit.\n"
    echo -ne "-t, --type\t\tSpecify the parsing type you require. If not provided, qpParser will try to infer the parsing type from the current directory path. One of qpAdm|qpWave|qpGraph.\n"
    echo -ne "-d, --details\t\tWhen parsing qpWave, the tail difference for each rank will be printed (only n-1 rank is printed by default). When parsing qpAdm, the full list of right populations is displayed, instead of the qpWave directory for the model.\n"
    echo -ne "-s, --suffix\t\tInput file prefix to look for. By default this is '.out' for qpWave/qpAdm parsing, and '.log' for qpGraph parsing.\n"
    echo -ne "-c, --cutoff\t\tZ-Score cutoff for qpGraph parsing. When supplied, any absolute Z-Score above the cutoff will not be printed.\n"
}

TEMP=`getopt -q -o -c:t:s:dnh --long cutoff:,type:,suffix:,details,newline,help -n 'qpParser.sh' -- "$@"`
eval set -- "$TEMP"

if [ $? -ne 0 ]
then
    Helptext
fi

while true ; do
    case "$1" in
    -t|--type)
        case "$2" in
        qpAdm) Type="qpAdm"; shift 2 ;;
        qpWave) Type="qpWave"; shift 2 ;;
        qpGraph) Type="qpGraph"; shift 2 ;;
        *) echo -e "Type requested is not supported.\n"; Helptext; exit 1 ;;
        esac ;;
    -c|--cutoff) cutoff="$2"; shift 2 ;;
    -d|--details) Details="TRUE"; shift;;
    -n|--newline) NewLine="FALSE"; shift;;
    -s|--suffix) suffix=$2; set_suffix="TRUE"; shift 2 ;;
    -h|--help) Helptext; exit 0 ;;
    *) break;;
esac
done

fn0="$PWD"

## If parsing type was not set via the option, infer from directory names.
if ! [[ -v Type ]]; then
    Type="$(echo ${fn0/*qp/qp} | cut -d "/" -f1)"
fi
OutGroup="${fn0/*${Type}\//}"

if [[ ${set_suffix} != "TRUE" ]]; then
    suffix=".out"
fi

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
            if [[ $NewLine != "FALSE" ]]; then
                echo ""
            fi
        else
            echo -e "${OutGroup}\t${joinRights}\t${joinLefts}\t${temp3[-1]}"
        fi
    fi
done < <(ls -1 ${fn0}/*${suffix})

if [[ ${set_suffix} != "TRUE" ]]; then
    suffix=".log"
fi

## qpGraph logfile parsing
while read r; do
    let outlier_number=0
    graph_switch1="off"
    if [[ $Type == "qpGraph" ]]; then
        while read f; do
            if [[ ${f} == "## qpGraph version:"* ]]; then
                let version=$(echo "${f}" | cut -d " " -f4)
            elif [[ "${version}" -ge "5052" && ${f} == "score:"* ]]; then 
                score=$(echo ${f} | cut -d " " -f 2)
                # echo $score
            elif [[ "${version}" -lt "5052" ]]; then 
                score="NA"
            elif [[ ${f} == "outliers:" ]]; then
                graph_switch1="on"
            elif [[ ${f} == "" ]]; then
                graph_switch1="off"
            elif [[ ${graph_switch1} == "on" ]]; then
                let outlier_number+=1
            elif [[ ${f} == "worst"* ]]; then
                worst_stat=$(echo "${f}" | tr -s " " | cut -d " " -f 11)
                # echo ${worst_stat}
            fi
        done < <(cat ${r})
        if [[ -v cutoff ]] && (( $(echo "$worst_stat > $cutoff"| bc -l) )); then
            :
        else
            echo -e "$(basename ${r})\t${score}\t${worst_stat}\t${outlier_number}"
        fi
        # elif ![[ -v cutoff ]]; then
#             echo -e "$(basename ${r})\t${score}\t${worst_stat}\t${outlier_number}"
#         fi
## echo ${outlier_number}
    fi
done < <(ls -1 ${fn0}/*${suffix})