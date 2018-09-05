#!/usr/bin/env bash

#You should be editing ONLY the paths in lines 36-40! 

TEMP=`getopt -q -o haS:R:L:D: --long help,Sample:,Right:,Ref:,Left:,Source:,SubDir: -n 'qpWrapper.sh' -- "$@"`
eval set -- "$TEMP"

function Helptext {
	echo -ne "\t usage: qpWrapper.sh [options]\n\n"
	echo -ne "This programme will submit multiple qpWave/qpAdm runs, one for each Sample, with the rest of your Left and Right pops constant.\n\n"
	echo -ne "options:\n"
	echo -ne "-S, --Sample\t\tName of your sample. Can be provided multiple times.\n"
	echo -ne "-R, --Ref, --Right\tThe Right populations for your runs. Can be provided multiple times.\n"
	echo -ne "-L, --Left, --Source\tThe Left Pops of your runs. Your Sample will be the first Left pop, followed by these. Can be provided multiple times.\n"
	echo -ne "-D, --SubDir\tWhen provided, results will be placed in a subdirectory with the name provided within the result directory. Deeper paths can be provided by using '/'.\n"
	echo -ne "-a, \t\tWhen provided, the option 'allsnps: YES' will NOT be provided.\n"
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
		-a) ALLSNPS="FALSE"; shift 1;;
	*) echo -e "invalid option provided.\n"; Helptext; exit 1;;
    esac
done

if [[ "$ALLSNPS" == "FALSE" ]]; then
	OUTTYPE="$TYPE.NoAllSnps"
else
	OUTTYPE=$TYPE
fi

source ~/.qpWrapper.config
# # EDIT ONLY THIS PART
# INDIR=/projects1/AncientFinnish/Revision/data
# OUTDIR=/projects1/AncientFinnish/Revision #Subdirectories will be created within this directory to contain the results from the runs.
# GENO=$INDIR/L35.Mittnik.Saag.Jones.Data.geno
# SNP=$INDIR/L35.Mittnik.Saag.Jones.Data.snp
# IND=$INDIR/PattersonTests.ind
# # IND=$INDIR/L35.Mittnik.Saag.Jones.Data.Group.ind
# # IND=$INDIR/L35.Mittnik.Saag.Jones.Data.IceAgeClusters.ind
# # IND=$INDIR/L35.Mittnik.Saag.Jones.Data.ind
# # IND=$INDIR/L35.Mittnik.Saag.Jones.Data.Each.AllSaami
# #DONT EDIT BELOW HERE

OUTDIR2=$OUTDIR/$TYPE/$SUBDIR
mkdir -p $OUTDIR2/Logs
mkdir -p $OUTDIR2/.tmp

if [[ $HOSTNAME == mpi* ]] ; then
	SlurmPart="-p short "
else
	SlurmPart=""
fi

if [[ $TYPE == "qpWave" ]]; then
	unset SAMPLES
	SAMPLES+=""
	TEMPDIR=$(mktemp -d $OUTDIR2/.tmp/XXXXXXXX)
	POPLEFT=$TEMPDIR/Left
	printf "" >$POPLEFT
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
	if [[ "$ALLSNPS" != "FALSE" ]]; then
		printf "allsnps:\tYES\n" >>$PARAMSFILE
	fi
	LOG=$OUTDIR2/Logs/$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).log
	OUT=$OUTDIR2/$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).out
	# echo "OUT: $OUT"
	# echo "LOG: $LOG"
	# echo "LEFT: $POPLEFT"
	# echo "RIGHT: $POPRIGHT"
	# echo "PARAM: $PARAMSFILE"
	# echo "${SAMPLE}_$TYPE"
	sbatch $SlurmPart--job-name="${SAMPLE}_${SUBDIR}_$OUTTYPE" --mem=4000 -o $LOG --wrap="$TYPE -p $PARAMSFILE >$OUT"
fi

for SAMPLE in ${SAMPLES[@]}; do
	TEMPDIR=$(mktemp -d $OUTDIR2/.tmp/XXXXXXXX)
	POPLEFT=$TEMPDIR/Left
	if [[ "$SAMPLE" != "" ]]; then
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
	if [[ "$ALLSNPS" != "FALSE" ]]; then
		printf "allsnps:\tYES\n" >>$PARAMSFILE
	fi
	
	if [[ "$SAMPLE" != "" ]]; then
		LOG=$OUTDIR2/Logs/$SAMPLE.$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).log
		OUT=$OUTDIR2/$SAMPLE.$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).out
	else
		LOG=$OUTDIR2/Logs/$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).log
		OUT=$OUTDIR2/$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).out
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
	sbatch $SlurmPart--job-name="${SAMPLE}_${SUBDIR}_$OUTTYPE" --mem=4000 -o $LOG --wrap="$TYPE -p $PARAMSFILE >$OUT"
done

