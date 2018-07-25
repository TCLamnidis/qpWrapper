#!/usr/bin/env bash
function join_by() { local IFS="$1"; shift; echo "$*"; }
function repeatTab() { Length="$1"; let reps=6-${Length}; myString="$(printf "%${reps}s")"; echo ${myString// /"\t"}; }
fn0="$PWD"
Type="$(echo ${fn0/*qp/qp} | cut -d "/" -f1)"
OutGroup="${fn0/*${Type}\//}"

while read r; do
	unset Lefts
	unset Rights
	switch1='off'

## qpAdm Parser
	if [[ $Type == "qpAdm" ]]; then
		temp1=$(grep "0  0" $r | tr -s " " | sed -e 's/ /\t/g' | cut -f 6-)
		temp2=$(grep "errors:" $r | tr -s " " | sed -e 's/ /\t/g'| cut -f 4-)
		while read f; do
			if [[ ${f} == "right pops:" ]]; then
				break
			elif [[ ${switch1} == 'on' && ${f} != "" ]]; then
				Lefts+=("$f")
			elif [[ ${f} == "left pops:" ]]; then
				switch1='on'
			fi
		done < <(cat ${r})
		sample=${Lefts[0]}
		Sources=(${Lefts[@]:1})
		joinSources=$(join_by , ${Sources[@]})
		if [[ ${#Sources[@]} -lt 5 ]]; then
			let Length=${#Sources[@]}+1
			Buffer=$(repeatTab ${Length})
		fi
		echo -e "${sample}\t${OutGroup}\t${joinSources}\t${temp1%infeasible}${Buffer}${temp2}"

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
