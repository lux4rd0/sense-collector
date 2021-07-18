#!/bin/bash

##
## Sense Collector - exec-monitor-status.sh
##

##
## Sense-Collector Details
##

source sense-collector-details.sh

##
## Set Specific Variables
##

collector_type="monitor-status"

##
## Start Observations Timer
##

observations_start=$(date +%s%N)

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
sense_monitor_id=$SENSE_COLLECTOR_MONITOR_ID
sense_token=$SENSE_COLLECTOR_TOKEN

if [ "$debug" == "true" ]; then

echo "debug=${debug}
debug_curl=${debug_curl}
debug_if=${debug_if}
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

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --show-error --fail ); fi

url_sense_get_status="https://api.sense.com/apiservice/api/v1/app/monitors/${sense_monitor_id}/status"

response_url_sense_get_status=$(curl "${curl[@]}" -k -H "Sense-Collector-Client-Version: 1.0.0" -H "X-Sense-Protocol: 3" -H "User-Agent: okhttp/3.8.0" -H "Authorization: bearer ${sense_token}" "${url_sense_get_status}")

#echo "${response_url_sense_get_status}"

eval "$(echo "${response_url_sense_get_status}" | jq -r '.signals | {"progress", "status"}' | \
jq -r '. | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

eval "$(echo "${response_url_sense_get_status}" | jq -r '.monitor_info | {"ethernet", "test_result", "serial", "emac", "ndt_enabled", "wifi_strength", "online", "ip_address", "version", "ssid", "signal", "mac"}' | \
jq -r '. | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

if [ "$debug" == "true" ]; then

echo "
progress=${progress}
status=${status}
ethernet=${ethernet}
test_result=${test_result}
serial=${serial}
emac=${emac}
ndt_enabled=${ndt_enabled}
wifi_strength=${wifi_strength}
online=${online}
ip_address=${ip_address}
version=${version}
ssid=${ssid}
signal=${signal}
mac=${mac}
"

fi

curl_message="sense_monitor_status,serial=${serial} "

if [ "${progress}" != "null" ]; then curl_message="${curl_message}progress=${progress},"; else if [ "$debug_if" == "true" ]; then echo "progress is null"; fi; fi
if [ "${status}" != "null" ]; then curl_message="${curl_message}status=\"${status}\","; else if [ "$debug_if" == "true" ]; then echo "status is null"; fi; fi
if [ "${ethernet}" != "null" ]; then curl_message="${curl_message}ethernet=\"${ethernet}\","; else if [ "$debug_if" == "true" ]; then echo "ethernet is null"; fi; fi
if [ "${test_result}" != "null" ]; then curl_message="${curl_message}test_result=\"${test_result}\","; else if [ "$debug_if" == "true" ]; then echo "test_result is null"; fi; fi
if [ "${emac}" != "null" ]; then curl_message="${curl_message}emac=\"${emac}\","; else if [ "$debug_if" == "true" ]; then echo "emac is null"; fi; fi
if [ "${ndt_enabled}" != "null" ]; then curl_message="${curl_message}ndt_enabled=\"${ndt_enabled}\","; else if [ "$debug_if" == "true" ]; then echo "ndt_enabled is null"; fi; fi
if [ "${wifi_strength}" != "null" ]; then curl_message="${curl_message}wifi_strength=-${wifi_strength},"; else if [ "$debug_if" == "true" ]; then echo "wifi_strength is null"; fi; fi
if [ "${online}" != "null" ]; then curl_message="${curl_message}online=\"${online}\","; else if [ "$debug_if" == "true" ]; then echo "online is null"; fi; fi
if [ "${ip_address}" != "null" ]; then curl_message="${curl_message}ip_address=\"${ip_address}\","; else if [ "$debug_if" == "true" ]; then echo "ip_address is null"; fi; fi
if [ "${version}" != "null" ]; then curl_message="${curl_message}version=\"${version}\","; else if [ "$debug_if" == "true" ]; then echo "version is null"; fi; fi
if [ "${ssid}" != "null" ]; then curl_message="${curl_message}ssid=\"${ssid}\","; else if [ "$debug_if" == "true" ]; then echo "ssid is null"; fi; fi
if [ "${signal}" != "null" ]; then curl_message="${curl_message}signal=\"${signal}\","; else if [ "$debug_if" == "true" ]; then echo "signal is null"; fi; fi
if [ "${mac}" != "null" ]; then curl_message="${curl_message}mac=\"${mac}\","; else if [ "$debug_if" == "true" ]; then echo "mac is null"; fi; fi

##
## Remove a trailing comma in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/,$//')"

if [ "$debug" == "true" ]; then

echo "${curl_message}"

fi

if [ "$curl_debug" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

##
## Device Detection - In Progress
##

number_of_devices_in_progress=$(echo "${response_url_sense_get_status}" | jq '.device_detection.in_progress | length')

number_of_devices_in_progress_minus_one=$((number_of_devices_in_progress-1))

if [ "$debug" == "true" ]; then

echo "number_of_devices_in_progress=${number_of_devices_in_progress}"

fi

for device_number in $(seq 0 $number_of_devices_in_progress_minus_one) ; do

eval "$(echo "${response_url_sense_get_status}" | jq -r '.device_detection.in_progress['"$device_number"'] | {"icon", "name", "progress"}' | \
jq -r '. | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

if [ "$debug" == "true" ]; then

echo "Device Detection - In Progress"

echo "
icon=${icon}
name=${name}
progress=${progress}"

fi

##
## Escape Names (Function)
##

escape_names

curl_message="sense_monitor_device_detection,detection_type=in_progress,name=${name_escaped},serial=${serial} "

if [ "${icon}" != "null" ]; then curl_message="${curl_message}icon=\"${icon}\","; else if [ "$debug_if" == "true" ]; then echo "icon is null"; fi; fi
if [ "${progress}" != "null" ]; then curl_message="${curl_message}progress=${progress},"; else if [ "$debug_if" == "true" ]; then echo "progress is null"; fi; fi

##
## Remove a trailing comma in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/,$//')"

if [ "$debug" == "true" ]; then

echo "${curl_message}"

fi

if [ "$curl_debug" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

done

##
## Device Detection - Found
##

number_of_devices_found=$(echo "${response_url_sense_get_status}" | jq '.device_detection.found | length')

number_of_devices_found_minus_one=$((number_of_devices_found-1))

if [ "$debug" == "true" ]; then

echo "number_of_devices_found=${number_of_devices_found}"

fi

for device_number in $(seq 0 $number_of_devices_found_minus_one) ; do

eval "$(echo "${response_url_sense_get_status}" | jq -r '.device_detection.found['"$device_number"'] | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

if [ "$debug" == "true" ]; then

echo "Device Detection - Found"

echo "
icon=${icon}
name=${name}
progress=${progress}"
fi

##
## Escape Names (Function)
##

escape_names

curl_message="sense_monitor_device_detection,detection_type=found,name=${name_escaped},serial=${serial} "

if [ "${icon}" != "null" ]; then curl_message="${curl_message}icon=\"${icon}\","; else if [ "$debug_if" == "true" ]; then echo "icon is null"; fi; fi
if [ "${progress}" != "null" ]; then curl_message="${curl_message}progress=${progress},"; else if [ "$debug_if" == "true" ]; then echo "progress is null"; fi; fi

##
## Remove a trailing comma in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/,$//')"

if [ "$debug" == "true" ]; then

echo "${curl_message}"

fi

if [ "$curl_debug" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

done

##
## Device Detection - Number Detected
##

num_detected=$(echo "${response_url_sense_get_status}" | jq -r '.device_detection.num_detected')

if [ "$debug" == "true" ]; then

echo "Device Detection - Number Detected"
echo "num_detected=${num_detected}"
fi

curl_message="sense_monitor_device_detection,serial=${serial} num_detected=${num_detected}"

if [ "$debug" == "true" ]; then

echo "${curl_message}"

fi

if [ "$curl_debug" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

wait

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
sense_o11y,host_hostname=${host_hostname},function="monitor_status",source=${collector_type} duration=${observations_duration}"

fi