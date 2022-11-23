#!/bin/bash

n=1
N=$(condor_q ${1:-} -constraint 'JobStatus == 5' -af ClusterID ProcID | wc -l)

condor_q ${1:-} -constraint 'JobStatus == 5' -af ClusterID ProcID NumJobStarts | while read ClusterID ProcID NumJobStarts ; do
  echo "Job ${ClusterID}.${ProcID} ${NumJobStarts} ($n/$N)"
  prefix="LOG/CONDOR/osg_${ClusterID}_${ProcID}"

  # Copy hold record
  for i in ${prefix}.* ; do
    j=${i/LOG/HOLD}
    mkdir -p $(dirname ${j})
    cp ${i} ${j}
  done

  # Common errors for automatic release
  if test -f ${prefix}.err ; then
    if grep "Transport endpoint is not connected" ${prefix}.err ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "Unable to initialize new alias from the provided credentials." ${prefix}.err ; then
      grep ^resource ${prefix}.out
      grep ^hostname ${prefix}.out
      grep -A20 tracepath ${prefix}.out | tee -a tracepath.log
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "tracepath: dtn01.sdcc.bnl.gov: Temporary failure in name resolution" ${prefix}.err ; then
      grep hostname ${prefix}.out
      grep -A20 tracepath ${prefix}.out | tee -a tracepath.log
      read <&1
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
    #if grep -Pzo "Info in <TGeoManager::CloseGeometry>: -+modeler ready-+.*\n.*\[FATAL\] Detected timeout in worker! Stopping." ${prefix}.out ; then
    #  read <&1
    #  condor_release ${ClusterID}.${ProcID}
    #  n=$((n+1))
    #  continue
    #fi
    if grep -Pzo "Failed to load ID decoder for HcalBarrelHits" ${prefix}.out ; then
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
  fi
  if test -f ${prefix}.out ; then
    if grep "Unable to initialize new alias from the provided credentials." ${prefix}.out ; then
      grep ^date ${prefix}.out
      grep ^resource ${prefix}.out
      grep ^hostname ${prefix}.out
      grep -A20 tracepath ${prefix}.out | tee -a tracepath.log
      read <&1
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "Unable to validate source" ${prefix}.out ; then
      grep ^resource ${prefix}.out
      grep ^hostname ${prefix}.out
      grep -A20 tracepath ${prefix}.out | tee -a tracepath.log
      read <&1
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "No internet connection." ${prefix}.out ; then
      grep ^resource ${prefix}.out
      grep ^hostname ${prefix}.out
      grep -A20 tracepath ${prefix}.out | tee -a tracepath.log
      condor_release ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if [ $(grep "unsorted double linked list corrupted" ${prefix}.out | wc -l) -gt 10 ] ; then
      grep -B5 "unsorted double linked list corrupted" ${prefix}.out | head -n 10
      read <&1
      condor_rm ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    #if grep -B20 "\[FATAL\] Detected timeout in worker! Stopping." ${prefix}.out ; then
    #  read <&1
    #  condor_release ${ClusterID}.${ProcID}
    #  n=$((n+1))
    #  continue
    #fi
  fi
  if test -f ${prefix}.log ; then
    if grep "put on hold by SYSTEM_PERIODIC_HOLD due to memory usage" ${prefix}.log ; then
      condor_rm ${ClusterID}.${ProcID}
      n=$((n+1))
      continue
    fi
    if grep "memory usage exceeded request_memory" ${prefix}.log ; then
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
  test -f ${prefix}.out && grep resource ${prefix}.out
  test -f ${prefix}.out && grep hostname ${prefix}.out

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
