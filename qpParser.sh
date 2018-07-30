#!/usr/bin/env bash
function join_by() { local IFS="$1"; shift; echo "$*"; }
function repeatTab() { Length="$1"; let reps=6-${Length}; myString="$(printf "%${reps}s")"; echo ${myString// /"\t"}; }
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
		temp=$(grep -n "0  0" ${r} | tr -s " ")
		temp1=$(echo $temp | sed -e 's/ /\t/g' | cut -f 6-)
		let ResultLine=$(echo $temp | sed -e 's/ /\t/g' | cut -f 1 | rev | cut -c 2- | rev)+1
		temp=$(grep -n "errors:" ${r} | tr -s " " | sed -e 's/ /\t/g' )
		temp2=$(echo $temp | sed -e 's/ /\t/g' | cut -f 4-)
		let ErrorLine=$(echo $temp | sed -e 's/ /\t/g' | cut -f 1 | rev | cut -c 2- | rev)+1
		while read f; do
			if [[ ${f} == "right pops:" ]]; then
				break
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
		# echo -e "${ProportionsPrint%	}"
		echo -e "${sample}\t${OutGroup}\t${joinSources}\t${ProportionsPrint%	}\t${Buffer}${temp2}${temp4}"

## qpWave parsing
	elif [[ $Type == "qpWave" ]]; then
		switch2='off'
		temp3=$(grep taildiff $r | tail -n1 | tr -s " " | sed -e 's/ /\t/g' | rev | cut -f1 | rev)
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
		echo -e "${OutGroup}\t${joinRights}\t${joinLefts}\t${temp3}"
	fi
done < <(ls -1 ${fn0}/*.out)
