#!/usr/bin/env bash

#You should be editing ONLY the paths in lines 36-40! 

TEMP=`getopt -q -o hS:R:L:D: --long help,Sample:,Right:,Ref:,Left:,Source:,SubDir: -n 'qpWrapper.sh' -- "$@"`
eval set -- "$TEMP"

function Helptext {
	echo -ne "\t usage: qpWrapper.sh [options]\n\n"
	echo -ne "This programme will submit multiple qpWave/qpAdm runs, one for each Sample, with the rest of your Left and Right pops constant.\n\n"
	echo -ne "options:\n"
	echo -ne "-S, --Sample\t\tName of your sample. Can be provided multiple times.\n"
	echo -ne "-R, --Ref, --Right\tThe Right populations for your runs. Can be provided multiple times.\n"
	echo -ne "-L, --Left, --Source\tThe Left Pops of your runs. Your Sample will be the first Left pop, followed by these. Can be provided multiple times.\n"
	echo -ne "-D, --SubDir\tWhen provided, results will be placed in a subdirectory with the name provided within the result directory. Deeper paths can be provided by using '/'.\n"
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
        -D|--SubDir) SUBDIR="$2"; shift 2;;
        --) TYPE=$2 ;shift 2; break ;;
        -h|--help) Helptext; exit 0 ;;
	*) echo -e "invalid option provided.\n"; Helptext; exit 1;;
    esac
done

# EDIT ONLY THIS PART
INDIR=/projects1/AncientFinnish/DataFreeze20_07_17/results/calls
OUTDIR=/projects1/AncientFinnish/DataFreeze20_07_17/results #Subdirectories will be created within this directory to contain the results from the runs.
GENO=$INDIR/Baltic.PublishedOnly.HO.1240K.Ancients+Saami.geno 
SNP=$INDIR/Baltic.PublishedOnly.HO.1240K.Ancients+Saami.snp
IND=$INDIR/Baltic.PublishedOnly.HO.1240K.Ancients+Saami.ind
#DONT EDIT BELOW HERE

OUTDIR2=$OUTDIR/$TYPE/$SUBDIR
mkdir -p $OUTDIR2/Logs
mkdir -p $OUTDIR2/.tmp

for SAMPLE in "" ${SAMPLES[@]}; do
	TEMPDIR=$(mktemp -d $OUTDIR2/.tmp/XXXXXXXX)
	POPLEFT=$TEMPDIR/Left
	if [ "$SAMPLE" != "" ]; then
		printf "$SAMPLE\n" >$POPLEFT
	else
		printf "" >$POPLEFT
	fi
	for POP in ${LEFTS[@]}; do
		printf "$POP\n" >>$POPLEFT
	done
	
	POPRIGHT=$TEMPDIR/Right
	printf "" >$POPRIGHT
	for REF in ${RIGHTS[@]}; do
		printf "$REF\n" >>$POPRIGHT
	done
	
	PARAMSFILE=$TEMPDIR/Params
	printf "genotypename:\t$GENO\n" > $PARAMSFILE
	printf "snpname:\t$SNP\n" >> $PARAMSFILE
	printf "indivname:\t$IND\n" >> $PARAMSFILE
	printf "popleft:\t$POPLEFT\n" >> $PARAMSFILE
	printf "popright:\t$POPRIGHT\n" >>$PARAMSFILE
	printf "details:\tYES\n" >>$PARAMSFILE
	
	if [ "$SAMPLE" != "" ]; then
		LOG=$OUTDIR2/Logs/$SAMPLE.$LEFTS.$RIGHTS.$TYPE.$(basename $TEMPDIR).log
		OUT=$OUTDIR2/$SAMPLE.$LEFTS.$RIGHTS.$TYPE.$(basename $TEMPDIR).out
	else
		LOG=$OUTDIR2/Logs/$LEFTS.$RIGHTS.$TYPE.$(basename $TEMPDIR).log
		OUT=$OUTDIR2/$LEFTS.$RIGHTS.$TYPE.$(basename $TEMPDIR).out
	fi
	if [[ $SAMPLE == "" && $TYPE == "qpAdm" ]]; then
		continue
	fi
	# echo "OUT: $OUT"
	# echo "LOG: $LOG"
	# echo "LEFT: $POPLEFT"
	# echo "RIGHT: $POPRIGHT"
	# echo "PARAM: $PARAMSFILE"
	# echo "${SAMPLE}_$TYPE"
	sbatch --job-name="${SAMPLE}_${SUBDIR}_$TYPE" --mem=4000 -o $LOG --wrap="$TYPE -p $PARAMSFILE >$OUT"
done

