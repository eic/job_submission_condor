#!/bin/bash

n=1
N=$(condor_q -constraint 'JobStatus == 5' -af ClusterID ProcID | wc -l)

condor_q -constraint 'JobStatus == 5' -af ClusterID ProcID | while read ClusterID ProcID ; do
  echo "Job ${ClusterID}.${ProcID} ($n/$N)"
  prefix="LOG/CONDOR/osg_${ClusterID}_${ProcID}"

  # Common errors for automatic release
  if test -f ${prefix}.err ; then
    if grep "Unable to initialize new alias from the provided credentials." ${prefix}.err ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
  fi
  if test -f ${prefix}.out ; then
    if grep "Error on line 18: date" ${prefix}.out ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "Unable to initialize new alias from the provided credentials." ${prefix}.out ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "Unable to validate source" ${prefix}.out ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "No internet connection." ${prefix}.out ; then
      head -n 3 ${prefix}.out
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
  fi

  ls -al ${prefix}.*
  for i in ${prefix}.* ; do
    tail -n 5 ${i}
  done

  review=x
  while [ -n "${review}" ] ; do
    read -n 1 -p "Job ${ClusterID}.${ProcID} ($n/$N): review? [e,l,o] " review <&1
    echo
    if [ "${review}" == "e" ] ; then
      less ${prefix}.err
    fi
    if [ "${review}" == "l" ] ; then
      less ${prefix}.log
    fi
    if [ "${review}" == "o" ] ; then
      less ${prefix}.out
    fi
  done

  release=x
  read -n 1 -p "Job ${ClusterID}.${ProcID} ($n/$N): release? [Y,n] " release <&1
  echo
  if [ -z "${release}" -o "${release}" == "y" ] ; then
    condor_release ${ClusterID}.${ProcID}
  fi

  n=$((n+1))
done
