#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# check arguments
if [ $# -lt 1 ] ; then
  echo "Usage: "
  echo "  $0 <resource>"
  exit
fi

TEMPLATE=osg_test

# Parse arguments
# - resource name
RESOURCENAME=${1}
shift

# create command line
EXECUTABLE="./scripts/run_osg_test.sh"
ARGUMENTS=""

# construct environment file
ENVIRONMENT=environment.sh
sed "
  s|%S3_ACCESS_KEY%|${S3_ACCESS_KEY:-}|g;
  s|%S3_SECRET_KEY%|${S3_SECRET_KEY:-}|g;
" templates/${TEMPLATE}.sh.in > ${ENVIRONMENT}

# construct submission file
SUBMIT_FILE=${TEMPLATE}.submit
sed "
  s|%EXECUTABLE%|${EXECUTABLE}|g;
  s|%ARGUMENTS%|${ARGUMENTS}|g;
  s|%JUG_XL_TAG%|${JUG_XL_TAG:-nightly}|g;
  s|%ENVIRONMENT%|${ENVIRONMENT}|g;
  s|%RESOURCENAME%|${RESOURCENAME}|g;
" templates/${TEMPLATE}.submit.in > ${SUBMIT_FILE}

# submit job
condor_submit ${SUBMIT_FILE}
