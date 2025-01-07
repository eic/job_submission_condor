#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# Set url for frequency tables
EGAS_URL=https://raw.githubusercontent.com/eic/simulation_campaign_datasets/main/config_data/egas_freq.csv
HGAS_URL=https://raw.githubusercontent.com/eic/simulation_campaign_datasets/main/config_data/hgas_freq.csv
MINBIAS_URL=https://raw.githubusercontent.com/eic/simulation_campaign_datasets/main/config_data/minbias_freq.csv

# Download tables
EGAS_TABLE=(curl ${EGAS_URL})
HGAS_TABLE=(curl ${HGAS_URL})
MINBIAS_TABLE=(curl ${MINBIAS_URL})

# Initialize associative arrays (maps) for each type of background
declare -A EGAS_MAP
declare -A HGAS_MAP
declare -A MINBIAS_MAP

# Function to process each line into a map
process_lines() {
    local data="$1"
    local -n map_ref="$2"
    local index=0

    while IFS=',' read -r key value; do
        # Adding the line to the map with a simple index as the key
        map_ref[$index]="$key,$value"
        index=$((index + 1))
    done <<< "$data"
}

# Process the downloaded data and populate the maps
process_lines "$EGAS_TABLE" EGAS_MAP
process_lines "$HGAS_TABLE" HGAS_MAP
process_lines "$MINBIAS_TABLE" MINBIAS_MAP

export BG1_FREQ=${EGAS_MAP[${EBEAM}x${PBEAM}_${EVAC}]}
export BG2_FREQ=${HGAS_MAP[${EBEAM}x${PBEAM}_${HVAC}]}
export BG3_FREQ=${MINBIAS_MAP[${EBEAM}x${PBEAM}]}
