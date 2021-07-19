#!/bin/bash

##
## Sense Collector - sense-collector-details.sh
##

sense_collector_version="1.0.1"
#grafana_loki_binary_path="./promtail-linux-amd64"
grafana_loki_binary_path="/usr/bin/promtail"
debug_sleeping=$SENSE_COLLECTOR_DEBUG_SLEEPING

##
## Echo Details
##

echo_bold=$(tput -T xterm bold)
echo_blink=$(tput -T xterm blink)
echo_black=$(tput -T xterm setaf 0)
echo_blue=$(tput -T xterm setaf 4)
echo_dim=$(tput -T xterm dim)

echo_color_random=$(echo -e "\e[3$(( $RANDOM * 6 / 32767 + 1 ))m")

echo_normal=$(tput -T xterm sgr0)

##
## Functions
##

##
## ┌─┐┌─┐┌─┐┌─┐┌─┐┌─┐    ┌┐┌┌─┐┌┬┐┌─┐┌─┐
## ├┤ └─┐│  ├─┤├─┘├┤     │││├─┤│││├┤ └─┐
## └─┘└─┘└─┘┴ ┴┴  └─┘────┘└┘┴ ┴┴ ┴└─┘└─┘
##

function escape_names {

##
## Spaces
##

name_escaped="${name// /\\ }"

##
## Commas
##

name_escaped="${name_escaped//,/\\,}"

##
## Equal Signs
##

name_escaped="${name_escaped//=/\\=}"

}

##
## ┬ ┬┌─┐┌─┐┬ ┌┬┐┬ ┬    ┌─┐┬ ┬┌─┐┌─┐┬┌─
## ├─┤├┤ ├─┤│  │ ├─┤    │  ├─┤├┤ │  ├┴┐
## ┴ ┴└─┘┴ ┴┴─┘┴ ┴ ┴────└─┘┴ ┴└─┘└─┘┴ ┴
##

function health_check () {

if [ "$healthcheck" == "true" ]; then health_check_file="health-check-${collector_type}.txt"; touch "${health_check_file}"; fi

}

##
## ┌─┐┬─┐┌─┐┌─┐┌─┐┌─┐┌─┐    ┌─┐┌┬┐┌─┐┬─┐┌┬┐
## ├─┘├┬┘│ ││  ├┤ └─┐└─┐    └─┐ │ ├─┤├┬┘ │ 
## ┴  ┴└─└─┘└─┘└─┘└─┘└─┘────└─┘ ┴ ┴ ┴┴└─ ┴ 
##

##
## Send Startup Event Timestamp to InfluxDB
##

function process_start () {

if [ "$curl_debug" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

current_time=$(date +%s)

#echo "${bold}${collector_type}:${normal} time_epoch: ${current_time}"

if [ -n "$influxdb_url" ]; then

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
sense_o11y,host_hostname=${host_hostname},function="process_start",source=${collector_type},type=event time_epoch=${current_time}000"

fi

}