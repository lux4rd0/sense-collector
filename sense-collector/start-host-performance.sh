#!/bin/bash

##
## Sense Collector - start-host-performance.sh
##

##
## Set Specific Variables
##

collector_type="host-performance"

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
function=$SENSE_COLLECTOR_FUNCTION
healthcheck=$SENSE_COLLECTOR_HEALTHCHECK
host_hostname=$SENSE_COLLECTOR_HOST_HOSTNAME
perf_interval=$SENSE_COLLECTOR_PERF_INTERVAL
influxdb_password=$SENSE_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$SENSE_COLLECTOR_INFLUXDB_URL
influxdb_username=$SENSE_COLLECTOR_INFLUXDB_USERNAME
poll_interval=$SENSE_COLLECTOR_HOST_PERFORMANCE_POLL_INTERVAL

if [ "$debug" == "true" ]

then

echo "${echo_bold}${echo_color_host_performance}${collector_type}:${echo_normal} $(date) - Starting Sense Collector (start-host-performance.sh) - https://github.com/lux4rd0/sense-collector

Debug Environmental Variables

collector_type=${collector_type}
debug=${debug}
debug_curl=${debug_curl}
debug_sleeping=${debug_sleeping}
function=${function}
healthcheck=${healthcheck}
host_hostname=${host_hostname}
perf_interval=${perf_interval}
weatherflow_collector_version=${weatherflow_collector_version}"

fi

##
## Check for required intervals
##

if [ -z "${poll_interval}" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_POLL_INTERVAL${echo_normal} environmental variable not set. Defaulting to ${echo_bold}60${echo_normal} seconds."; poll_interval="60"; export SENSE_COLLECTOR_POLL_INTERVAL="60"; fi

if [ -z "${host_hostname}" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_HOST_HOSTNAME${echo_normal} environmental variable not set. Defaulting to ${echo_bold}sense-collector${echo_normal}."; host_hostname="sense-collector"; export SENSE_COLLECTOR_HOST_HOSTNAME="sense-collector"; fi

##
## Send Startup Event Timestamp to InfluxDB
##

process_start

##
## Curl Command
##

if [ "$debug" == "true" ]; then curl=(  ); else curl=( --silent --show-error --fail ); fi

##
## Start Host Performance Loop
##

while ( true ); do
before=$(date +%s%N)

./exec-host-performance.sh

after=$(date +%s%N)
delay=$(echo "scale=4;(${perf_interval}-($after-$before) / 1000000000)" | bc)
if [ "$debug_sleeping" == "true" ]; then echo "${echo_bold}${echo_color_host_performance}${collector_type}:${echo_normal} Sleeping: ${delay} seconds"; fi
sleep "$delay"
done