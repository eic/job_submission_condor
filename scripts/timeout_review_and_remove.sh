#!/bin/bash

n=1
N=$(condor_q -constraint 'RemoteUserCpu>60000 && JobStatus==2' -af ClusterID ProcID | wc -l)

condor_q -constraint 'RemoteUserCpu>60000 && JobStatus==2' -af RemoteUserCpu ClusterID ProcID RemoteHost | sort -nr | head -n 20
condor_q -constraint 'RemoteUserCpu>60000 && JobStatus==2' -af RemoteUserCpu ClusterID ProcID RemoteHost | sort -nr | while read RemoteUserCpu ClusterID ProcID RemoteHost ; do
  echo "Job ${ClusterID}.${ProcID} ($n/$N), $RemoteUserCpu seconds"
  condor_q ${ClusterID}.${ProcID}
  prefix="LOG/CONDOR/osg_${ClusterID}_${ProcID}"

  ls -al ${prefix}.*
  condor_q ${ClusterID}.${ProcID} -af LastRemoteHost
  condor_q ${ClusterID}.${ProcID} -af RemoteHost
  test -f ${prefix}.log && tail -n 10 ${prefix}.log

  review=x
  while [ -n "${review}" ] ; do
    read -n 1 -p "Job ${ClusterID}.${ProcID} ($n/$N): review? [e,l,o] " review <&1
    echo
    if [ "${review}" == "l" ] ; then
      less ${prefix}.log
    fi
    if [ "${review}" == "e" ] ; then
      condor_tail -stderr ${ClusterID}.${ProcID}
    fi
    if [ "${review}" == "o" ] ; then
      condor_tail ${ClusterID}.${ProcID}
    fi
  done

  remove=x
  read -n 1 -p "Job ${ClusterID}.${ProcID} ($n/$N): hold? [h,r] " remove <&1
  echo
  if [ "${remove}" == "h" ] ; then
    condor_hold ${ClusterID}.${ProcID}
  fi
  if [ "${remove}" == "r" ] ; then
    condor_rm ${ClusterID}.${ProcID}
  fi

  n=$((n+1))
done
