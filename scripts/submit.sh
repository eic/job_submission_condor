#!/bin/bash

# check arguments
if [ $# -lt 2 ] ; then
  echo "Usage: "
  echo "  $0 <input> [n_chunk=10000]"
  echo "  sbatch --array 1-<N> $0 <type> <input> [n_chunk=10000]"
  echo
  echo "This job is intended to be run as an array job:"
  echo "  sbatch --array 1-<N> $0 <type> <input> [n_chunk=10000]"
  echo "where N tasks of n_chunk events will be dispatched."
  echo
  echo "Note: The job with task ID 1 will start with the first event."
  echo
  echo "Additional useful options to sbatch are:"
  echo " --mail-user=$USER@$HOSTNAME"
  echo " --mail-type=ALL"
  echo
  echo "In interactive use, the number of events per task is still honored,"
  echo "but the sequence always starts from the first event."
  echo "  $0 <type> <input> [n_chunk=10000]"
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

# determine directory this is being run from
if [ -n "$SLURM_JOB_ID" ] ;  then
  BASEDIR=$(realpath ${SLURM_SUBMIT_DIR})
else
  BASEDIR=$(realpath $(dirname ${0}))
fi

# use local eic-shell if it exists
if [ -x ${BASEDIR}/eic-shell ] ; then
  EICSHELL=${BASEDIR}/eic-shell
else
  # bind base dir for lustre symlinked systems
  EICSHELL="singularity exec -B ${BASEDIR} /cvmfs/singularity.opensciencegrid.org/eicweb/jug_xl:nightly/ eic-shell"
fi

# dispatch job
cat << EOF | ${EICSHELL}

  /opt/campaigns/${TYPE}/scripts/run.sh ${INPUT_FILE} ${EVENTS_PER_TASK} ${SLURM_ARRAY_TASK_ID:-}

EOF

# closeout
date
