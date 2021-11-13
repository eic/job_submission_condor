#!/bin/bash

n=1
N=$(condor_q -constraint 'JobStatus == 5' -af ClusterID ProcID | wc -l)

condor_q -constraint 'JobStatus == 5' -af ClusterID ProcID NumJobStarts | while read ClusterID ProcID NumJobStarts ; do
  echo "Job ${ClusterID}.${ProcID} ${NumJobStarts} ($n/$N)"
  prefix="LOG/CONDOR/osg_${ClusterID}_${ProcID}"

  # Common errors for automatic release
  if test -f ${prefix}.err ; then
    if grep "Unable to initialize new alias from the provided credentials." ${prefix}.err ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "FATAL: kernel too old" ${prefix}.err ; then
      read <&1
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
      grep hostname ${prefix}.out
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "ERROR Detector separation = 0!Cannot calculate slope!" ${prefix}.out ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
  fi
  if test -f ${prefix}.log ; then
    if grep "put on hold by SYSTEM_PERIODIC_HOLD due to memory usage" ${prefix}.log ; then
      condor_rm ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
  fi

  ls -al ${prefix}.*
  for i in ${prefix}.* ; do
    tail -n 5 ${i}
  done
  test -f ${prefix}.out && grep -i error ${prefix}.out | tail -n 10

  review=x
  while [ -n "${review}" ] ; do
    read -n 1 -p "Job ${ClusterID}.${ProcID} ${NumJobStarts} ($n/$N): review? [e,l,o] " review <&1
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
  read -n 1 -p "Job ${ClusterID}.${ProcID} ${NumJobStarts} ($n/$N): release? [Y,n,r] " release <&1
  echo
  if [ -z "${release}" -o "${release}" == "y" ] ; then
    condor_release ${ClusterID}.${ProcID}
  fi
  if [ "${release}" == "r" ] ; then
    condor_rm ${ClusterID}.${ProcID}
  fi

  n=$((n+1))
done
