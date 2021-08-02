#!/usr/bin/env bash
VERSION="0.1.2"

## Function that takes an element and a list and returns the contents of that list without the specified element.
function exclude_element() { idx=$1; shift 1; arr=($*); new_arr=(${arr[@]:0:${idx}} ${arr[@]:((${idx}+1)):${#arr[@]}}); echo ${new_arr[@]}; }

## Parse CLI args.
TEMP=`getopt -q -o hArvtS:R:L:D:a:c: --long help,rotating,version,test,Sample:,Right:,Ref:,Left:,Source:,SubDir:,array:,chrom: -n 'qpWrapper.sh' -- "$@"`
eval set -- "$TEMP"

## Debugging
# echo $TEMP

## Helptext function
function Helptext {
    echo -ne "\t usage: qpWrapper.sh [options] (qpWave|qpAdm)\n\n"
    echo -ne "This programme will submit multiple qpWave/qpAdm runs, one for each Sample, with the rest of your Left and Right pops constant.\n\n"
    echo -ne "options:\n"
    echo -ne "-h, --help\t\tPrint this text and exit.\n"
    echo -ne "-S, --Sample\t\tName of your sample. Can be provided multiple times.\n"
    echo -ne "-R, --Ref, --Right\tThe Right populations for your runs. Can be provided multiple times.\n"
    echo -ne "-L, --Left, --Source\tThe Left Pops of your runs. Your Sample will be the first Left pop, followed by these. Can be provided multiple times.\n"
    echo -ne "-D, --SubDir\t\tWhen provided, results will be placed in a subdirectory with the name provided within the result directory. Deeper paths can be provided by using '/'.\n"
    echo -ne "-A, \t\t\tWhen provided, the option 'allsnps: YES' will NOT be provided.\n"
    echo -ne "-c, --chrom \t\tWhen provided, qpWave/qpAdm will only use snps from the specified chromosome. Chromosome names in eigenstrat format are integers.\n"    
    echo -ne "-r, --rotating \t\tWhen provided and submitting qpAdm runs, qpWrapper will submit 'rotating' models, where all Sample populations except the one currently tested are added\n\t\t\t\tto the end of the Right poplations.\n"
    echo -ne "-a, --array \t\tWhen provided, the qpAdm jobs will be submitted in a slurm array instead. The number of jobs to run simultaneously should be provided to this option.\n"
    echo -ne "-t, --test \t\tUsed to test the commands to be submitted. Instead of submitting them, qpWrapper will simply print them, while still creating the required files. \n\t\t\t\tUseful for troubleshooting and integrating with broader pipelines.\n"
    echo -ne "-v, --version \t\tPrint qpWrapper version and exit.\n"
}

if [ $? -ne 0 ]
then
    Helptext
fi

## Submit jobs outside of an array, unless -a/--array is provided with a parameter
Submission="Jobs"

## Regex to check that --array option accepts only positive integers.
re='^[0-9]+$'

## Read in CLI arguments
while true ; do
    case "$1" in
        -S|--Sample) SAMPLES+=("$2"); shift 2;;
        -R|--Ref|--Right) RIGHTS+=("$2") ; shift 2;;
        -L|--Left|--Source) LEFTS+=("$2"); shift 2;;
        -D|--SubDir) SUBDIR="$2"; shift 2;;
        --) TYPE=$2 ;shift 2; break ;;
        -h|--help) Helptext; exit 0 ;;
        -c|--chrom) set_chrom="$2"; shift 2;;
        -A) ALLSNPS="FALSE"; shift 1;;
        -r|--rotating) Rotating="TRUE"; shift 1;;
        -t|--test) dry_run="TRUE"; shift 1;;
        -v|--version) echo ${VERSION}; exit 0;;
        ## When --array is specified, check that parameter is an integer, else throw an error.
        -a|--array)
          # echo "Option -a/--array specified!"
          Submission="Array"; 
          if [[ $2 =~ $re ]]; then 
            num_simultaneous_jobs="$2" 
          else 
            echo "Invalid parameter '$2' specified to --array option"
            exit 2
          fi
          shift 2;;
    *) echo -e "invalid option provided.\n"; Helptext; exit 1;;
    esac
done

## Set output file name based on option selection.
if [[ "$ALLSNPS" == "FALSE" ]]; then
    OUTTYPE="$TYPE.NoAllSnps"
else
    OUTTYPE=$TYPE
fi

if [[ "$Rotating" == "TRUE" ]]; then
    OUTTYPE="$OUTTYPE.rotating"
else
    OUTTYPE="$OUTTYPE"
fi

## Read in variable assignments from ~/.qpWrapper.config
source ~/.qpWrapper.config

## Make the output dir/subdir if they don't exist.
OUTDIR2=$OUTDIR/$TYPE/$SUBDIR
mkdir -p $OUTDIR2/Logs
mkdir -p $OUTDIR2/.tmp

## Always submit to short queue
SlurmPart="-p short "
# if [[ $HOSTNAME == mpi* ]] ; then
#     SlurmPart="-p short "
# else
#     SlurmPart=""
# fi

unset job_commands

if [[ $TYPE == "qpWave" ]]; then
    unset SAMPLES
    SAMPLES+=""
    ## Make a temp directory and populate Left and Right pop lists.
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
    
    ## Make the params file
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
    if [[ ! -z ${set_chrom+x} ]]; then
      printf "chrom:\t${set_chrom}\n" >> $PARAMSFILE
    fi
    
    ## Submit qpWave job to slurm
    LOG=$OUTDIR2/Logs/$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).log
    OUT=$OUTDIR2/$LEFTS.${RIGHTS[0]}.${RIGHTS[1]}.$OUTTYPE.$(basename $TEMPDIR).out
    # echo "OUT: $OUT"
    # echo "LOG: $LOG"
    # echo "LEFT: $POPLEFT"
    # echo "RIGHT: $POPRIGHT"
    # echo "PARAM: $PARAMSFILE"
    # echo "${SAMPLE}_$TYPE"
    if [[ "${dry_run}" == "TRUE" ]]; then
        echo "$TYPE -p $PARAMSFILE >$OUT"
    else
        sbatch $SlurmPart--job-name="${SAMPLE}_${SUBDIR}_$OUTTYPE" --mem=4000 -o $LOG --wrap="$TYPE -p $PARAMSFILE >$OUT"
    fi
fi

## If submittiing to a alurm array, create a temp dir for the array and the filename to the command file.
if [[ ${Submission} == "Array" ]]; then
  array_dir=$(mktemp -d $OUTDIR2/.tmp/array_XXXXXX)
  command_file="${array_dir}/slurm_commands"
fi

if [[ $TYPE == "qpAdm" ]]; then
  for idx in ${!SAMPLES[@]}; do
    SAMPLE=${SAMPLES[${idx}]} ## SAMPLE is now set by index due to implementation of rotating models.
    
    ## If rotating models are requested, create a list of all SAMPLES except the current one and append it to the RIGHTS to make the list of Reference populations.
    if [[ "$Rotating" == "TRUE" ]]; then
      Unused_Samples=($(exclude_element ${idx} ${SAMPLES[@]}))
      REFS=(${RIGHTS[@]} ${Unused_Samples[@]})
    else
      REFS=(${RIGHTS[@]})
    fi
##    DEBUG
#     echo "SAMPLE: ${SAMPLE}"
#     echo "LEFTS:  ${LEFTS[@]}"
#     echo "RIGHTS: ${RIGHTS[@]}"
#     echo "REFS:   ${REFS[@]}"
#     echo ""
# done
# exit 0
    ## Make a temp directory and populate Left and Right pop lists.
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
    for REF in ${REFS[@]}; do
      printf "$REF\n" >>$POPRIGHT
    done
    
    ## Make the params file
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
    if [[ ! -z ${set_chrom+x} ]]; then
      printf "chrom:\t${set_chrom}\n" >> $PARAMSFILE
    fi
    
    if [[ "$SAMPLE" != "" ]]; then
      LOG=$OUTDIR2/Logs/$SAMPLE.$LEFTS.${REFS[0]}.${REFS[1]}.$OUTTYPE.$(basename $TEMPDIR).log
      OUT=$OUTDIR2/$SAMPLE.$LEFTS.${REFS[0]}.${REFS[1]}.$OUTTYPE.$(basename $TEMPDIR).out
    else
      LOG=$OUTDIR2/Logs/$LEFTS.${REFS[0]}.${REFS[1]}.$OUTTYPE.$(basename $TEMPDIR).log
      OUT=$OUTDIR2/$LEFTS.${REFS[0]}.${REFS[1]}.$OUTTYPE.$(basename $TEMPDIR).out
    fi
    if [[ $SAMPLE == "" && $TYPE == "qpAdm" ]]; then
      continue
    fi
    
    ## If array submission is specified, print all commands that would be ran into a file. esle submit each command as its own job.
    if [[ "${dry_run}" == "TRUE" ]]; then
      echo "$TYPE -p $PARAMSFILE >$OUT 2>$LOG"
    elif [[ ${Submission} == "Array" ]]; then
      echo "$TYPE -p $PARAMSFILE >$OUT 2>$LOG" >> ${command_file}
    ## DEBUG
    # echo "OUT: $OUT"
    # echo "LOG: $LOG"
    # echo "LEFT: $POPLEFT"
    # echo "RIGHT: $POPRIGHT"
    # echo "PARAM: $PARAMSFILE"
    # echo "${SAMPLE}_$TYPE"
    else
      sbatch $SlurmPart--job-name="${SAMPLE}_${SUBDIR}_$OUTTYPE" --mem=4000 -o $LOG --wrap="$TYPE -p $PARAMSFILE >$OUT"
    fi
  done
  
  ## If array submission is specified, submit as an array job.
  if [[ ${Submission} == "Array" ]]; then
    # touch ${log_files[@]} ${output_files[@]}
    max_array_index=$(bc <<< "$(wc -l ${command_file}| cut -f 1 -d ' ') - 1" )
    sbatch $SlurmPart--job-name="${array_dir#*/}.${SUBDIR}.${OUTTYPE}" \
      --mem=4GB -c1  -a 0-${max_array_index}%${num_simultaneous_jobs} \
      --export=command_file=${command_file}\
      -o "${array_dir}/%A_%a.log" \
      <<- 'END'
		#!/usr/bin/env bash
		while read line; do
			job_commands+=("${line}")
			# echo $line
		done < ${command_file}
		for i in ${params_files[@]}; do
			echo $i
		done
		current_command="${job_commands[${SLURM_ARRAY_TASK_ID}]}"
		# echo ${command_file}
		# echo ''
		# echo ${job_commands[0]}
		# echo ''
		# echo "bash -c ${current_command}"
		bash -c "${current_command}"
		END
  fi
fi
