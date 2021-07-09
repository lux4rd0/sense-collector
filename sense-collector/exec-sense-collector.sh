#!/bin/bash

##
## Sense Collector - exec-sense-collector.sh
##

##
## Sense-Collector Details
##

debug=$SENSE_COLLECTOR_DEBUG
debug_curl=$SENSE_COLLECTOR_DEBUG_CURL
influxdb_password=$SENSE_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$SENSE_COLLECTOR_INFLUXDB_URL
influxdb_username=$SENSE_COLLECTOR_INFLUXDB_USERNAME

if [ "$debug" == "true" ]; then

echo "debug=${debug}
debug_curl=${debug_curl}
influxdb_password=${influxdb_password}
influxdb_url=${influxdb_url}
influxdb_username=${influxdb_username}"
fi

##
## Example Command
##

# ./start.sh | SENSE_COLLECTOR_INFLUXDB_PASSWORD=none SENSE_COLLECTOR_INFLUXDB_USERNAME=none SENSE_COLLECTOR_INFLUXDB_URL=http://influxdb01.tylephony.com:8086/write?db=sense SENSE_COLLECTOR_DEBUG=true ./exec-sense-collector.sh

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

##
## Read Socket
##

while read -r line; do

##
## Get non-device metrics
##

if [[ $line == *"realtime_update"* ]]; then

eval "$(echo "${line}" | jq -r '.payload | to_entries | .[6,7,8,10,11] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

voltage=($(echo "${line}" | jq -r '.payload.voltage | @sh') )
watts=($(echo "${line}" | jq -r '.payload.channels | @sh') )

if [ "$debug" == "true" ]; then

echo "
voltage=${voltage[0]}, ${voltage[1]}
watts=${watts[0]}, ${watts[1]}
hz=${hz}
w=${w}
c=${c}"

fi

curl_message=""
NL=$'\n'

if [ "${voltage[0]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L1 voltage=${voltage[0]}${NL}"; else echo "leg=L1 voltage is null"; fi
if [ "${voltage[1]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L2 voltage=${voltage[1]}${NL}"; else echo "leg=L2 voltage is null"; fi
if [ "${watts[0]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L1 watts=${watts[0]}${NL}"; else echo "leg=L1 watts is null"; fi
if [ "${watts[1]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L2 watts=${watts[1]}${NL}"; else echo "leg=L2 watts is null"; fi
if [ "${hz}" != "null" ]; then curl_message="${curl_message}sense_mains hz=${hz}${NL}"; else echo "hz is null"; fi
if [ "${c}" != "null" ]; then curl_message="${curl_message}sense_mains c=${c}${NL}"; else echo "c is null"; fi

##
## Remove a new line in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/\r$//')"

/usr/bin/timeout -k 1 2s curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

##
## Number of devices
##

num_of_devices=$(echo "${line}" | jq -r '.payload.devices | length')
num_of_devices_minus_one=$((num_of_devices-1))

curl_message=""
NL=$'\n'

for device in $(seq 0 $num_of_devices_minus_one); do

eval "$(echo "${line}" | jq -r '.payload.devices['"${device}"'] | to_entries | .[0,1,5] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

##
## Escape Names (Function)
##

##
## Functions
##

##
## ┌─┐┌─┐┌─┐┌─┐┌─┐┌─┐    ┌┐┌┌─┐┌┬┐┌─┐┌─┐
## ├┤ └─┐│  ├─┤├─┘├┤     │││├─┤│││├┤ └─┐
## └─┘└─┘└─┘┴ ┴┴  └─┘────┘└┘┴ ┴┴ ┴└─┘└─┘
##

#function escape_names () {

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

#}

if [ "$debug" == "true" ]; then echo "device=${device}, id=${id}, name_escaped=${name_escaped}, watts=${w}"; fi

curl_message="${curl_message}sense_devices,id=${id},name=${name_escaped} watts=${w}${NL}"

done

##
## Remove a new line in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/\r$//')"

#echo "${curl_message}"

/usr/bin/timeout -k 1 2s curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

fi

if [[ $line == *"new_timeline_event"* ]]; then

eval "$(echo "${line}" | jq -r '.payload.items_added[] | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

if [ "$debug" == "true" ]; then

echo "
time=${time}
type=${type}
icon=${icon}
body=${body}
device_id=${device_id}
device_state=${device_state}
user_device_type=${user_device_type}
device_transition_from_state=${device_transition_from_state}"
fi

time_epoch_ns=$(date -d"${time}" +%s%N )
time_epoch=$(date +%s%3N )

if [ "$debug" == "true" ]; then echo "sense_event,event_type=new_timeline,device_id=${device_id} type=\"${type}\",icon=\"${icon}\",body=\"${body}\",device_state=\"${device_state}\",user_device_type=\"${user_device_type}\",device_transition_from_state=\"${device_transition_from_state}\",time_epoch=${time_epoch} ${time_epoch_ns}"; fi

/usr/bin/timeout -k 1 2s curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "sense_event,device_id=${device_id},event_type=new_timeline type=\"${type}\",icon=\"${icon}\",body=\"${body}\",device_state=\"${device_state}\",user_device_type=\"${user_device_type}\",device_transition_from_state=\"${device_transition_from_state}\",time_epoch=${time_epoch} ${time_epoch_ns}" &

fi

if [[ $line == *"hello"* ]]; then

time_epoch=$(date +%s%3N )

if [ "$debug" == "true" ]; then echo "sense_event,event_type=hello time_epoch=${time_epoch}"; fi

/usr/bin/timeout -k 1 2s curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "sense_event,event_type=hello time_epoch=${time_epoch}" &

fi

done < /dev/stdin