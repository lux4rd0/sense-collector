#!/bin/bash

##
## Sense Collector - start-device-details.sh
##

##
## Set Specific Variables
##

collector_type="device-details"

##
## Sense-Collector Details
##

source sense-collector-details.sh

##
## Set Variables from Environmental Variables
##

debug=$SENSE_COLLECTOR_DEBUG
debug_curl=$SENSE_COLLECTOR_DEBUG_CURL
debug_sleeping=$SENSE_COLLECTOR_DEBUG_SLEEPING
host_hostname=$SENSE_COLLECTOR_HOST_HOSTNAME
influxdb_password=$SENSE_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$SENSE_COLLECTOR_INFLUXDB_URL
influxdb_username=$SENSE_COLLECTOR_INFLUXDB_USERNAME
poll_interval=$SENSE_COLLECTOR_DEVICE_DETAILS_POLL_INTERVAL
sense_monitor_id=$SENSE_COLLECTOR_MONITOR_ID
sense_token=$SENSE_COLLECTOR_TOKEN
threads=$SENSE_COLLECTOR_THREADS

##
## Check for required intervals
##

if [ -z "${poll_interval}" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_DEVICE_DETAILS_POLL_INTERVAL${echo_normal} environmental variable not set. Defaulting to ${echo_bold}60${echo_normal} seconds."; poll_interval="60"; export SENSE_COLLECTOR_POLL_INTERVAL="60"; fi

if [ -z "${host_hostname}" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_HOST_HOSTNAME${echo_normal} environmental variable not set. Defaulting to ${echo_bold}sense-collector${echo_normal}."; host_hostname="sense-collector"; export SENSE_COLLECTOR_HOST_HOSTNAME="sense-collector"; fi

if [ -z "${threads}" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_THREADS${echo_normal} environmental variable not set. Defaulting to ${echo_bold}4${echo_normal} threads."; threads="4"; export SENSE_COLLECTOR_THREADS="4"; fi

if [ "$debug" == "true" ]

then

echo "$(date) - Starting Sense Collector (start-device-details.sh) - https://github.com/lux4rd0/sense-collector

Debug Environmental Variables

debug=${debug}
debug_curl=${debug_curl}
host_hostname=${host_hostname}
influxdb_password=${influxdb_password}
influxdb_url=${influxdb_url}
influxdb_username=${influxdb_username}
poll_interval=${poll_interval}
sense_monitor_id=${sense_monitor_id}
sense_token=${sense_token}"
fi

##
## Send Startup Event Timestamp to InfluxDB
##

process_start

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --show-error --fail ); fi

##
## Start Sense Device Details Loop
##

while ( true ); do
before=$(date +%s%N)

./exec-device-details.sh

after=$(date +%s%N)
delay=$(echo "scale=4;(${poll_interval}-($after-$before) / 1000000000)" | bc)

if [ "$debug_sleeping" == "true" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Sleeping: ${delay} seconds"; fi

sleep "$delay"
done