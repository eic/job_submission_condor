#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# Set url for frequency tables
EGAS_URL=https://raw.githubusercontent.com/eic/simulation_campaign_datasets/main/config_data/egas_freq.csv
HGAS_URL=https://raw.githubusercontent.com/eic/simulation_campaign_datasets/main/config_data/hgas_freq.csv
SYNRAD_URL=https://raw.githubusercontent.com/eic/simulation_campaign_datasets/main/config_data/synrad_freq.csv

# Download tables
EGAS_TABLE=$( curl -L ${EGAS_URL} )
HGAS_TABLE=$( curl -L ${HGAS_URL} )
SYNRAD_TABLE=$( curl -L ${SYNRAD_URL} )

# Initialize associative arrays (maps) for each type of background
declare -A EGAS_FILE EGAS_FREQ EGAS_SKIP HGAS_FILE HGAS_FREQ HGAS_SKIP SYNRAD_FILE SYNRAD_FREQ SYNRAD_SKIP

# Function to trim units
trim() {
  local input="$1"
  local unit="$2"
  # Remove unit
  input="${input//${unit}/}"
  echo "$input"
}

# Function to process each line into a map
process_lines() {
    local data="$1"
    local -n map_file="$2"
    local -n map_freq="$3"
    local -n map_skip="$4"
    local index=0

    while IFS=',' read -r config file freq skip; do
        # Adding the line to the map with a simple index as the key
        map_file[$config]="$(echo $file | xargs)"
        map_freq[$config]="$(echo $(trim $freq kHz) | xargs)"
        map_skip[$config]="$(echo $skip | xargs)"
    done <<< "$data"
}

# Process the downloaded data and populate the maps
process_lines "$EGAS_TABLE" EGAS_FILE EGAS_FREQ EGAS_SKIP
process_lines "$HGAS_TABLE" HGAS_FILE HGAS_FREQ HGAS_SKIP
process_lines "$SYNRAD_TABLE" SYNRAD_FILE SYNRAD_FREQ SYNRAD_SKIP

# Always set BG1 and BG3
export BG1_FILE=${EGAS_FILE[${EBEAM}GeVx${PBEAM}GeV_${VAC}Ahr]}
export BG1_FREQ=${EGAS_FREQ[${EBEAM}GeVx${PBEAM}GeV_${VAC}Ahr]}
export BG1_SKIP=${EGAS_SKIP[${EBEAM}GeVx${PBEAM}GeV_${VAC}Ahr]}

export BG3_FILE=${SYNRAD_FILE[${EBEAM}GeV]}
export BG3_FREQ=${SYNRAD_FREQ[${EBEAM}GeV]}
export BG3_SKIP=${SYNRAD_SKIP[${EBEAM}GeV]}

# Only set BG2 if BG_ONLY is not true
if [ -z "${BG_ONLY:-}" ]; then
  export BG2_FILE=${HGAS_FILE[${EBEAM}GeVx${PBEAM}GeV_${VAC}Ahr]}
  export BG2_FREQ=${HGAS_FREQ[${EBEAM}GeVx${PBEAM}GeV_${VAC}Ahr]}
  export BG2_SKIP=${HGAS_SKIP[${EBEAM}GeVx${PBEAM}GeV_${VAC}Ahr]}
else
  echo "Running in background only mode. Make sure to use the proton beam gas as the signal"
fi
