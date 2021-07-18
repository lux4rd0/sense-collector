#!/bin/bash

##
## Sense Collector - start-sense-collector.sh
##

##
## Set Specific Variables
##

collector_type="sense-collector"

##
## Sense-Collector Details
##

source sense-collector-details.sh

##
## Sense-Collector Details
##

debug=$SENSE_COLLECTOR_DEBUG
debug_curl=$SENSE_COLLECTOR_DEBUG_CURL
debug_if=$SENSE_COLLECTOR_DEBUG_IF
host_hostname=$SENSE_COLLECTOR_HOST_HOSTNAME
influxdb_password=$SENSE_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$SENSE_COLLECTOR_INFLUXDB_URL
influxdb_username=$SENSE_COLLECTOR_INFLUXDB_USERNAME
poll_interval=$SENSE_COLLECTOR_SENSE_COLLECTOR_POLL_INTERVAL
sense_monitor_id=$SENSE_COLLECTOR_MONITOR_ID
sense_token=$SENSE_COLLECTOR_TOKEN
threads=$SENSE_COLLECTOR_THREADS

##
## Set Threads
##

if [ -z "${threads}" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} ${echo_bold}SENSE_COLLECTOR_THREADS${echo_normal} environmental variable not set. Defaulting to ${echo_bold}4${echo_normal} threads."; threads="4"; export SENSE_COLLECTOR_THREADS="4"; fi

if [ "$debug" == "true" ]; then

echo "debug=${debug}
debug_curl=${debug_curl}
debug_if=${debug_if}
host_hostname=${host_hostname}
influxdb_password=${influxdb_password}
influxdb_url=${influxdb_url}
influxdb_username=${influxdb_username}
poll_interval=${poll_interval}
sense_monitor_id=${sense_monitor_id}
sense_token=${sense_token}
threads=${threads}"

fi

##
## Set New Line Variable
##

NL=$'\n'

##
## Testing
##

#debug=true
#debug_curl=true

##
## Read Socket
##

while read -r line; do

if [ "$debug" == "true" ]
then

echo ""
echo "${line}"
echo ""

fi

##
## Get Power Mains Metrics
##

##
## ┬─┐┌─┐┌─┐┬ ┌┬┐┬┌┬┐┌─┐    ┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐
## ├┬┘├┤ ├─┤│  │ ││││├┤     │ │├─┘ ││├─┤ │ ├┤ 
## ┴└─└─┘┴ ┴┴─┘┴ ┴┴ ┴└─┘────└─┘┴  ─┴┘┴ ┴ ┴ └─┘
##

if [[ $line == *"realtime_update"* ]]; then


##
## Process realtime_update by streaming or on a polling interval
##

poll_check=$(date +"%S")

if [ "$debug" == "true" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} poll_check=${poll_check}"; fi

if [ "$poll_interval" == "5" ]; then

if [ "$poll_check" == "00" ] || [ "$poll_check" == "05" ] || [ "$poll_check" == "10" ] || [ "$poll_check" == "15" ] || [ "$poll_check" == "20" ] || \
[ "$poll_check" == "25" ] || [ "$poll_check" == "30" ] || [ "$poll_check" == "35" ] || [ "$poll_check" == "40" ] || [ "$poll_check" == "45" ] || \
[ "$poll_check" == "50" ] || [ "$poll_check" == "55" ]; then run_collector="true"; if [ "$debug_sleeping" == "true" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Running Collector Poll - ${echo_bold}5${echo_normal} seconds."; fi; else continue; fi

fi

if [ "$poll_interval" == "10" ]; then

if [ "$poll_check" == "00" ] || [ "$poll_check" == "10" ] || [ "$poll_check" == "20" ] || [ "$poll_check" == "30" ] || [ "$poll_check" == "40" ] || \
[ "$poll_check" == "50" ]; then run_collector="true"; if [ "$debug_sleeping" == "true" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Running Collector Poll - ${echo_bold}10${echo_normal} seconds."; fi; else continue; fi

fi

if [ "$poll_interval" == "15" ]; then

if [ "$poll_check" == "00" ] || [ "$poll_check" == "15" ] || [ "$poll_check" == "30" ] || [ "$poll_check" == "45" ]; then run_collector="true"; if [ "$debug_sleeping" == "true" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Running Collector Poll - ${echo_bold}15${echo_normal} seconds."; fi; else continue; fi

fi

if [ "$poll_interval" == "30" ]; then

if [ "$poll_check" == "00" ] || [ "$poll_check" == "30" ]; then run_collector="true"; if [ "$debug_sleeping" == "true" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Running Collector Poll - ${echo_bold}30${echo_normal} seconds."; fi; else continue; fi

fi

if [ "$poll_interval" == "60" ]; then

if [ "$poll_check" == "00" ]; then run_collector="true"; if [ "$debug_sleeping" == "true" ]; then echo "${echo_bold}${echo_color_random}${collector_type}:${echo_normal} Running Collector Poll - ${echo_bold}60${echo_normal} seconds."; fi; else continue; fi

fi

##
## Start Observations Timer
##

observations_start=$(date +%s%N)

##
## ╔╦╗┌─┐┬┌┐┌┌─┐
## ║║║├─┤││││└─┐
## ╩ ╩┴ ┴┴┘└┘└─┘
##

eval "$(echo "${line}" | jq -r '.payload | {"hz", "w", "c", "d_w", "epoch"} | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

voltage=($(echo "${line}" | jq -r '.payload.voltage | @sh') )
watts=($(echo "${line}" | jq -r '.payload.channels | @sh') )

if [ "$debug" == "true" ]; then

echo "
voltage=${voltage[0]}, ${voltage[1]}
watts=${watts[0]}, ${watts[1]}
hz=${hz}
w=${w}
c=${c}
epoch=${epoch}"

echo "epoch top: ${epoch}"
fi

##
## Clear Curl Message
##

if [ "${epoch}" != "null" ]; then curl_message=""; else
if [ "$debug_if" == "true" ]; then echo "epoch is null. Skipping realtime_update"; fi; continue; fi

if [ "${voltage[0]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L1 voltage=${voltage[0]} ${epoch}${NL}"; else if [ "$debug_if" == "true" ]; then echo "leg=L1 voltage is ${voltage[0]}."; fi; continue; fi
if [ "${voltage[1]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L2 voltage=${voltage[1]} ${epoch}${NL}"; else if [ "$debug_if" == "true" ]; then echo "leg=L2 voltage is ${voltage[1]}."; fi; continue; fi
if [ "${watts[0]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L1 watts=${watts[0]} ${epoch}${NL}"; else if [ "$debug_if" == "true" ]; then echo "leg=L1 watts is ${watts[0]}."; fi; continue; fi
if [ "${watts[1]}" != "null" ]; then curl_message="${curl_message}sense_mains,leg=L2 watts=${watts[1]} ${epoch}${NL}"; else if [ "$debug_if" == "true" ]; then echo "leg=L2 watts is ${watts[1]}."; fi; continue; fi
if [ "${hz}" != "null" ]; then curl_message="${curl_message}sense_mains hz=${hz} ${epoch}${NL}"; else if [ "$debug_if" == "true" ]; then echo "hz is ${hz}."; fi; continue; fi
if [ "${c}" != "null" ]; then curl_message="${curl_message}sense_mains c=${c} ${epoch}${NL}"; else if [ "$debug_if" == "true" ]; then echo "c is ${c}."; fi; continue; fi

##
## Remove a new line in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/\r$//')"

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

if [ "$debug" == "true" ]; then echo "${curl_message}"; fi

##
## Set InfluxDB Precision to Seconds to use the epoch time from Sense
##

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}&precision=s" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

##
## End Observations Timer
##

observations_end=$(date +%s%N)
observations_duration=$((observations_end-observations_start))

if [ "$debug" == "true" ]; then echo "$(date) - observations_duration:${observations_duration}"; fi

##
## Send Observations Metrics To InfluxDB
##

if [ -n "$influxdb_url" ]; then

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
sense_o11y,host_hostname=${host_hostname},function="realtime_update_mains",source=${collector_type} duration=${observations_duration}"

fi

## Mac
#curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}&precision=s" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

#server_epoch=$(date +%s)
#difference_epoch=$((server_epoch-epoch))

#echo "MAINS: server_epoch=${server_epoch} sense_epoch=${epoch} difference_epoch=${difference_epoch}"

#continue;

##
## ╔╦╗┌─┐┬  ┬┬┌─┐┌─┐┌─┐
##  ║║├┤ └┐┌┘││  ├┤ └─┐
## ═╩╝└─┘ └┘ ┴└─┘└─┘└─┘
##


##
## Start Observations Timer
##

observations_start=$(date +%s%N)


##
## Number of devices
##

num_of_devices=$(echo "${line}" | jq -r '.payload.devices | length')
num_of_devices_minus_one=$((num_of_devices-1))

##
## Clear variables from prior loop
##

curl_message=""
sd="null"
i="null"
v="null"
e="null"

##
## Start "threading"
##

for device in $(seq 0 $num_of_devices_minus_one); do

(

eval "$(echo "${line}" | jq -r '.payload.devices['"${device}"'] | {"id", "name", "w", "sd", "ao_w"} | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

##
## Check the ${sd} variable to see if here are additional details for discovered plugs. If found - we'll overwrite the ${w} value since it should be the same.
##

if [ "${sd}" != "null" ]; then if [ "$debug" == "true" ]; then echo "name=${name}, sd=${sd}"; fi; eval "$(echo "${line}" | jq -r '.payload.devices['"${device}"'].sd | {"w", "i", "v", "e"} | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"; fi

curl_message="${curl_message}sense_devices,"

if [ "${id}" != "null" ]; then curl_message="${curl_message}id=${id},"; else echo "id is null. Skipping device."; continue; fi

##
## Escape Names (Function)
##

if [ "${name}" != "null" ]; then escape_names; curl_message="${curl_message}name=${name_escaped},"; else if [ "$debug_if" == "true" ]; then echo "${name} - id is null. Skipping device."; continue; fi; fi

if [ "${sd}" != "null" ]; then curl_message="${curl_message}is_plug=true,"; else curl_message="${curl_message}is_plug=false,"; fi
if [ "${ao_w}" != "null" ]; then curl_message="${curl_message}always_on=true,"; else curl_message="${curl_message}always_on=false,"; fi

##
## Remove a trailing comma and add a space in curl_message
##

curl_message="$(echo "${curl_message}" | sed 's/,$/ /')"

if [ "${i}" != "null" ]; then curl_message="${curl_message}i=${i},"; else if [ "$debug_if" == "true" ]; then echo "${name} - i is null."; fi; fi
if [ "${v}" != "null" ]; then curl_message="${curl_message}v=${v},"; else if [ "$debug_if" == "true" ]; then echo "${name} - v is null."; fi; fi
if [ "${e}" != "null" ]; then curl_message="${curl_message}e=${e},"; else if [ "$debug_if" == "true" ]; then echo "${name} - e is null."; fi; fi
if [ "${ao_w}" != "null" ]; then curl_message="${curl_message}ao_w=${ao_w},"; else if [ "$debug_if" == "true" ]; then echo "${name} - ao_w is null."; fi; fi

if [ "${w}" != "null" ]; then curl_message="${curl_message}current_watts=${w}"; else if [ "$debug_if" == "true" ]; then echo "${name} - w is null. Skipping device."; fi; continue; fi

##
## Add Epoch Time
##

curl_message="${curl_message} ${epoch}"

if [ "$debug" == "true" ]; then echo "device=${device}, device_id=${id}, name_escaped=${name_escaped}, current_watts=${w}, i=${i}, v=${v}, e=${e}"; fi

##
## Remove a trailing comma in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

#curl_message="$(echo "${curl_message}" | sed 's/,$//')"

#echo "curl_message=${curl_message}"

#curl_message="$(echo "${curl_message}" | sed 's/\r$//')"

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

##
## Set InfluxDB Precision to Seconds to use the epoch time from Sense
##

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}&precision=s" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

##
## Clear ${sd}
##

sd="null"
i="null"
v="null"
e="null"

## Mac
#curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}&precision=s" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

) &

if [[ $(jobs -r -p | wc -l) -ge $threads ]]; then wait -n; fi

done

wait
#echo "curl_message=${curl_message}"

#echo "Device Loop Finished"

#if [ "$debug" == "true" ]; then echo "Device Loop Finished"; fi

##
## End "threading"
##

##
## Remove a new line in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/\r$//')"

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

##
## Set InfluxDB Precision to Seconds to use the epoch time from Sense
##

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}&precision=s" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

#curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}&precision=s" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

##
## Send Epoch Drift Metrics To InfluxDB
##

server_epoch=$(date +%s)
difference_epoch=$((server_epoch-epoch))

if [ -n "$influxdb_url" ]; then

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
sense_o11y,host_hostname=${host_hostname},function="realtime_update_devices",source=${collector_type} difference_epoch=${difference_epoch}"

fi

##
## End Observations Timer
##

observations_end=$(date +%s%N)
observations_duration=$((observations_end-observations_start))

if [ "$debug" == "true" ]; then echo "$(date) - observations_duration:${observations_duration}"; fi

##
## Send Observations Metrics To InfluxDB
##

if [ -n "$influxdb_url" ]; then

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "

sense_o11y,host_hostname=${host_hostname},function="realtime_update_devices",source=${collector_type} duration=${observations_duration}"

fi

fi

##
## ┌┐┌┌─┐┬ ┬   ┌┬┐┬┌┬┐┌─┐┬  ┬┌┐┌┌─┐    ┌─┐┬  ┬┌─┐┌┐┌┌┬┐
## │││├┤ │││    │ ││││├┤ │  ││││├┤     ├┤ └┐┌┘├┤ │││ │ 
## ┘└┘└─┘└┴┘────┴ ┴┴ ┴└─┘┴─┘┴┘└┘└─┘────└─┘ └┘ └─┘┘└┘ ┴ 
##

if [[ $line == *"new_timeline_event"* ]]; then

##
## Start Observations Timer
##

observations_start=$(date +%s%N)

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

eval "$(echo "${line}" | jq -r '.payload.items_added[] | {"time", "type", "icon", "body", "device_id", "device_state", "user_device_type", "device_transition_from_state"} | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

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

if [ "${device_id}" != "null" ]; then url_sense_device="https://api.sense.com/apiservice/api/v1/app/monitors/${sense_monitor_id}/devices/${device_id}"; else if [ "$debug_if" == "true" ]; then echo "device_id is null. Skipping device."; fi; continue; fi

if [ "$debug" == "true" ]; then echo "url_sense_device=${url_sense_device}"; fi

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --show-error --fail ); fi

response_url_sense_device=$(curl "${curl[@]}" -k -H "Sense-Collector-Client-Version: 1.0.0" -H "X-Sense-Protocol: 3" -H "User-Agent: okhttp/3.8.0" -H "Authorization: bearer ${sense_token}" "${url_sense_device}")

if [ "$debug" == "true" ]; then echo "response_url_sense_device=${response_url_sense_device}"; fi

name=$(echo "${response_url_sense_device}" | jq -r '.device.name')

curl_message="sense_event,"

if [ "${device_id}" != "null" ]; then curl_message="device_id=${device_id},"; else echo "device_id is null. Skipping device."; continue; fi

curl_message="${curl_message}event_type=new_timeline,"

##
## Escape Names (Function)
##

if [ "${name}" != "null" ]; then escape_names; curl_message="name=${name_escaped} "; else echo "name is null. Skipping device."; continue; fi

if [ "${time}" != "null" ]; then time_epoch_ns=$(date -d"${time}" +%s%N ); time_epoch=$(date -d"${time}" +%s%3N ); curl_message="${curl_message}time=${time},"; else if [ "$debug_if" == "true" ]; then echo "time is null. Skipping device."; fi; continue; fi
if [ "${type}" != "null" ]; then curl_message="${curl_message}type=\"${type}\","; else if [ "$debug_if" == "true" ]; then echo "type is null. Skipping device."; fi; continue; fi
if [ "${icon}" != "null" ]; then curl_message="${curl_message}icon=\"${icon}\","; else if [ "$debug_if" == "true" ]; then echo "icon is null. Skipping device."; fi; continue; fi
if [ "${body}" != "null" ]; then curl_message="${curl_message}body=\"${body}\","; else if [ "$debug_if" == "true" ]; then echo "body is null. Skipping device."; fi; continue; fi

if [ "${device_state}" != "null" ]; then curl_message="${curl_message}device_state=${device_state},"; else if [ "$debug_if" == "true" ]; then echo "device_state is null. Skipping device."; fi; continue; fi
if [ "${user_device_type}" != "null" ]; then curl_message="${curl_message}user_device_type=${user_device_type},"; else if [ "$debug_if" == "true" ]; then echo "user_device_type is null. Skipping device."; fi; continue; fi
if [ "${device_transition_from_state}" != "null" ]; then curl_message="${curl_message}device_transition_from_state=${device_transition_from_state},"; else if [ "$debug_if" == "true" ]; then echo "device_transition_from_state is null. Skipping device."; fi; continue; fi
if [ "${time_epoch}" != "null" ]; then curl_message="${curl_message}time_epoch=${time_epoch},"; else if [ "$debug_if" == "true" ]; then echo "time_epoch is null. Skipping device."; fi; continue; fi

##
## Remove a comma in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/,$//')"
curl_message="${curl_message} ${time_epoch_ns}"

curl_message="sense_event,device_id=${device_id},event_type=new_timeline,name=${name_escaped} type=\"${type}\",icon=\"${icon}\",body=\"${body}\",device_state=\"${device_state}\",user_device_type=\"${user_device_type}\",device_transition_from_state=\"${device_transition_from_state}\",time_epoch=${time_epoch} ${time_epoch_ns}"

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

##
## End Observations Timer
##

observations_end=$(date +%s%N)
observations_duration=$((observations_end-observations_start))

if [ "$debug" == "true" ]; then echo "$(date) - observations_duration:${observations_duration}"; fi

##
## Send Timer Metrics To InfluxDB
##

if [ -n "$influxdb_url" ]; then

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
sense_o11y,host_hostname=${host_hostname},function="new_timeline_event",source=${collector_type} duration=${observations_duration}"

fi

fi

##
## ┬ ┬┌─┐┬  ┬  ┌─┐
## ├─┤├┤ │  │  │ │
## ┴ ┴└─┘┴─┘┴─┘└─┘
##

if [[ $line == *"hello"* ]]; then

##
## Start Observations Timer
##

observations_start=$(date +%s%N)

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

time_epoch=$(date +%s%3N)

if [ "$debug" == "true" ]; then echo "sense_event,event_type=hello time_epoch=${time_epoch}"; fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "sense_event,event_type=hello time_epoch=${time_epoch}" &

##
## End Observations Timer
##

observations_end=$(date +%s%N)
observations_duration=$((observations_end-observations_start))

if [ "$debug" == "true" ]; then echo "$(date) - observations_duration:${observations_duration}"; fi

##
## Send Timer Metrics To InfluxDB
##

if [ -n "$influxdb_url" ]; then

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
sense_o11y,host_hostname=${host_hostname},function="hello",source=${collector_type} duration=${observations_duration}"

fi

fi

done < /dev/stdin