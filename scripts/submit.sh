#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# check arguments
if [ $# -lt 2 ] ; then
  echo "Usage: "
  echo "  $0 <template> <type> <input> [n_chunk=10000] [n_chunks=1]"
  echo
  echo "A typical npsim run requires from 0.5 to 5 core-seconds per event,"
  echo "and uses under 3 GB of memory. The output ROOT file for"
  echo "10k events take up about 2 GB in disk space."
  exit
fi

# startup
date

# Parse arguments
# - condor template
TEMPLATE_FILE=${1}
shift
# - type of simulation
TYPE=${1}
shift
# - input file
INPUT=${1}
shift
# - number of events per task
EVENTS_PER_TASK=${1:-10000}
shift
# - number of tasks
NUMBER_OF_TASKS=${1:-1}

# create command line
EXECUTABLE="./scripts/run.sh"
ARGUMENTS="${TYPE} ${INPUT} ${EVENTS_PER_TASK} \$(Process)"

# construct submission file
SUBMIT_FILE=$(basename ${TEMPLATE} .in).submit
sed "
  s|%EXECUTABLE%|${EXECUTABLE}|g;
  s|%ARGUMENTS%|${ARGUMENTS}|g;
  s|%QUEUE%|${NUMBER_OF_TASKS}|g;
  s|%JUGGLER_TAG%|${JUGGLER_TAG:-nightly}|g;
" ${TEMPLATE_FILE} > ${SUBMIT_FILE}

# submit job
condor_submit ${SUBMIT_FILE}
