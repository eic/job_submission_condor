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
RESULTS=results/nightly/${DETECTOR_CONFIG:-epic_craterlake}/main
export BASEURL="https://eicweb.phy.anl.gov/api/v4/projects/491/jobs/artifacts/${DATASET_TAG:-main}/raw/${RESULTS}/datasets/timings/"
export BASEJOB="?job=collect"
BKGURL="https://eicweb.phy.anl.gov/EIC/campaigns/datasets/-/raw/${DATASET_TAG:-main}/config_data"

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

# USE_GPU and osg_csv_gpu template are equivalent; either implies the other
if [ -n "${USE_GPU:-}" ] || [ "${TEMPLATE}" = "osg_csv_gpu" ]; then
  USE_GPU=1
  TEMPLATE="osg_csv_gpu"
fi


SCRIPTS_DIR=$(dirname $0)
# process csv file into jobs
if [ -n "${CSV_FILE:-}" ]; then
  # allow to set custom csv file for job instead of fetching from web archive
  CSV_FILE=$(realpath -e ${CSV_FILE})
else
  CSV_FILE=$(${SCRIPTS_DIR}/csv_to_chunks.sh ${FILE} ${TARGET})
fi
CSV_BASE=$(basename ${CSV_FILE} .csv)

# create command line
EXECUTABLE="${SCRIPTS_DIR}/run.sh"
ARGUMENTS="EVGEN/\$(file) \$(ext) \$(nevents) \$(ichunk)"

# Set background environment variables
if [ -n "${BG_FILES:-}" ]; then
  curl -L -O ${BKGURL}/${BG_FILES}
fi

# construct environment file
ENVIRONMENT=environment-${CSV_BASE}.sh

# extract certificate name
X509_USER_PROXY_BASE=$(basename ${X509_USER_PROXY:-})

sed "
  s|%COPYRECO%|${COPYRECO:-}|g;
  s|%COPYFULL%|${COPYFULL:-}|g;
  s|%COPYLOG%|${COPYLOG:-}|g;
  s|%USERUCIO%|${USERUCIO:-}|g;
  s|%OUT_RSE%|${OUT_RSE:-}|g;
  s|%X509_USER_PROXY%|${X509_USER_PROXY_BASE:-}|g;
  s|%TAG_PREFIX%|${TAG_PREFIX:-}|g;
  s|%TAG_SUFFIX%|${TAG_SUFFIX:-}|g;
  s|%DETECTOR_VERSION%|${DETECTOR_VERSION}|g;
  s|%DETECTOR_CONFIG%|${DETECTOR_CONFIG}|g;
  s|%EBEAM%|${EBEAM}|g;
  s|%PBEAM%|${PBEAM}|g;
  s|%SIGNAL_FREQ%|${SIGNAL_FREQ:-}|g;
  s|%SIGNAL_STATUS%|${SIGNAL_STATUS:-}|g;
  s|%BG_FILES%|${BG_FILES:-}|g;
" templates/${TEMPLATE}.sh.in > ${ENVIRONMENT}

# construct requirements
REQUIREMENTS=""

# construct input files
INPUT_FILES=${ENVIRONMENT},${X509_USER_PROXY}
INPUT_FILES="${INPUT_FILES}${BG_FILES:+,${BG_FILES}}"

# construct submission file
SUBMIT_FILE=${CSV_BASE}.submit
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

if [ -n "${SUBMIT_CONDOR:-}" ]; then
  # submit job
  condor_submit -verbose -file ${SUBMIT_FILE}
  # create log dir
  if [ $? -eq 0 ] ; then
    for i in `condor_q --batch | grep ^${USER} | tail -n1 | awk '{print($NF)}' | cut -d. -f1` ; do
      mkdir -p LOG/CONDOR/osg_$i/
    done
  fi
else
  # PanDA mode - organize into directory
  SUBMISSION_DIR="${CSV_BASE}"
  mkdir -p ${SUBMISSION_DIR}

  # Count jobs before moving the CSV file
  NJOBS=$(grep . ${CSV_FILE} | wc -l)

  # Extract first file path from CSV and convert to dataset identifier
  FIRST_FILE=$(head -n1 ${CSV_FILE} | cut -d',' -f1)
  # Remove filename and keep directory path, then replace slashes with dots
  DATASET_PATH=${DETECTOR_VERSION}/${DETECTOR_CONFIG}${TAG_PREFIX:+/${TAG_PREFIX}}/$(dirname ${FIRST_FILE})
  DATASET_IDENTIFIER=${DATASET_PATH//\//.}
  DATASET_IDENTIFIER=${DATASET_IDENTIFIER//=/-}

  # Move generated files into submission directory
  mv ${ENVIRONMENT} ${SUBMISSION_DIR}/
  mv ${SUBMIT_FILE} ${SUBMISSION_DIR}/
  mv ${CSV_FILE} ${SUBMISSION_DIR}/

  # Copy scripts and external files
  cp ${SCRIPTS_DIR}/submit_panda.py ${SUBMISSION_DIR}/
  cp ${SCRIPTS_DIR}/submit_panda_api.py ${SUBMISSION_DIR}/
  [ -d "${SCRIPTS_DIR}/../celeritas" ] && cp -r ${SCRIPTS_DIR}/../celeritas ${SUBMISSION_DIR}/
  [ -n "${X509_USER_PROXY:-}" ] && cp ${X509_USER_PROXY} ${SUBMISSION_DIR}/
  [ -n "${BG_FILES:-}" ] && cp ${BG_FILES} ${SUBMISSION_DIR}/

  # Change into submission directory and run Python API submission
  cd ${SUBMISSION_DIR}

  # Build submission command with required parameters
  SUBMIT_CMD="python3 submit_panda_api.py \
    --exec \"python3 submit_panda.py %RNDM=0 ${CSV_BASE}\" \
    --nJobs ${NJOBS} \
    --outDS ${RUCIO_SCOPE:-group.EIC}.${DATASET_IDENTIFIER}"

  # Add optional overrides if environment variables are set
  [ -n "${PANDA_AUTH_VO:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --workingGroup ${PANDA_AUTH_VO}"
  [ -n "${PANDA_SITE:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --site ${PANDA_SITE}"
  [ -n "${PANDA_NCORE:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --nCore ${PANDA_NCORE}"
  [ -n "${PANDA_MEMORY:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --memory ${PANDA_MEMORY}"
  [ -n "${PANDA_DISK:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --disk ${PANDA_DISK}"
  if [ -n "${USE_GPU:-}" ]; then
    SUBMIT_CMD="$SUBMIT_CMD --useGPU --containerImage /cvmfs/singularity.opensciencegrid.org/eicweb/eic_dev_cuda:${JUG_XL_TAG:-nightly}"
  else
    [ -n "${JUG_XL_TAG:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --containerImage /cvmfs/singularity.opensciencegrid.org/eicweb/eic_xl:${JUG_XL_TAG}"
  fi
  [ -n "${PANDA_WALLTIME:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --walltime ${PANDA_WALLTIME}"
  [ -n "${PANDA_SKIP_SCOUT:-}" ] && SUBMIT_CMD="$SUBMIT_CMD --skipScout"

  eval $SUBMIT_CMD
fi
