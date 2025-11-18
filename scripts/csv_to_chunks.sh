#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# check arguments
if [ $# -lt 2 ] ; then
  echo "Usage: "
  echo "  $0 <file or url> [target hours = 2]"
  exit
fi

# Parse arguments
# - input file
FILE=${1}
shift
# - target hours
TARGET=${1:-2}
shift

# Parse input URI
if [ -f "${FILE}" ] ; then
  echo "Using local file as input" 1>&2
  INPUT=(cat ${FILE})
else
  echo "Using ${BASEURL}${FILE}${BASEJOB} as input" 1>&2
  INPUT=(curl ${BASEURL}${FILE}${BASEJOB})
fi

# Output file
output=$(basename ${FILE} .csv)-$(date --iso-8601=minutes).csv

# Loop over input
"${INPUT[@]}" | grep -v ^curl | while IFS="," read file ext ntotal dt0 dt1 duf0 duf1 dur0 dur1 ; do
  if [[ "${file}" =~ csv$ ]] ; then
    ${0} ${TEMPLATE} ${TYPE} ${file} ${TARGET}
  else
    nevents=$(echo "scale=0; n=(3600*$TARGET-$dt0)/$dt1; if (n>$ntotal) print($ntotal) else print(n)" | bc -l)
    nchunks=$(echo "scale=0; n=$ntotal/$nevents+1; if (n==0) print(1) else print(n)" | bc -l)
    nevents=$(echo "scale=0; $ntotal/$nchunks" | bc -l)
    actualt=$(echo "scale=2; ($dt0+$nevents*$dt1)/3600" | bc -l)
    for ichunk in `seq 0 $((nchunks-1))` ; do
      echo "${file},${ext},${nevents},$(printf '%04d' $ichunk)"
    done
  fi
done > ${output}
echo "${output}"
