#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# check arguments
if [ $# -lt 2 ] ; then
  echo "Usage: "
  echo "  $0 <type> <input> [n_chunk=10000] [i_chunk=]"
  echo
  echo "A typical npsim run requires from 0.5 to 5 core-seconds per event,"
  echo "and uses under 3 GB of memory. The output ROOT file for"
  echo "10k events take up about 2 GB in disk space."
  exit
fi

# startup
date

# Parse arguments
# - input file basename
INPUT_FILE_BASENAME=${1}
shift
# - input file extension to determine type of simulation 
EXTENSION=${1}
shift
# - number of events
EVENTS_PER_TASK=${1:-10000}
shift
# - current chunk
TASK=${1:-}
shift

# clone repo
if [ -n "${CAMPAIGNS:-}" ] ; then
  if [ -z "${CAMPAIGNS/http*/}" ] ; then
    echo "cloning ${CAMPAIGNS}"
    git clone ${CAMPAIGNS} campaigns
    CAMPAIGNS="campaigns"
  fi
fi

# dispatch job
${CAMPAIGNS:-/opt/campaigns/hepmc3}/scripts/run.sh ${INPUT_FILE_BASENAME} ${EXTENSION} ${EVENTS_PER_TASK} ${TASK}

# closeout
date
