#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# check arguments
if [ $# -lt 2 ] ; then
  echo "Usage: "
  echo "  $0 <template> <type> <file or url> [target hours = 2]"
  exit
fi

# Project configuration
BASEURL="https://eicweb.phy.anl.gov/api/v4/projects/491/jobs/artifacts/${DETECTOR_VERSION:-main}/raw/results/datasets/timings/"
BASEJOB="?job=collect"

# Parse arguments
# - condor template
TEMPLATE=${1}
shift
# - type of simulation
TYPE=${1}
shift
# - input file
FILE=${1}
shift
# - target hours
TARGET=${1:-2}
shift

# process csv file into jobs
if [ -n "${CSV_FILE:-}" ]; then
  # allow to set custom csv file for job instead of fetching from web archive
  CSV_FILE=$(realpath -e ${CSV_FILE})
else
  CSV_FILE=$($(dirname $0)/csv_to_chunks.sh ${FILE} ${TARGET})
fi

# number of jobs (zero-based)
NUM_JOBS=$(wc -l ${CSV_FILE} | cut -f1 -d\ )
let NUM_JOBS=${NUM_JOBS}-1
echo ${NUM_JOBS}

# create command line
EXECUTABLE="$(dirname $0)/run.sh"
ARGUMENTS="EVGEN/\$(file) \$(ext) \$(nevents) \$(ichunk)"

# construct environment file
ENVIRONMENT=environment-$(date --iso-8601=minutes).sh
sed "
  s|%COPYRECO%|${COPYRECO:-}|g;
  s|%COPYFULL%|${COPYFULL:-}|g;
  s|%COPYLOG%|${COPYLOG:-}|g;
  s|%DETECTOR_VERSION%|${DETECTOR_VERSION}|g;
  s|%DETECTOR_CONFIG%|${DETECTOR_CONFIG}|g;
  s|%EBEAM%|${EBEAM}|g;
  s|%PBEAM%|${PBEAM}|g;
" templates/${TEMPLATE}.sh.in > ${ENVIRONMENT}

# construct requirements
REQUIREMENTS=""

# construct input files
INPUT_FILES=${ENVIRONMENT}

# construct submission file
SUBMIT_FILE=$(basename ${CSV_FILE} .csv).submit
sed "
  s|%EXECUTABLE%|${EXECUTABLE}|g;
  s|%ARGUMENTS%|${ARGUMENTS}|g;
  s|%JUG_XL_TAG%|${JUG_XL_TAG:-nightly}|g;
  s|%DETECTOR_VERSION%|${DETECTOR_VERSION}|g;
  s|%DETECTOR_CONFIG%|${DETECTOR_CONFIG}|g;
  s|%INPUT_FILES%|${INPUT_FILES}|g;
  s|%REQUIREMENTS%|${REQUIREMENTS}|g;
  s|%CSV_FILE%|${CSV_FILE}|g;
" templates/${TEMPLATE}.submit.in > ${SUBMIT_FILE}

# submit job
if [[ ${TEMPLATE} =~ slurm ]] ; then

  # slurm
  max_array_size=2000
  while [ ${NUM_JOBS} -ge 0 ] ; do
    let taskN=${NUM_JOBS}
    let task0=${NUM_JOBS}-${max_array_size}+1
    if [ ${task0} -lt 0 ] ; then task0=0 ; fi
    echo sbatch --array=${task0}-${taskN} ${SUBMIT_FILE}
    let NUM_JOBS=${NUM_JOBS}-${max_array_size}
  done

else

  # condor
  condor_submit -verbose -file ${SUBMIT_FILE}

  # create log dir
  if [ $? -eq 0 ] ; then
    for i in `condor_q --batch | grep ^${USER} | tail -n1 | awk '{print($NF)}' | cut -d. -f1` ; do
      mkdir -p LOG/CONDOR/osg_$i/
    done
  fi

fi
