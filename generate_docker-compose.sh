#!/bin/bash

##
## Sense Collector - generate_docker-compose.sh
##

debug=$SENSE_COLLECTOR_DEBUG
debug_curl=$SENSE_COLLECTOR_DEBUG_CURL
influxdb_password=$SENSE_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$SENSE_COLLECTOR_INFLUXDB_URL
influxdb_username=$SENSE_COLLECTOR_INFLUXDB_USERNAME
loki_client_url=$SENSE_COLLECTOR_LOKI_CLIENT_URL
sense_password=$SENSE_COLLECTOR_PASSWORD
sense_username=$SENSE_COLLECTOR_USERNAME


echo_bold=$(tput -T xterm bold)
echo_color_sense=$(echo -e "\e[3$(( RANDOM * 6 / 32767 + 1 ))m")
echo_color_collector=$(echo -e "\e[3$(( RANDOM * 6 / 32767 + 1 ))m")
echo_normal=$(tput -T xterm sgr0)


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



echo "${echo_bold}Sense Collector${echo_normal} (generate_docker-compose.sh) - https://github.com/lux4rd0/sense-collector

debug=${debug}
debug_curl=${debug_curl}
influxdb_password=${influxdb_password}
influxdb_url=${influxdb_url}
influxdb_username=${influxdb_username}
loki_client_url=${loki_client_url}
sense_password=${sense_password}
sense_username=${sense_username}"

if [ -z "${influxdb_password}" ]; then echo "${echo_bold}${echo_color_sense}sense-collector:${echo_normal} ${echo_bold}SENSE_COLLECTOR_INFLUXDB_PASSWORD${echo_normal} was not set. Setting defaults: ${echo_bold}password${echo_normal}"; influxdb_password="password"; fi

if [ -z "${influxdb_url}" ]; then echo "${echo_bold}${echo_color_sense}sense-collector:${echo_normal} ${echo_bold}SENSE_COLLECTOR_INFLUXDB_URL${echo_normal} was not set. Setting defaults: ${echo_bold}http://influxdb:8086/write?db=sense${echo_normal}"; influxdb_url="http://influxdb:8086/write?db=sense" ; fi

if [ -z "${influxdb_username}" ]; then echo "${echo_bold}${echo_color_sense}sense-collector:${echo_normal} ${echo_bold}SENSE_COLLECTOR_INFLUXDB_USERNAME${echo_normal} was not set. Setting defaults: ${echo_bold}influxdb${echo_normal}"; influxdb_username="influxdb"; fi

if [ -z "${sense_password}" ]; then echo "${echo_bold}${echo_color_sense}sense-collector:${echo_normal} ${echo_bold}SENSE_COLLECTOR_PASSWORD${echo_normal} was not set. Missing Sense password. Please provide your password as an environmental variable."; fi

if [ -z "${sense_username}" ]; then echo "${echo_bold}${echo_color_sense}sense-collector:${echo_normal} ${echo_bold}SENSE_COLLECTOR_USERNAME${echo_normal} was not set. Missing Sense user name. Please provide your user name as an environmental variable."

else

url_sense_authenticate="https://api.sense.com/apiservice/api/v1/authenticate"

response_url_sense=$(curl -k --data "email=${sense_username}" --data "password=${sense_password}" -H "Sense-Collector-Client-Version: 1.0.0" -H "X-Sense-Protocol: 3" -H "User-Agent: okhttp/3.8.0" "${url_sense_authenticate}")

#echo "${response_url_sense}"

token=$(echo "${response_url_sense}" | jq -r .access_token)
monitor_id=$(echo "${response_url_sense}" | jq -r .monitors[].id)
time_zone=$(echo "${response_url_sense}" | jq -r .monitors[].time_zone)

echo "token=${token}
monitor_id=${monitor_id}
time_zone=${time_zone}"


FILE_DC="${PWD}/docker-compose.yml"

if test -f "${FILE_DC}"; then
existing_file_timestamp_dc=$(date -r "${FILE_DC}" "+%Y%m%d-%H%M%S")
echo "${echo_bold}${echo_color_sense}sense-collector:${echo_normal} Existing ${echo_bold}${FILE_DC}${echo_normal} with a timestamp of ${echo_bold}${existing_file_timestamp_dc}${echo_normal} file found. Backup up file to ${FILE_DC}.${existing_file_timestamp_dc}.old"
mv "${FILE_DC}" "${FILE_DC}"."${existing_file_timestamp_dc}.old"
fi



##
## ┌┬┐┌─┐┌─┐┬┌─┌─┐┬─┐   ┌─┐┌─┐┌┬┐┌─┐┌─┐┌─┐┌─┐┬ ┬┌┬┐┬  
##  │││ ││  ├┴┐├┤ ├┬┘───│  │ ││││├─┘│ │└─┐├┤ └┬┘││││  
## ─┴┘└─┘└─┘┴ ┴└─┘┴└─   └─┘└─┘┴ ┴┴  └─┘└─┘└─┘o┴ ┴ ┴┴─┘
##

echo "services:
  sense-collector-${monitor_id}:
    container_name: sense-collector-${monitor_id}
    environment:
      TZ: ${time_zone}
      SENSE_COLLECTOR_DEBUG: \"false\"
      SENSE_COLLECTOR_DEBUG_CURL: \"false\"
      SENSE_COLLECTOR_HEALTHCHECK: \"true\"
      SENSE_COLLECTOR_HOST_HOSTNAME: $(hostname)
      SENSE_COLLECTOR_INFLUXDB_PASSWORD: ${influxdb_password}
      SENSE_COLLECTOR_INFLUXDB_URL: ${influxdb_url}
      SENSE_COLLECTOR_INFLUXDB_USERNAME: ${influxdb_username}" > docker-compose.yml

if [ -n "$loki_client_url" ]

then

echo "      SENSE_COLLECTOR_LOKI_CLIENT_URL: ${loki_client_url}" >> docker-compose.yml

fi

echo "      SENSE_COLLECTOR_TOKEN: ${token}
      SENSE_COLLECTOR_MONITOR_ID: ${monitor_id}
    image: lux4rd0/sense-collector:latest
    restart: always
version: '3.3'" >> docker-compose.yml

echo "${echo_bold}${echo_color_sense}sense-collector:${echo_normal} ${FILE_DC} file created"

fi