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
CSV_FILE=$($(dirname $0)/csv_to_chunks.sh ${FILE} ${TARGET})

# create command line
EXECUTABLE="./scripts/run.sh"
ARGUMENTS="${TYPE} EVGEN/\$(file).\$(ext) \$(nevents) \$(ichunk)"

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
condor_submit -verbose -file ${SUBMIT_FILE}

# create log dir
if [ $? -eq 0 ] ; then
  for i in `condor_q | grep ^${USER} | tail -n1 | awk '{print($NF)}' | cut -d. -f1` ; do
    mkdir -p LOG/CONDOR/osg_$i/
  done
fi
