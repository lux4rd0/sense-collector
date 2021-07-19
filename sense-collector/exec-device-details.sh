#!/bin/bash

##
## Sense Collector - exec-sense-device-details.sh
##

##
## Sense-Collector Details
##

source sense-collector-details.sh

##
## Set Specific Variables
##

collector_type="device-details"

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
sense_monitor_id=${sense_monitor_id}
sense_token=${sense_token}
threads=${threads}"

fi

##
## Curl Command
##

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --show-error --fail ); fi

url_sense_get_devices="https://api.sense.com/apiservice/api/v1/app/monitors/${sense_monitor_id}/devices"

response_url_sense_get_devices=$(curl "${curl[@]}" -k -H "Sense-Collector-Client-Version: 1.0.0" -H "X-Sense-Protocol: 3" -H "User-Agent: okhttp/3.8.0" -H "Authorization: bearer ${sense_token}" "${url_sense_get_devices}")

#echo "${response_url_sense_get_devices}"

devices=($(echo "${response_url_sense_get_devices}" | jq -r '.[].id | @sh' | tr -d \'))

number_of_devices=$(echo "${response_url_sense_get_devices}" | jq '. | length')

number_of_devices_minus_one=$((number_of_devices-1))

#echo "number_of_devices=${number_of_devices}"
#echo "devices=${devices[@]}"

##
## Start "threading"
##

for device_number in $(seq 0 $number_of_devices_minus_one) ; do

#(

url_sense_device="https://api.sense.com/apiservice/api/v1/app/monitors/${sense_monitor_id}/devices/${devices[device_number]}"

#echo "url_sense_device=${url_sense_device}"
#echo "device_id=${devices[device_number]}"

if [ "${devices[device_number]}" == "unknown" ] || [ "${devices[device_number]}" == "always_on" ] || [ "${devices[device_number]}" == "Other" ]; then continue; fi

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --show-error --fail ); fi

response_url_sense_device=$(curl "${curl[@]}" -k -H "Sense-Collector-Client-Version: 1.0.0" -H "X-Sense-Protocol: 3" -H "User-Agent: okhttp/3.8.0" -H "Authorization: bearer ${sense_token}" "${url_sense_device}")

#name=$(echo "${response_url_sense_device}" | jq -r .device.name)

eval "$(echo "${response_url_sense_device}" | jq -r '.usage | {"current_month_runs", "current_month_KWH", "avg_monthly_runs", "avg_monthly_KWH", "avg_monthly_pct", "avg_watts", "avg_duration", "yearly_KWH", "yearly_text", "yearly_cost", "current_month_cost", "avg_monthly_cost"} | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

if [ "$debug" == "true" ]; then

echo "
current_month_runs=${current_month_runs}
current_month_KWH=${current_month_KWH}
avg_monthly_runs=${avg_monthly_runs}
avg_monthly_KWH=${avg_monthly_KWH}
avg_monthly_pct=${avg_monthly_pct}
avg_watts=${avg_watts}
avg_duration=${avg_duration}
yearly_KWH=${yearly_KWH}
yearly_text=${yearly_text}
yearly_cost=${yearly_cost}
current_month_cost=${current_month_cost}
avg_monthly_cost=${avg_monthly_cost}"

fi

eval "$(echo "${response_url_sense_device}" | jq -r '.device | {"name", "icon", "last_state", "last_state_time"}' | jq -r '. | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

if [ "${last_state_time}" != "null" ]; then last_state_time_epoch=$(date -d"${last_state_time}" +%s%3N ); else if [ "$debug_if" == "true" ]; then echo "last_state_time is null"; fi; fi
if [ "${last_state_time}" != "null" ]; then last_state_time_ns=$(date -d"${last_state_time}" +%s%N ); else if [ "$debug_if" == "true" ]; then echo "last_state_time is null"; fi; fi

if [ "$debug" == "true" ]; then

echo "
name=${name}
icon=${icon}
last_state=${last_state}
last_state_time=${last_state_time}
last_state_time_epoch=${last_state_time_epoch}
last_state_time_ns=${last_state_time_ns}
"

fi

if [ "$debug" == "true" ]; then echo "loop=${device_number} - name=${name} - device_id=${devices[$device_number]}"; fi

##
## Escape Names (Function)
##

escape_names

curl_message="sense_devices,device_id=${devices[device_number]},name=${name_escaped} "

if [ "${current_month_runs}" != "null" ]; then curl_message="${curl_message}current_month_runs=${current_month_runs},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} current_month_runs is null"; fi; fi
if [ "${current_month_KWH}" != "null" ]; then curl_message="${curl_message}current_month_KWH=${current_month_KWH},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} current_month_KWH is null"; fi; fi
if [ "${avg_monthly_runs}" != "null" ]; then curl_message="${curl_message}avg_monthly_runs=${avg_monthly_runs},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} avg_monthly_runs is null"; fi; fi
if [ "${avg_monthly_KWH}" != "null" ]; then curl_message="${curl_message}avg_monthly_KWH=${avg_monthly_KWH},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} avg_monthly_KWH is null"; fi; fi
if [ "${avg_monthly_pct}" != "null" ]; then curl_message="${curl_message}avg_monthly_pct=${avg_monthly_pct},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} avg_monthly_pct is null"; fi; fi
if [ "${avg_watts}" != "null" ]; then curl_message="${curl_message}avg_watts=${avg_watts},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} avg_watts is null"; fi; fi
if [ "${avg_duration}" != "null" ]; then curl_message="${curl_message}avg_duration=${avg_duration},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} avg_duration is null"; fi; fi
if [ "${yearly_KWH}" != "null" ]; then curl_message="${curl_message}yearly_KWH=${yearly_KWH},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} yearly_KWH is null"; fi; fi
if [ "${yearly_text}" != "null" ]; then curl_message="${curl_message}yearly_text=\"${yearly_text}\","; else if [ "$debug_if" == "true" ]; then echo "name=${name} yearly_text is null"; fi; fi
if [ "${yearly_cost}" != "null" ]; then yearly_cost_dollars=$(echo "scale=2; ${yearly_cost}/100" | bc); curl_message="${curl_message}yearly_cost=${yearly_cost_dollars},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} yearly_cost is null"; fi; fi
if [ "${current_month_cost}" != "null" ]; then current_month_cost_dollars=$(echo "scale=2; ${current_month_cost}/100" | bc); curl_message="${curl_message}current_month_cost=${current_month_cost_dollars},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} current_month_cost is null"; fi; fi
if [ "${icon}" != "null" ]; then curl_message="${curl_message}icon=\"${icon}\","; else if [ "$debug_if" == "true" ]; then echo "name=${name} icon is null"; fi; fi
if [ "${last_state}" != "null" ]; then curl_message="${curl_message}last_state=\"${last_state}\","; else if [ "$debug_if" == "true" ]; then echo "name=${name} last_state is ${last_state} - null"; fi; fi
if [ -n "${last_state_time_epoch}" ]; then curl_message="${curl_message}last_state_time_epoch=${last_state_time_epoch},"; else if [ "$debug_if" == "true" ]; then echo "name=${name} last_state_time_epoch is empty"; fi; fi

##
## Remove a trailing comma in curl_message if the last element happens to be null (so that there's still a properly formatted InfluxDB mmessage)
##

curl_message="$(echo "${curl_message}" | sed 's/,$//')"

if [ "$debug" == "true" ]; then echo "${curl_message}"; fi

if [ "$curl_debug" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

#) &

#if [[ $(jobs -r -p | wc -l) -ge $threads ]]; then wait -n; fi

done

#wait

if [ "$debug" == "true" ]; then echo "Device Loop Finished"; fi

##
## End "threading"
##

##
## Always On
##

url_sense_device="https://api.sense.com/apiservice/api/v1/app/monitors/${sense_monitor_id}/devices/always_on"

if [ "$debug_curl" == "true" ]; then curl=(  ); else curl=( --silent --show-error --fail ); fi

response_url_sense_device=$(curl "${curl[@]}" -k -H "Sense-Collector-Client-Version: 1.0.0" -H "X-Sense-Protocol: 3" -H "User-Agent: okhttp/3.8.0" -H "Authorization: bearer ${sense_token}" "${url_sense_device}")

eval "$(echo "${response_url_sense_device}" | jq -r '.usage | {"avg_monthly_KWH", "avg_monthly_pct", "avg_watts", "yearly_KWH", "yearly_text", "yearly_cost", "avg_monthly_cost", "current_ao_wattage"} | to_entries | .[] | .key + "=" + "\"" + ( .value|tostring ) + "\""')"

if [ "$debug" == "true" ]; then

echo "
avg_monthly_KWH=${avg_monthly_KWH}
avg_monthly_pct=${avg_monthly_pct}
avg_watts=${avg_watts}
yearly_KWH=${yearly_KWH}
yearly_text=${yearly_text}
yearly_cost=${yearly_cost}
avg_monthly_cost=${avg_monthly_cost}
current_ao_wattage=${current_ao_wattage}
"
fi

curl_message="sense_devices,device_id=${devices[device_number]},name=Always\ On "

if [ "${avg_monthly_KWH}" != "null" ]; then curl_message="${curl_message}avg_monthly_KWH=${avg_monthly_KWH},"; else if [ "$debug_if" == "true" ]; then echo "avg_monthly_KWH is null"; fi; fi
if [ "${avg_monthly_pct}" != "null" ]; then curl_message="${curl_message}avg_monthly_pct=${avg_monthly_pct},"; else if [ "$debug_if" == "true" ]; then echo "avg_monthly_pct is null"; fi; fi
if [ "${avg_watts}" != "null" ]; then curl_message="${curl_message}avg_watts=${avg_watts},"; else if [ "$debug_if" == "true" ]; then echo "avg_watts is null"; fi; fi
if [ "${yearly_KWH}" != "null" ]; then curl_message="${curl_message}yearly_KWH=${yearly_KWH},"; else if [ "$debug_if" == "true" ]; then echo "yearly_KWH is null"; fi; fi
if [ "${yearly_text}" != "null" ]; then curl_message="${curl_message}yearly_text=\"${yearly_text}\","; else if [ "$debug_if" == "true" ]; then echo "yearly_text is null"; fi; fi
if [ "${yearly_cost}" != "null" ]; yearly_cost_dollars=$(echo "scale=2; ${yearly_cost}/100" | bc); then curl_message="${curl_message}yearly_cost=${yearly_cost_dollars},"; else if [ "$debug_if" == "true" ]; then echo "yearly_cost is null"; fi; fi
if [ "${avg_monthly_cost}" != "null" ]; then curl_message="${curl_message}avg_monthly_cost=${avg_monthly_cost},"; else if [ "$debug_if" == "true" ]; then echo "avg_monthly_cost is null"; fi; fi
if [ "${current_ao_wattage}" != "null" ]; then curl_message="${curl_message}current_ao_wattage=${current_ao_wattage},"; else if [ "$debug_if" == "true" ]; then echo "current_ao_wattage is null"; fi; fi

##
## Add our own Icon for Always On
##

curl_message="${curl_message}icon=\"always_on\""

if [ "$debug" == "true" ]; then echo "${curl_message}"; fi

if [ "$curl_debug" == "true" ]; then curl=(  ); else curl=( --silent --output /dev/null --show-error --fail ); fi

/usr/bin/timeout -k 1 10s curl "${curl[@]}" --connect-timeout 2 --max-time 2 --retry 5 --retry-delay 0 --retry-max-time 30 -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "${curl_message}" &

#wait

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
sense_o11y,host_hostname=${host_hostname},function="device_details",source=${collector_type} duration=${observations_duration}"

fi