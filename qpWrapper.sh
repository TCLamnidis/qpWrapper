#!/bin/env bash
VERSION="1.1.2"

## Function to echo to stderr
function errecho() { echo $* 1>&2 ;}

## Function that takes an element and a list and returns the contents of that list without the specified element.
function exclude_element() { idx=$1; shift 1; arr=($*); new_arr=(${arr[@]:0:${idx}} ${arr[@]:((${idx}+1)):${#arr[@]}}); echo ${new_arr[@]}; }

function infer_output_suffix() {
  local type=$1
  local all_snps=$2
  local rotation=$3
  local outtype=''
  
  if [[ ${all_snps} == "FALSE" ]]; then
      outtype=".NoAllSnps"
  fi
  if [[ ${type} == "qpAdm" && ${rotation} == "TRUE" ]]; then
      outtype+=".rotating"
  fi
  echo ${outtype}
}

function beta_qpWave() {
  local -n _RIGHTS=$1
  local -n _LEFTS=$2
  local _ALL_SNPS=$3
  local _set_chrom=$4
  local _dry_run=$5
  local _isRotating=$6
  local _debug=$7
  local _inbreed=$8
  local _output_suffix=$(infer_output_suffix qpWave ${_ALL_SNPS} ${_isRotating})
  
  if [[ ${_debug} == "TRUE" ]]; then
    ##    DEBUG
    errecho -e "\nqpWave function"
    errecho "_LEFTS:     ${_LEFTS[@]}"
    errecho "_RIGHTS:    ${_RIGHTS[@]}"
    errecho "_ALLSNPS:   ${_ALL_SNPS}"
    errecho "_CHROM:     ${_set_chrom}"
    errecho "_TEST:      ${_dry_run}"
    errecho "_OUT_TYPE:  ${_output_suffix}"
    errecho "_dry_run:   ${_dry_run}"
    errecho "_inbreed:   ${_inbreed}"
  fi
  
  ## Create temp dir for run
  TEMPDIR=$(mktemp -d $OUTDIR2/.tmp/XXXXXXXX)
  ## File name for Leftpops
  POPLEFT=$TEMPDIR/Left
  ## Create empty file and populate it with all Left pops
  printf "" >$POPLEFT
  for POP in ${_LEFTS[@]}; do
      printf "$POP\n" >>$POPLEFT
  done
  
  ## File name for Rightpops
  POPRIGHT=$TEMPDIR/Right
  ## Create empty file and populate it with all Right pops
  printf "" >$POPRIGHT
  for REF in ${_RIGHTS[@]}; do
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
  if [[ "${_ALL_SNPS}" != "FALSE" ]]; then
      printf "allsnps:\tYES\n" >>$PARAMSFILE
  fi 
  if [[ "${_inbreed}" != "FALSE" ]]; then
      printf "inbreed:\tYES\n" >>$PARAMSFILE
  else
      printf "inbreed:\tNO\n" >>$PARAMSFILE
  fi
  if [[ ${_set_chrom} != "0" ]]; then
    printf "chrom:\t${_set_chrom}\n" >> $PARAMSFILE
  fi
  
  ## Submit qpWave job to slurm
  LOG=$OUTDIR2/Logs/$_LEFTS.${_RIGHTS[0]}.${_RIGHTS[1]}${_output_suffix}.$(basename $TEMPDIR).log
  OUT=$OUTDIR2/$_LEFTS.${_RIGHTS[0]}.${_RIGHTS[1]}${_output_suffix}.$(basename $TEMPDIR).out
  # echo "OUT: $OUT"
  # echo "LOG: $LOG"
  # echo "LEFT: $POPLEFT"
  # echo "RIGHT: $POPRIGHT"
  # echo "PARAM: $PARAMSFILE"
  # echo "${SAMPLE}_$TYPE"
  if [[ "${_dry_run}" == "TRUE" ]]; then
      echo "$TYPE -p $PARAMSFILE >$OUT 2>$LOG"
  else
      qsub -V -b y -cwd -pe smp 1 -l h_vmem=4G -j y -o $LOG -N "qpWave.${SUBDIR//\//-}${_output_suffix}" "$TYPE -p $PARAMSFILE >$OUT"
  fi
}

function beta_qpAdm() {
  local _SAMPLE=$1
  local -n _REFS=$2
  local -n _SOURCES=$3
  local _ALL_SNPS=$4
  local _set_chrom=$5
  local _dry_run=$6
  local _rotation=$7
  local _debug=$8
  local _inbreed=$9
  local _output_suffix=$(infer_output_suffix qpAdm ${_ALL_SNPS} ${_rotation})
  
  if [[ ${_debug} == "TRUE" ]]; then
    ##    DEBUG
    errecho -e "\nqpAdm function"
    errecho "_SAMPLE:  ${_SAMPLE}"
    errecho "_SOURCES: ${_SOURCES[@]}"
    errecho "_REFS:    ${_REFS[@]}"
    errecho "_ALLSNPS: ${_ALL_SNPS}"
    errecho "_CHROM:   ${_set_chrom}"
    errecho "_TEST:    ${_dry_run}"
    errecho "OUTTYPE:  ${_output_suffix}"
    errecho "ROTATING: ${_rotation}"
    errecho "_inbreed:   ${_inbreed}"
  fi
  
  ## Make a temp directory and populate Left and Right pop lists.
  TEMPDIR=$(mktemp -d $OUTDIR2/.tmp/XXXXXXXX)
  POPLEFT=$TEMPDIR/Left
  if [[ "$_SAMPLE" != "" ]]; then
    printf "$_SAMPLE\n" >$POPLEFT
  else
    printf "" >$POPLEFT
  fi
  for POP in ${_SOURCES[@]}; do
    printf "$POP\n" >>$POPLEFT
  done
  
  POPRIGHT=$TEMPDIR/Right
  printf "" >$POPRIGHT
  for REF in ${_REFS[@]}; do
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
  if [[ "${_ALL_SNPS}" != "FALSE" ]]; then
    printf "allsnps:\tYES\n" >>$PARAMSFILE
  fi
  if [[ "${_inbreed}" != "FALSE" ]]; then
    printf "inbreed:\tYES\n" >>$PARAMSFILE
  else
      printf "inbreed:\tNO\n" >>$PARAMSFILE
  fi
  if [[ ${_set_chrom} != "0" ]]; then
    printf "chrom:\t${_set_chrom}\n" >> $PARAMSFILE
  fi

  if [[ "$_SAMPLE" != "" ]]; then
    LOG=$OUTDIR2/Logs/$_SAMPLE.${_SOURCES}.${_REFS[0]}.${_REFS[1]}${_output_suffix}.$(basename $TEMPDIR).log
    OUT=$OUTDIR2/$_SAMPLE.${_SOURCES}.${_REFS[0]}.${_REFS[1]}${_output_suffix}.$(basename $TEMPDIR).out
  else
    LOG=$OUTDIR2/Logs/${_SOURCES}.${_REFS[0]}.${_REFS[1]}${_output_suffix}.$(basename $TEMPDIR).log
    OUT=$OUTDIR2/${_SOURCES}.${_REFS[0]}.${_REFS[1]}${_output_suffix}.$(basename $TEMPDIR).out
  fi

  ## If array submission is specified, print all commands that would be ran into a file. else submit each command as its own job.
  if [[ "${dry_run}" == "TRUE" ]]; then
    echo "$TYPE -p $PARAMSFILE >$OUT 2>$LOG"
  # elif [[ ${Submission} == "Array" ]]; then
  #   echo "$TYPE -p $PARAMSFILE >$OUT 2>$LOG" >> ${command_file}
  ## DEBUG
  # echo "OUT: $OUT"
  # echo "LOG: $LOG"
  # echo "LEFT: $POPLEFT"
  # echo "RIGHT: $POPRIGHT"
  # echo "PARAM: $PARAMSFILE"
  # echo "${_SAMPLE}_$TYPE"
  else
    qsub -V -b y -cwd -pe smp 1 -l h_vmem=4G -j y -o $LOG -N "qpAdm.${_SAMPLE}_${SUBDIR//\//-}${_output_suffix}" "$TYPE -p $PARAMSFILE >$OUT"
  fi
}

## Parse CLI args.
TEMP=`getopt -q -o dhAivtS:R:r:L:D:a:c: --long debug,help,version,test,Sample:,Right:,Ref:,rotating:,Left:,Source:,SubDir:,array:,chrom: -n 'qpWrapper.sh' -- "$@"`
eval set -- "$TEMP"

## DEBUG
# echo $TEMP

## Helptext function
function Helptext() {
  echo -ne "\t usage: qpWrapper.sh [options] (qpWave|qpAdm)\n\n"
  echo -ne "This programme will submit multiple qpWave/qpAdm runs, one for each Sample, with the rest of your Left and Right pops constant.\n\n"
  echo -ne "Options:\n"
  echo -ne "-h, --help\t\tPrint this text and exit.\n"
  echo -ne "-S, --Sample\t\tName of your sample. Should correspond to the populations name of your sample in the '.ind' file. Can be provided multiple times.\n"
  echo -ne "-R, --Ref, --Right\tThe Right populations for your runs. Can be provided multiple times.\n"
  echo -ne "-L, --Left, --Source\tThe Left populations for your runs. For qpAdm, each Sample will be the first Left pop, followed by these. Can be provided multiple times.\n"
  echo -ne "-r, --rotating \t\tPopulations to 'rotate' from the Lefts to the Rights. When provided, qpWrapper will submit multiple runs, each with one of the rotating populations\n\t\t\t\tadded to the Lefts while the rest are added to the end of the list of Rights. Can be provided multiple times.\n"
  echo -ne "-D, --SubDir\t\tWhen provided, results will be placed in a subdirectory with the name provided within the result directory. Deeper paths can be provided by using '/'.\n"
  echo -ne "-A, \t\t\tWhen provided, the option 'allsnps: YES' will NOT be provided.\n"
  echo -ne "-i, \t\t\tWhen provided, the option 'inbreed: YES' will NOT be provided.\n"
  echo -ne "-c, --chrom \t\tWhen provided, qpWave/qpAdm will only use snps from the specified chromosome. Chromosome names in eigenstrat format are integers.\n"    
  # echo -ne "-a, --array \t\tWhen provided, the qpAdm jobs will be submitted in a slurm array instead. The number of jobs to run simultaneously should be provided to this option.\n"
  echo -ne "-t, --test \t\tUsed to test the commands to be submitted. Instead of submitting them, qpWrapper will simply print them, while still creating the required files. \n\t\t\t\tUseful for troubleshooting and integrating with broader pipelines.\n"
  echo -ne "-v, --version \t\tPrint qpWrapper version and exit.\n"
  echo -ne "-d, --debug \t\tRun while printing debug information.\n"
}

## Regex to check that --array option accepts only positive integers.
re='^[0-9]+$'

## Default parameter values
TYPE="NONE"
set_chrom="0"
ALLSNPS="TRUE"
dry_run="FALSE"
inbreed="TRUE"
debug="FALSE"

## Read in CLI arguments
while true ; do
  case "$1" in
    -S|--Sample) SAMPLES+=("$2"); shift 2;;
    -R|--Ref|--Right) RIGHTS+=("$2") ; shift 2;;
    -L|--Left|--Source) LEFTS+=("$2"); shift 2;;
    -r|--rotating) Rotating+=("$2"); shift 2;;
    -D|--SubDir) SUBDIR="$2"; shift 2;;
    --) TYPE=$2 ;shift 2; break ;;
    -h|--help) Helptext; exit 0 ;;
    -c|--chrom) set_chrom="$2"; shift 2;;
    -A) ALLSNPS="FALSE"; shift 1;;
    -i) inbreed="FALSE"; shift 1;;
    -t|--test) dry_run="TRUE"; shift 1;;
    -v|--version) echo ${VERSION}; exit 0;;
    -d|--debug) debug="TRUE"; shift 1;;
    ## When --array is specified, check that parameter is an integer, else throw an error.
    # -a|--array)
    #   # echo "Option -a/--array specified!"
    #   Submission="Array";
    #   if [[ $2 =~ $re ]]; then
    #     num_simultaneous_jobs="$2"
    #   else
    #     echo "Invalid parameter '$2' specified to --array option"
    #     exit 2
    #   fi
    #   shift 2;;
    *) echo -e "invalid option provided.\n"; Helptext; exit 1;;
  esac
done

## Read in variable assignments from ~/.qpWrapper.config
source ~/.qpWrapper.config

## Make the output dir/subdir if they don't exist.
OUTDIR2=$OUTDIR/$TYPE/$SUBDIR
mkdir -p $OUTDIR2/Logs
mkdir -p $OUTDIR2/.tmp

## Rotating models specified?
isRotating=$(if [[ ${#Rotating} == 0 ]]; then echo "FALSE"; else echo "TRUE"; fi)

if [[ $TYPE == "qpWave" ]]; then
  if [[ ${isRotating} == "TRUE" ]]; then
    for idx in ${!Rotating[@]}; do
      ## Rotate selected population to Lefts
      SOURCES=(${LEFTS[@]} ${Rotating[${idx}]})
      Rotate_Rights=($(exclude_element ${idx} ${Rotating[@]}))
      ## Rotate remaining rotating populations to the Rights
      REFS=(${RIGHTS[@]} ${Rotate_Rights[@]})
      
      if [[ ${debug} == "TRUE" ]]; then
        ##    DEBUG
        errecho -e "\nOut of function"
        errecho "SAMPLE:   ${SAMPLE}"
        errecho "LEFTS:    ${LEFTS[@]}"
        errecho "RIGHTS:   ${RIGHTS[@]}"
        errecho "Rotating: ${Rotating[@]}"
        errecho "ALLSNPS:  ${ALLSNPS}"
        errecho "CHROM:    ${set_chrom}"
        errecho "TEST:     ${dry_run}"
        errecho "REFS:     ${REFS[@]}"
        errecho "SOURCES:  ${SOURCES[@]}"
      fi
      beta_qpWave REFS SOURCES ${ALLSNPS} ${set_chrom} ${dry_run} ${isRotating} ${debug} ${inbreed}
    done
  else
    
    if [[ ${debug} == "TRUE" ]]; then
      ##    DEBUG
      errecho -e "\nOut of function"
      errecho "SAMPLE:  ${SAMPLE}"
      errecho "LEFTS:   ${LEFTS[@]}"
      errecho "RIGHTS:  ${RIGHTS[@]}"
      errecho "ALLSNPS: ${ALLSNPS}"
      errecho "CHROM:   ${set_chrom}"
      errecho "TEST:    ${dry_run}"
      errecho "INBREED: ${inbreed}"
    fi
    
    beta_qpWave RIGHTS LEFTS ${ALLSNPS} ${set_chrom} ${dry_run} ${isRotating} ${debug} ${inbreed}
  fi
elif [[ $TYPE == "qpAdm" ]]; then
  for SAMPLE in ${SAMPLES[@]}; do
    if [[ ${isRotating} == "TRUE" ]]; then
      for idx in ${!Rotating[@]}; do
        ## Rotate selected population to Lefts
        SOURCES=(${LEFTS[@]} ${Rotating[${idx}]})
        Rotate_Rights=($(exclude_element ${idx} ${Rotating[@]}))
        ## Rotate remaining rotating populations to the Rights
        REFS=(${RIGHTS[@]} ${Rotate_Rights[@]})
        
        if [[ ${debug} == "TRUE" ]]; then
          ##    DEBUG
          errecho -e "\nOut of function"
          errecho "SAMPLE:   ${SAMPLE}"
          errecho "LEFTS:    ${LEFTS[@]}"
          errecho "RIGHTS:   ${RIGHTS[@]}"
          errecho "Rotating: ${Rotating[@]}"
          errecho "ALLSNPS:  ${ALLSNPS}"
          errecho "CHROM:    ${set_chrom}"
          errecho "TEST:     ${dry_run}"
          errecho "REFS:     ${REFS[@]}"
          errecho "SOURCES:  ${SOURCES[@]}"
          errecho "INBREED: ${inbreed}"
        fi
        
        beta_qpAdm ${SAMPLE} REFS SOURCES ${ALLSNPS} ${set_chrom} ${dry_run} ${isRotating} ${debug} ${inbreed}
      done
    else
      if [[ ${debug} == "TRUE" ]]; then
        ##    DEBUG
        errecho -e "\nOut of function"
        errecho "SAMPLES:  ${SAMPLES[@]}"
        errecho "SAMPLE:   ${SAMPLE}"
        errecho "LEFTS:    ${LEFTS[@]}"
        errecho "RIGHTS:   ${RIGHTS[@]}"
        errecho "Rotating: ${Rotating[@]}"
        errecho "ALLSNPS:  ${ALLSNPS}"
        errecho "CHROM:    ${set_chrom}"
        errecho "TEST:     ${dry_run}"
        errecho "REFS:     ${REFS[@]}"
        errecho "SOURCES:  ${SOURCES[@]}"
        errecho "INBREED: ${inbreed}"
      fi
      beta_qpAdm ${SAMPLE} RIGHTS LEFTS ${ALLSNPS} ${set_chrom} ${dry_run} ${isRotating} ${debug} ${inbreed}
    fi
  done
else
  ## Throw error if user did not specify what analysis to run, or had a typo
  errecho "Invalid analysis type selected: '${TYPE}'"
  errecho -e "\nAcceptable values are: 'qpWave'/'qpAdm'\n"
  errecho "Execution halted"
  exit 1
fi