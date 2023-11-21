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

# environment variable to indicate whether the job is running on condor or slurm
SYSTEM=${SYSTEM:-condor}

# process csv file into jobs
if [ -n "${CSV_FILE:-}" ]; then
  # allow to set custom csv file for job instead of fetching from web archive
  CSV_FILE=$(realpath -e ${CSV_FILE})                     
else
  CSV_FILE=$($(dirname $0)/csv_to_chunks.sh ${FILE} ${TARGET})
fi

# create command line
EXECUTABLE="$PWD/scripts/run.sh"
if [ ${SYSTEM} = "condor" ]; then
  ARGUMENTS="${TYPE} EVGEN/\$(file).\$(ext) \$(nevents) \$(ichunk)"
elif [ ${SYSTEM} = "slurm" ]; then
  ARGUMENTS="${TYPE}"
  # FIXME: This is not ideal. It prevents from submitting multiple jobs with different JUG_XL_TAG simultaneously.
  cd scripts 
  wget --output-document install.sh https://get.epic-eic.org
  sed -i 's/nightly/${JUG_XL_TAG}/g' install.sh
  bash install.sh
  cd ..
else
  echo "Enter a valid SYSTEM value (condor or slurm)"
fi

# construct environment file
ENVIRONMENT=environment-$(date --iso-8601=minutes).sh
sed "
  s|%S3_ACCESS_KEY%|${S3_ACCESS_KEY:-}|g;
  s|%S3_SECRET_KEY%|${S3_SECRET_KEY:-}|g;
  s|%S3RW_ACCESS_KEY%|${S3RW_ACCESS_KEY:-}|g;
  s|%S3RW_SECRET_KEY%|${S3RW_SECRET_KEY:-}|g;
  s|%DETECTOR_VERSION%|${DETECTOR_VERSION}|g;
  s|%DETECTOR_CONFIG%|${DETECTOR_CONFIG}|g;
  s|%EBEAM%|${EBEAM}|g;
  s|%PBEAM%|${PBEAM}|g;
" templates/${TEMPLATE}.sh.in > ${ENVIRONMENT}

# construct requirements
REQUIREMENTS=""

# construct input files
INPUT_FILES=${ENVIRONMENT}

# calculate number of jobs being submitted
NJOBS=$( wc -l ${CSV_FILE} | awk '{print $1}' )

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
  s|%ACCOUNT%|${ACCOUNT:-rrg-wdconinc}|g;
  s|%CAMPAIGN_LOG%|${CAMPAIGN_LOG:-$PWD}|g;
  s|%TARGET%|$TARGET|g;
  s|%NJOBS%|${NJOBS}|g;
" templates/${TEMPLATE}.submit.in > ${SUBMIT_FILE}

# submit job

echo "Submitting ${NJOBS} to a ${SYSTEM} system"

if [ ${SYSTEM} = "condor" ]; then
  condor_submit -verbose -file ${SUBMIT_FILE}

  # create log dir
  if [ $? -eq 0 ] ; then
    for i in `condor_q | grep ^${USER} | tail -n1 | awk '{print($NF)}' | cut -d. -f1` ; do
      mkdir -p ${CAMPAIGN_LOG:-$PWD}/LOG/CONDOR/osg_$i/
    done
  fi
elif [ ${SYSTEM} = "slurm" ]; then
  sbatch ${SUBMIT_FILE}

  # create log dir
  if [ $? -eq 0 ] ; then
    for i in `squeue -u ${USER} | tail -n1 |  awk '{$1=$1; print}' | awk -F" |_" '{print($1)}' | cut -d. -f1` ; do
      mkdir -p ${CAMPAIGN_LOG:-$PWD}/LOG/SLURM/slurm_$i/
    done
  fi
else
  echo "Enter a valid SYSTEM value (condor or slurm)"
fi
