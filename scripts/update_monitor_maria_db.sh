#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line $LINENO: $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# Startup
date

process_options() {
  verbose=false
  server=""
  user=""
  database=""
  table=""

  while getopts "hv:s:u:d:t:" opt; do
    case $opt in
      h)
        echo "Usage: $0 -s <server_name> -u <user_name> -d <database_name> -t <table_name>"
        echo "Collect condor queue info and update job monitoring database."
        echo "Options:"
        echo "  -h         Help"
        echo "  -v         Verbose level [true/false], default: false"
        echo "  -s         Server name"
        echo "  -u         User name"
        echo "  -d         Database name"
        echo "  -t         Table name"
        exit 0
        ;;
      v)
        verbose=${OPTARG}
        ;;
      s)
        server=${OPTARG}
        ;;
      u)
        user=${OPTARG}
        ;;
      d)
        database=${OPTARG}
        ;;
      t)
        table=${OPTARG}
        ;;
      \?)
        echo "Use -h to display proper usage"
        exit 1
        ;;
    esac
  done

  echo "Verbose: $verbose"
  if [[ -n $server ]] && [[ -n $user ]] && [[ -n $database ]] && [[ -n $table ]]; then
    echo "Server: $server"
    echo "User: $user"
    echo "Database: $database"
    echo "Table: $table"
  else
    echo "All required arguments not defined."
    echo "Use -h to display proper usage"
    exit 1
  fi
}

collect_job_ids() {
  # Run the condor_q command and capture the output
  output=$(condor_q --nobatch)

  # Extract the ID column and store it in an array
  readarray -t ids < <(echo "$output" | awk '{a[NR]=$1} END{for (i=5; i<NR-3; i++) print a[i]}')
}

store_info_per_id() {
  for id in "${ids[@]}"; do
    # Extract Job Ads Per Id
    IFS=
    job_ads="$(condor_q --nobatch -l $id -json)"
    IFS=$'\n\t'

    # Extract Job Start Date
    job_start_date=$(echo "$job_ads" | jq -r '.[].JobCurrentStartDate')
    hr_job_start_date=$(date -d "@$job_start_date" +"%Y-%m-%d %H:%M:%S")

    # Extract Job Status Code: 1=Idle, 2=Running, 5=Held
    job_status=$(echo "$job_ads" | jq -r '.[].JobStatus')

    # Extract Exit Code
    job_exit_code=$(echo "$job_ads" | jq -r '.[].ExitCode')

    if $verbose; then
      echo "Batch Job Id: $id"
      echo "Job Status Code: $job_status"
      echo "Latest Job Start Time: $hr_job_start_date"
      echo "Exit Code: $job_exit_code"
      echo "Job Ads:"
      echo "$job_ads"
    fi

    IFS=
    formatted_job_ads=$(printf "%s" "${job_ads}" | sed 's%"%%g')
    insert_query="INSERT INTO $table (Date, BatchJobID, Status, ExitCode, JobAd) VALUES (\"$hr_job_start_date\",\"$id\",\"$job_status\",\"$job_exit_code\",\"$formatted_job_ads\")"
    insert_query+=" ON DUPLICATE KEY UPDATE Date=\"$hr_job_start_date\", Status=\"$job_status\", ExitCode=\"$job_exit_code\", JobAd=\"$formatted_job_ads\";"

    IFS=$'\t'
    mysql --host="$server" --user="$user" --skip-password "$database" -e "$insert_query"
  done
}

process_options "$@"
collect_job_ids
store_info_per_id
