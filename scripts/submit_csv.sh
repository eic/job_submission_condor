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

# create command line
EXECUTABLE="$(dirname $0)/run.sh"
ARGUMENTS="EVGEN/\$(file) \$(ext) \$(nevents) \$(ichunk)"

# Set background environment variables
source $(dirname $0)/set_bg_mix_var.sh

# construct environment file
ENVIRONMENT=environment-$(date --iso-8601=minutes).sh

# extract certificate name
X509_USER_PROXY_BASE=$(basename ${X509_USER_PROXY:-})

sed "
  s|%COPYRECO%|${COPYRECO:-}|g;
  s|%COPYFULL%|${COPYFULL:-}|g;
  s|%COPYLOG%|${COPYLOG:-}|g;
  s|%USERUCIO%|${USERUCIO:-}|g;
  s|%X509_USER_PROXY%|${X509_USER_PROXY_BASE:-}|g;
  s|%TAG_PREFIX%|${TAG_PREFIX:-}|g;
  s|%TAG_SUFFIX%|${TAG_SUFFIX:-}|g;
  s|%DETECTOR_VERSION%|${DETECTOR_VERSION}|g;
  s|%DETECTOR_CONFIG%|${DETECTOR_CONFIG}|g;
  s|%EBEAM%|${EBEAM}|g;
  s|%PBEAM%|${PBEAM}|g;
  s|%VAC%|${VAC}|g;
  s|%SIG_FREQ%|${SIG_FREQ}|g;
  s|%BG1_FILE%|${BG1_FILE}|g;
  s|%BG1_FREQ%|${BG1_FREQ}|g;
  s|%BG1_SKIP%|${BG1_SKIP}|g;
  s|%BG2_FILE%|${BG2_FILE}|g;
  s|%BG2_FREQ%|${BG2_FREQ}|g;
  s|%BG2_SKIP%|${BG2_SKIP}|g;
  s|%BG3_FILE%|${BG3_FILE}|g;
  s|%BG3_FREQ%|${BG3_FREQ}|g;
  s|%BG3_SKIP%|${BG3_SKIP}|g;
" templates/${TEMPLATE}.sh.in > ${ENVIRONMENT}

# construct requirements
REQUIREMENTS=""

# construct input files
INPUT_FILES=${ENVIRONMENT},${X509_USER_PROXY}

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
  for i in `condor_q --batch | grep ^${USER} | tail -n1 | awk '{print($NF)}' | cut -d. -f1` ; do
    mkdir -p LOG/CONDOR/osg_$i/
  done
fi
