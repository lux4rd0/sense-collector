#!/bin/bash

##
## Sense Startup
##

##
## Set Specific Variables
##

collector_type="sense-init"

##
## Sense-Collector Details
##

source sense-collector-details.sh

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
disable_device_details=$SENSE_COLLECTOR_DISABLE_DEVICE_DETAILS
disable_health_check=$SENSE_COLLECTOR_DISABLE_HEALTH_CHECK
disable_host_performance=$SENSE_COLLECTOR_DISABLE_HOST_PERFORMANCE
disable_monitor_status=$SENSE_COLLECTOR_DISABLE_MONITOR_STATUS
disable_sense_collector=$SENSE_COLLECTOR_DISABLE_SENSE_COLLECTOR
host_hostname=$SENSE_COLLECTOR_HOST_HOSTNAME
influxdb_password=$SENSE_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$SENSE_COLLECTOR_INFLUXDB_URL
influxdb_username=$SENSE_COLLECTOR_INFLUXDB_USERNAME
poll_interval=$SENSE_COLLECTOR_POLL_INTERVAL
sense_monitor_id=$SENSE_COLLECTOR_MONITOR_ID
sense_token=$SENSE_COLLECTOR_TOKEN

if [ "$debug" == "true" ]; then

echo "debug=${debug}
debug_curl=${debug_curl}
host_hostname=${host_hostname}
influxdb_password=${influxdb_password}
influxdb_url=${influxdb_url}
influxdb_username=${influxdb_username}
sense_monitor_id=${sense_monitor_id}
sense_token=${sense_token}"
fi

##
## Curl Command
##

#if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

##
##  ::::::::   ::::::::  :::        :::        :::::::::: :::::::: ::::::::::: ::::::::  :::::::::  
## :+:    :+: :+:    :+: :+:        :+:        :+:       :+:    :+:    :+:    :+:    :+: :+:    :+: 
## +:+        +:+    +:+ +:+        +:+        +:+       +:+           +:+    +:+    +:+ +:+    +:+ 
## +#+        +#+    +:+ +#+        +#+        +#++:++#  +#+           +#+    +#+    +:+ +#++:++#:  
## +#+        +#+    +#+ +#+        +#+        +#+       +#+           +#+    +#+    +#+ +#+    +#+ 
## #+#    #+# #+#    #+# #+#        #+#        #+#       #+#    #+#    #+#    #+#    #+# #+#    #+# 
##  ########   ########  ########## ########## ########## ########     ###     ########  ###    ### 
##


##
## ┬ ┬┌─┐┌─┐┌┬┐  ┌─┐┌─┐┬─┐┌─┐┌─┐┬─┐┌┬┐┌─┐┌┐┌┌─┐┌─┐
## ├─┤│ │└─┐ │───├─┘├┤ ├┬┘├┤ │ │├┬┘│││├─┤││││  ├┤ 
## ┴ ┴└─┘└─┘ ┴   ┴  └─┘┴└─└  └─┘┴└─┴ ┴┴ ┴┘└┘└─┘└─┘
##

if [ "$disable_host_performance" != "true" ]; then

while : ; do echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Starting ${echo_bold}Host Performance${echo_normal}"; ./start-host-performance.sh ; done &
else
echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_DISABLE_HOST_PERFORMANCE${echo_normal} set to \"true\" or ${echo_bold}SENSE_COLLECTOR_INFLUXDB_URL${echo_normal} is missing. Disabling ${echo_color_start}host-performance${echo_normal}."
export SENSE_COLLECTOR_DISABLE_HOST_PERFORMANCE="true"
fi

##
## ┬ ┬┌─┐┌─┐┬ ┌┬┐┬ ┬   ┌─┐┬ ┬┌─┐┌─┐┬┌─
## ├─┤├┤ ├─┤│  │ ├─┤───│  ├─┤├┤ │  ├┴┐
## ┴ ┴└─┘┴ ┴┴─┘┴ ┴ ┴   └─┘┴ ┴└─┘└─┘┴ ┴
##

if [ "$disable_health_check" != "true" ]; then

while : ; do echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Starting ${echo_bold}Health Check${echo_normal}"; ./start-health-check.sh ; done &
else
echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_DISABLE_HEALTH_CHECK${echo_normal} set to \"true\" or ${echo_bold}SENSE_COLLECTOR_INFLUXDB_URL${echo_normal} is missing. Disabling ${echo_color_start}health-check${echo_normal}."
export SENSE_COLLECTOR_DISABLE_HEALTH_CHECK="true"
fi

##
## ┌┬┐┌─┐┬  ┬┬┌─┐┌─┐ ┌┬┐┌─┐┌┬┐┌─┐┬┬  ┌─┐
##  ││├┤ └┐┌┘││  ├┤───││├┤  │ ├─┤││  └─┐
## ─┴┘└─┘ └┘ ┴└─┘└─┘ ─┴┘└─┘ ┴ ┴ ┴┴┴─┘└─┘
##

if [ "$disable_device_details" != "true" ]; then

while : ; do echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Starting ${echo_bold}Device Details${echo_normal}"; ./start-device-details.sh ; done &
else
echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_DISABLE_DEVICE_DETAILS${echo_normal} set to \"true\" or ${echo_bold}SENSE_COLLECTOR_INFLUXDB_URL${echo_normal} is missing. Disabling ${echo_color_start}device-details${echo_normal}."
export SENSE_COLLECTOR_DISABLE_DEVICE_DETAILS="true"
fi

##
## ┌┬┐┌─┐┌┐┌┬┌┬┐┌─┐┬─┐   ┌─┐┌┬┐┌─┐┌┬┐┬ ┬┌─┐
## ││││ │││││ │ │ │├┬┘───└─┐ │ ├─┤ │ │ │└─┐
## ┴ ┴└─┘┘└┘┴ ┴ └─┘┴└─   └─┘ ┴ ┴ ┴ ┴ └─┘└─┘
##

if [ "$disable_monitor_status" != "true" ]; then

while : ; do echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Starting ${echo_bold}Monitor Status${echo_normal}"; ./start-monitor-status.sh ; done &
else
echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_DISABLE_MONITOR_STATUS${echo_normal} set to \"true\" or ${echo_bold}SENSE_COLLECTOR_INFLUXDB_URL${echo_normal} is missing. Disabling ${echo_color_start}monitor-status${echo_normal}."
export SENSE_COLLECTOR_DISABLE_MONITOR_STATUS="true"
fi

##
## ┌─┐┌─┐┌┐┌┌─┐┌─┐  ┌─┐┌─┐┬  ┬  ┌─┐┌─┐┌┬┐┌─┐┬─┐
## └─┐├┤ │││└─┐├┤───│  │ ││  │  ├┤ │   │ │ │├┬┘
## └─┘└─┘┘└┘└─┘└─┘  └─┘└─┘┴─┘┴─┘└─┘└─┘ ┴ └─┘┴└─
##

if [ "$disable_sense_collector" != "true" ]; then

while : ; do echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Starting ${echo_bold}Sense Collector${echo_normal}"; ./start-sense-collector.sh ; done &
else
echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_DISABLE_SENSE_COLLECTOR${echo_normal} set to \"true\" or ${echo_bold}SENSE_COLLECTOR_INFLUXDB_URL${echo_normal} is missing. Disabling ${echo_color_start}sense-collector${echo_normal}."
export SENSE_COLLECTOR_DISABLE_SENSE_COLLECTOR="true"
fi

##
## ┌─┐┌─┐┌┐┌┌─┐┌─┐  ┬┌┐┌┬┌┬┐
## └─┐├┤ │││└─┐├┤───│││││ │ 
## └─┘└─┘┘└┘└─┘└─┘  ┴┘└┘┴ ┴ 
##

##
## Used to keep dumb-init running
##

while : ; do sleep 69; done