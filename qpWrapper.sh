#!/usr/bin/env bash

#You should be editing ONLY the paths in lines 33-37! 

TEMP=`getopt -q -o hS:R:L: --long help,Sample:,Right:,Ref:,Left:,Source: -n 'qpWave.sh' -- "$@"`
eval set -- "$TEMP"

function Helptext {
	echo -ne "\t usage: qpWrapper.sh [options]\n\n"
	echo -ne "This programme will submit multiple qpWave/qpAdm runs, one for each Sample, with the rest of your Left and Right pops constant.\n\n"
	echo -ne "options:\n"
	echo -ne "-S, --Sample\t\tName of your sample. Can be provided multiple times.\n"
	echo -ne "-R, --Ref, --Right\tThe Right populations for your runs. Can be provided multiple times.\n"
	echo -ne "-L, --Left, --Source\tThe Left Pops of your runs. Your Sample will be the first Left pop, followed by these. Can be provided multiple times.\n"
}

if [ $? -ne 0 ]
then
	Helptext
fi

while true ; do
    case "$1" in
        -S|--Sample) SAMPLES+=("$2"); shift 2;;
        -R|--Ref|--Right) RIGHTS+=("$2") ; shift 2;;
        -L|--Left|--Source) LEFTS+=("$2"); shift 2;;
        --) TYPE=$2 ;shift 2; break ;;
        -h|--help) Helptext; exit 0 ;;
	*) echo -e "invalid option provided.\n"; Helptext; exit 1;;
    esac
done

# EDIT ONLY THIS PART
INDIR=/projects1/AncientFinnish/PopGen.Thiseas/MergedPopgen.backup/calls
OUTDIR=~/$TYPE
GENO=$INDIR/HO.1240K.Finnish.NoTrans.merged.geno
SNP=$INDIR/HO.1240K.Finnish.NoTrans.merged.snp
IND=$INDIR/HO.1240K.Finnish.NoTrans.merged.ind
mkdir -p $OUTDIR/Logs
mkdir -p $OUTDIR/.tmp
#DONT EDIT BELOW HERE


declare -i COUNT=0
for SAMPLE in "" ${SAMPLES[@]}; do
	POPLEFT=$OUTDIR/.tmp/$TYPE.Left.$COUNT.txt
	if [ -f $POPLEFT ]; then
		POPLEFT=$OUTDIR/.tmp/$TYPE.Left.$COUNT.txt1
	fi
	if [ "$SAMPLE" != "" ]; then
		printf "$SAMPLE\n" >$POPLEFT
	else
		printf "" >$POPLEFT
	fi
	for POP in ${LEFTS[@]}; do
		printf "$POP\n" >>$POPLEFT
	done
	
	POPRIGHT=$OUTDIR/.tmp/$TYPE.Right.$COUNT.txt
	if [ -f $POPRIGHT ]; then
		POPRIGHT=$OUTDIR/.tmp/$TYPE.Right.$COUNT.txt1
	fi
	printf "" >$POPRIGHT
	for REF in ${RIGHTS[@]}; do
		printf "$REF\n" >>$POPRIGHT
	done
	
	PARAMSFILE=$OUTDIR/.tmp/$TYPE.sh.params.$COUNT.txt
	printf "genotypename:\t$GENO\n" > $PARAMSFILE
	printf "snpname:\t$SNP\n" >> $PARAMSFILE
	printf "indivname:\t$IND\n" >> $PARAMSFILE
	printf "popleft:\t$POPLEFT\n" >> $PARAMSFILE
	printf "popright:\t$POPRIGHT\n" >>$PARAMSFILE
	printf "details:\tYES\n" >>$PARAMSFILE
	
	if [ "$SAMPLE" != "" ]; then
		LOG=$OUTDIR/Logs/$SAMPLE.$LEFTS.$RIGHTS.$TYPE.log
		if [ -f $OUTDIR/$SAMPLE.$LEFTS.$RIGHTS.$TYPE.out ]; then
			OUT=$OUTDIR/$SAMPLE.$LEFTS.$RIGHTS.$TYPE.out1
		else
			OUT=$OUTDIR/$SAMPLE.$LEFTS.$RIGHTS.$TYPE.out
		fi
	else
		LOG=$OUTDIR/Logs/$LEFTS.$RIGHTS.$TYPE.log
		if [ -f $OUTDIR/$SAMPLE.$LEFTS.$RIGHTS.$TYPE.out ]; then
			OUT=$OUTDIR/$LEFTS.$RIGHTS.$TYPE.out1
		else
			OUT=$OUTDIR/$LEFTS.$RIGHTS.$TYPE.out
		fi
	fi
	
	if [ $SAMPLE == "" -a $TYPE == "qpAdm" ]; then
		continue
	fi
	sbatch --job-name="${SAMPLE}_$TYPE" --mem=4000 -o $LOG --wrap="$TYPE -p $PARAMSFILE >$OUT"
	COUNT+=1
done

