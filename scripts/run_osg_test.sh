#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# Load job environment (includes secrets, so delete when read)
if [ -f environment.sh ] ; then
  grep -v SECRET environment.sh
  source environment.sh
  rm environment.sh
fi

# Startup
echo "date sys: $(date)"
echo "date web: $(date -d "$(curl -Is --max-redirs 0 google.com 2>&1 | grep Date: | cut -d' ' -f2-7)")"
echo "hostname: $(hostname -f)"
echo "uname:    $(uname -a)"
echo "whoami:   $(whoami)"
echo "pwd:      $(pwd)"
echo "site:     ${GLIDEIN_Site:-}"
echo "resource: ${GLIDEIN_ResourceName:-}"
echo "http_proxy: ${http_proxy:-}"
df -h --exclude-type=fuse --exclude-type=tmpfs
ls -al
test -f .job.ad && cat .job.ad
test -f .machine.ad && cat .machine.ad
eic-info

INPUT_FILE=EVGEN/CI/pythia8NCDIS_5x41_minQ2=1_beamEffects_xAngle=-0.025_hiDiv_1_20ev.hepmc.gz

# Retry function
function retry {
  local n=0
  local max=5
  local delay=20
  while [[ $n -lt $max ]] ; do
    n=$((n+1))
    s=0
    "$@" || s=$?
    [ $s -eq 0 ] && {
      return $s
    }
    [ $n -ge $max ] && {
      echo "Failed after $n retries, exiting with $s"
      return $s
    }
    echo "Retrying in $delay seconds..."
    sleep $delay
  done
}

# S3 locations
MC="/usr/local/bin/mc"
S3URL="https://eics3.sdcc.bnl.gov:9000"
S3RO="S3"
S3RODIR="${S3RO}/eictest/EPIC"

# Local temp dir
echo "SLURM_TMPDIR=${SLURM_TMPDIR:-}"
echo "SLURM_JOB_ID=${SLURM_JOB_ID:-}"
echo "SLURM_ARRAY_JOB_ID=${SLURM_ARRAY_JOB_ID:-}"
echo "SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID:-}"
echo "_CONDOR_SCRATCH_DIR=${_CONDOR_SCRATCH_DIR:-}"
echo "OSG_WN_TMP=${OSG_WN_TMP:-}"
if [ -n "${SLURM_TMPDIR:-}" ] ; then
  TMPDIR=${SLURM_TMPDIR}
elif [ -n "${_CONDOR_SCRATCH_DIR:-}" ] ; then
  TMPDIR=${_CONDOR_SCRATCH_DIR}
else
  if [ -d "/scratch/slurm/${SLURM_JOB_ID:-}" ] ; then
    TMPDIR="/scratch/slurm/${SLURM_JOB_ID:-}"
  else
    TMPDIR=${TMPDIR:-/tmp}/${$}
  fi
fi
echo "TMPDIR=${TMPDIR}"
mkdir -p ${TMPDIR}
ls -al ${TMPDIR}

# Internet connectivity check
if curl --connect-timeout 30 --retry 5 --silent --show-error ${S3URL} > /dev/null ; then
  echo "$(hostname) is online."
  export ONLINE=true
else
  echo "$(hostname) is NOT online."
  if which tracepath ; then
    echo "tracepath -b -p 9000 eics3.sdcc.bnl.gov"
    tracepath -b -p 9000 eics3.sdcc.bnl.gov
    echo "tracepath -b www.bnl.gov"
    tracepath -b www.bnl.gov
    echo "tracepath -b google.com"
    tracepath -b google.com
  fi
  export ONLINE=
fi

# Retrieve test file if S3_ACCESS_KEY and S3_SECRET_KEY in environment
if [ -x ${MC} ] ; then
  if [ -n "${ONLINE:-}" ] ; then
    if [ -n "${S3_ACCESS_KEY:-}" -a -n "${S3_SECRET_KEY:-}" ] ; then
      MC_CONFIG=$(mktemp -d $PWD/mc_config.XXXX)
      retry ${MC} -C ${MC_CONFIG} config host add ${S3RO} ${S3URL} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}
      retry ${MC} -C ${MC_CONFIG} config host list ${S3RO} | grep -v SecretKey
      retry ${MC} -C ${MC_CONFIG} cp --disable-multipart --insecure ${S3RODIR}/${INPUT_FILE} .
      retry ${MC} -C ${MC_CONFIG} config host remove ${S3RO}
      ls -al
    else
      echo "No S3 credentials. Provide (readonly) S3 credentials."
      exit -1
    fi
  else
    echo "No internet connection. Pre-cache input file."
    exit -1
  fi
fi

# closeout
date

