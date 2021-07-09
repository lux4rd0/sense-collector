#!/bin/bash

##
## Sense Startup
##

echo "

                ███████╗███████╗███╗   ██╗███████╗███████╗                 
                ██╔════╝██╔════╝████╗  ██║██╔════╝██╔════╝                 
                ███████╗█████╗  ██╔██╗ ██║███████╗█████╗                   
                ╚════██║██╔══╝  ██║╚██╗██║╚════██║██╔══╝                   
                ███████║███████╗██║ ╚████║███████║███████╗                 
                ╚══════╝╚══════╝╚═╝  ╚═══╝╚══════╝╚══════╝                 
                                                                           
 ██████╗ ██████╗ ██╗     ██╗     ███████╗ ██████╗████████╗ ██████╗ ██████╗ 
██╔════╝██╔═══██╗██║     ██║     ██╔════╝██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
██║     ██║   ██║██║     ██║     █████╗  ██║        ██║   ██║   ██║██████╔╝
██║     ██║   ██║██║     ██║     ██╔══╝  ██║        ██║   ██║   ██║██╔══██╗
╚██████╗╚██████╔╝███████╗███████╗███████╗╚██████╗   ██║   ╚██████╔╝██║  ██║
 ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
                                                                           
"

debug=$SENSE_COLLECTOR_DEBUG
debug_curl=$SENSE_COLLECTOR_DEBUG_CURL
influxdb_password=$SENSE_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$SENSE_COLLECTOR_INFLUXDB_URL
influxdb_username=$SENSE_COLLECTOR_INFLUXDB_USERNAME
sense_monitor_id=$SENSE_COLLECTOR_MONITOR_ID
sense_token=$SENSE_COLLECTOR_TOKEN

if [ "$debug" == "true" ]; then

echo "debug=${debug}
debug_curl=${debug_curl}
influxdb_password=${influxdb_password}
influxdb_url=${influxdb_url}
influxdb_username=${influxdb_username}
sense_monitor_id=${sense_monitor_id}
sense_token=${sense_token}"
fi

if [ "$disable_host_performance" != "true" ]; then

while : ; do echo "$(date) - Starting up Sense Collector."; timeout 10m ./websocat_amd64-linux-static -n -t - autoreconnect:wss://clientrt.sense.com/monitors/${sense_monitor_id}/realtimefeed -H "Authorization: bearer ${sense_token}" -H "Sense-Collector-Client-Version: 1.0.0" -H "X-Sense-Protocol: 3" -H "User-Agent: okhttp/3.8.0" | ./exec-sense-collector.sh ; done 
else
echo "${echo_bold}${echo_color_start}${collector_type}:${echo_normal} $(date) - ${echo_bold}SENSE_COLLECTOR_DISABLE_HOST_PERFORMANCE${echo_normal} set to \"true\" or ${echo_bold}SENSE_COLLECTOR_INFLUXDB_URL${echo_normal} is missing. Disabling ${echo_color_start}host-performance${echo_normal}."
export SENSE_COLLECTOR_DISABLE_HEALTHCHECK_HOST_PERFORMANCE="true"
fi