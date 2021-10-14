#!/bin/bash

# check arguments
if [ $# -lt 2 ] ; then
  echo "Usage: "
  echo "  $0 <template> <type> <file or url> [target hours = 2]"
  exit
fi

# Project configuration
BASEURL="https://eicweb.phy.anl.gov/api/v4/projects/491/jobs/artifacts/main/raw/results/datasets/timings/"
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

# Parse input URI
if [ -f "${FILE}" ] ; then
  INPUT="cat ${FILE}"
else
  INPUT="curl ${BASEURL}${FILE}${BASEJOB}"
fi

# Loop over input
${INPUT} | grep -v ^curl | while IFS="," read file ntotal dt0 dt1 ; do
  nevents=$(echo "n=(3600*$TARGET-$dt0)/$dt1; if (n>$ntotal) print($ntotal) else print(n)" | bc)
  nchunks=$(echo "n=$ntotal/$nevents; if (n==0) print(1) else print(n)" | bc)
  $(dirname $0)/submit.sh ${TEMPLATE} ${TYPE} ${file} ${nevents} ${nchunks}
done
