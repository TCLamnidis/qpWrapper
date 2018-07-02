#!/usr/bin/env bash
function join_by() { local IFS="$1"; shift; echo "$*"; }
function repeatTab() { Length="$1"; let reps=4-${Length}; myString="$(printf "%${reps}s")"; echo ${myString// /"\t"}; }
fn0="$PWD"
OutGroup="${fn0/*qpAdm\//}"
while read r; do
	unset Lefts
	switch='off'
	temp1=$(grep "0  0" $r | tr -s " " | sed -e 's/ /\t/g' | cut -f 6-)
	temp2=$(grep "errors:" $r | tr -s " " | sed -e 's/ /\t/g'| cut -f 4-)
	while read f; do
		if [[ ${f} == "right pops:" ]]; then
			break
		elif [[ ${switch} == 'on' && ${f} != "" ]]; then
			Lefts+=("$f")
		elif [[ ${f} == "left pops:" ]]; then
			switch='on'
		fi
	done < <(cat ${r})
	sample=${Lefts[0]}
	Sources=(${Lefts[@]:1})
	joinSources=$(join_by , ${Sources[@]})
	if [[ ${#Sources[@]} -lt 4 ]]; then
		Buffer=$(repeatTab ${#Sources[@]})
	fi
	echo -e "${sample}\t${OutGroup}\t${joinSources}\t${temp1%infeasible}${Buffer}\t${temp2}"
done < <(ls -1 ${fn0}/*.out)
