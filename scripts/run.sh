#!/bin/bash

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
# - type of simulation
TYPE=${1}
shift
# - input file
INPUT_FILE=${1}
shift
# - number of events
EVENTS_PER_TASK=${1:-10000}
shift
# - current chunk
TASK=${1:-}
if [ -n "$TASK" ] ; then
  # increment since condor starts at 0
  TASK=$((TASK+1))
fi
shift

# determine directory this is being run from
BASEDIR=$(realpath $(dirname ${0}))

# find singularity
if [ -z "${SINGULARITY:-}" ] ; then
  if which singularity 2> /dev/null ; then
    SINGULARITY=$(which singularity)
  else
    SINGULARITY="/cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity"
  fi
fi
echo "Using SINGULARITY=${SINGULARITY}"

# use local eic-shell if it exists
if [ -z "${EICSHELL:-}" ] ; then
  # bind base dir for lustre symlinked systems
  BINDPATH="/$(realpath ${BASEDIR} | cut -d "/" -f2)"
  EICSHELL="singularity exec -B ${BASEDIR} /cvmfs/singularity.opensciencegrid.org/eicweb/jug_xl:nightly/ eic-shell"
fi
echo "Using EICSHELL=${EICSHELL}"

# dispatch job
cat << EOF | ${EICSHELL}

  /opt/campaigns/${TYPE}/scripts/run.sh ${INPUT_FILE} ${EVENTS_PER_TASK} ${TASK}

EOF

# closeout
date
