import asyncio
import aiohttp
from datetime import datetime, timezone
from influxdb_client import InfluxDBClient, Point, WriteOptions
from influxdb_client.client.write_api import ASYNCHRONOUS
import logging
from dateutil import parser
import pytz
from collections import defaultdict

# Configure logging
storage_logger = logging.getLogger("storage")


class InfluxDBStorage:
    def __init__(self, influxdb_params):
        self.influxdb_client = InfluxDBClient(
            url=influxdb_params["url"],
            token=influxdb_params["token"],
            org=influxdb_params["org"],
        )
        self.bucket = influxdb_params["bucket"]

        write_options = WriteOptions(
            write_type=ASYNCHRONOUS,
            batch_size=10000,
            flush_interval=10000,
        )
        self.write_api = self.influxdb_client.write_api(write_options=write_options)

        # Initialize a local cache for device names
        self.device_name_cache = {}

        # Queue for device data awaiting names
        self.device_data_queue = defaultdict(list)

        # Start the task to process the device data queue
        asyncio.create_task(self.process_device_queue())

    async def persist_realtime_data(
        self,
        monitor_id,
        hertz,
        total_current,
        total_watts,
        epoch,
        voltage,
        devices,
        channels,
    ):
        storage_logger.debug("Persisting realtime data")

        current_time = datetime.now(timezone.utc)
        epoch_time = datetime.fromtimestamp(epoch, timezone.utc)
        time_difference = (current_time - epoch_time).total_seconds()

        storage_logger.debug(f"Time difference: {time_difference}")

        try:
            main_point = (
                Point("sense_mains")
                .tag("monitor_id", monitor_id)
                .field("hertz", hertz)
                .field("current", total_current)
                .field("watts", total_watts)
                .time(epoch, write_precision="s")
            )

            channel_point_1 = (
                Point("sense_mains")
                .tag("monitor_id", monitor_id)
                .tag("leg", "L1")
                .field("watts", channels[0])
                .time(epoch, write_precision="s")
            )

            channel_point_2 = (
                Point("sense_mains")
                .tag("monitor_id", monitor_id)
                .tag("leg", "L2")
                .field("watts", channels[1])
                .time(epoch, write_precision="s")
            )

            voltage_point_1 = (
                Point("sense_mains")
                .tag("monitor_id", monitor_id)
                .tag("leg", "L1")
                .field("voltage", voltage[0])
                .time(epoch, write_precision="s")
            )

            voltage_point_2 = (
                Point("sense_mains")
                .tag("monitor_id", monitor_id)
                .tag("leg", "L2")
                .field("voltage", voltage[1])
                .time(epoch, write_precision="s")
            )

            o11y_point = (
                Point("sense_o11y")
                .tag("monitor_id", monitor_id)
                .field("time_difference", time_difference)
                .time(epoch, write_precision="s")
            )

            points = [
                main_point,
                channel_point_1,
                channel_point_2,
                voltage_point_1,
                voltage_point_2,
                o11y_point,
            ]

            for device in devices:
                device_id = device.get("id")
                device_watts = device.get("w")
                device_name = device.get("name")
                device_icon = device.get("icon")
                device_sd = device.get("sd", {})
                is_plug = any(
                    device_sd.get(key) is not None for key in ["w", "i", "v", "e"]
                )

                # Add detailed debug logging
                storage_logger.debug(f"Processing device {device_id} - {device_name}")
                storage_logger.debug(f"Device Watts: {device_watts}")
                storage_logger.debug(f"Always On Watts (ao_w): {device.get('ao_w')}")
                storage_logger.debug(f"Always On State (ao_st): {device.get('ao_st')}")
                storage_logger.debug(f"Device SD: {device_sd}")

                device_point = (
                    Point("sense_devices")
                    .tag("monitor_id", monitor_id)
                    .tag("device_id", device_id)
                    .tag("device_name", device_name)
                    .tag("is_plug", str(is_plug).lower())
                    .field("icon", device_icon)
                    .field("watts", device_watts)
                    .field("sd_watts", device_sd.get("w"))
                    .field("sd_current", device_sd.get("i"))
                    .field("sd_voltage", device_sd.get("v"))
                    .field("sd_energy", device_sd.get("e"))
                    .field("always_on_watts", device.get("ao_w"))
                    .field("always_on_state", device.get("ao_st"))
                    .time(epoch, write_precision="s")
                )

                points.append(device_point)

            await self.write_points(points)
        except Exception as e:
            storage_logger.error(f"Error preparing points for InfluxDB: {e}")

    async def persist_device_data(self, device_data):
        storage_logger.debug("Persisting device data")
        storage_logger.debug(f"Device data: {device_data}")

        try:
            device_info = device_data.get("device", {})
            device_id = device_info.get("id")
            device_name = device_info.get("name")
            icon = device_info.get("icon")
            monitor_id = device_info.get("monitor_id")

            # Cache the device name
            self.device_name_cache[device_id] = device_name

            last_state_timestamp_seconds = None
            if "last_state_time" in device_info:
                last_state_timestamp = parser.parse(
                    device_info["last_state_time"]
                ).astimezone(pytz.UTC)
                last_state_timestamp_seconds = int(last_state_timestamp.timestamp())

            timestamp = int(datetime.now(timezone.utc).timestamp())

            if device_id == "always_on":
                # Handle the special "always_on" device
                await self.process_always_on_device(
                    device_id, device_name, device_data, timestamp, monitor_id, icon
                )
            else:
                # Handle regular devices
                await self.process_regular_device(
                    device_id, device_name, device_data, timestamp, monitor_id, icon
                )

        except KeyError as e:
            storage_logger.error(
                f"KeyError in persist_device_data: {e}, device_data: {device_data}"
            )
        except Exception as e:
            storage_logger.error(
                f"Error in persist_device_data: {e}, device_data: {device_data}"
            )

    async def process_regular_device(
        self, device_id, device_name, device_data, timestamp, monitor_id, icon
    ):
        storage_logger.debug(f"Processing regular device: {device_id} - {device_name}")
        device_detail_point = (
            Point("sense_devices")
            .tag("device_id", device_id)
            .tag("device_name", device_name)
            .tag("monitor_id", monitor_id)
            .field("icon", icon)
            .time(timestamp, write_precision="s")
        )

        storage_logger.debug(
            f"Tags - device_id: {device_id}, device_name: {device_name}, monitor_id: {monitor_id}"
        )
        storage_logger.debug(f"Field - icon: {icon}")

        device_info = device_data.get("device", {})
        if device_info.get("last_state") is not None:
            device_detail_point.field("last_state", device_info["last_state"])
            storage_logger.debug(f"Field - last_state: {device_info['last_state']}")
        if "last_state_time" in device_info:
            last_state_timestamp = parser.parse(
                device_info["last_state_time"]
            ).astimezone(pytz.UTC)
            last_state_timestamp_seconds = int(last_state_timestamp.timestamp())
            device_detail_point.field("last_state_time", last_state_timestamp_seconds)
            storage_logger.debug(
                f"Field - last_state_time: {last_state_timestamp_seconds}"
            )

        for field, value in device_data.get("usage", {}).items():
            if value is not None:
                device_detail_point.field(
                    field, float(value) / 100 if field == "yearly_cost" else value
                )
                storage_logger.debug(f"Field - {field}: {value}")

        if device_data.get("info") is not None:
            device_detail_point.field("info", str(device_data["info"]))
            storage_logger.debug(f"Field - info: {device_data['info']}")

        await self.write_points([device_detail_point])
        storage_logger.debug(f"Persisted device data for {device_id}")

    async def process_always_on_device(
        self, device_id, device_name, device_data, timestamp, monitor_id, icon
    ):
        storage_logger.debug(
            f"Processing always_on device: {device_id} - {device_name}"
        )
        usage = device_data.get("usage", {})
        always_on = device_data.get("always_on", {})
        comparison = usage.get("comparison", {})

        device_detail_point = (
            Point("sense_always_on")
            .tag("device_id", device_id)
            .tag("device_name", device_name)
            .tag("monitor_id", monitor_id)
            .field("icon", icon)
            .field("avg_monthly_KWH", usage.get("avg_monthly_KWH"))
            .field("avg_monthly_pct", usage.get("avg_monthly_pct"))
            .field("avg_watts", usage.get("avg_watts"))
            .field("yearly_KWH", usage.get("yearly_KWH"))
            .field("yearly_cost", usage.get("yearly_cost"))
            .field("avg_monthly_cost", usage.get("avg_monthly_cost"))
            .field("current_ao_wattage", usage.get("current_ao_wattage"))
            .time(timestamp, write_precision="s")
        )

        await self.write_points([device_detail_point])

        # Persist comparison data as a related metric
        comparison_point = (
            Point("sense_always_on_comparison")
            .tag("device_id", device_id)
            .tag("monitor_id", monitor_id)
            .field("comparison_text", comparison.get("comparison_text"))
            .field("comparison_summary_text", comparison.get("comparison_summary_text"))
            .field("title", comparison.get("title"))
            .field("count", comparison.get("count"))
            .field("display_count", comparison.get("display_count"))
            .field("cohort_marker", comparison.get("cohort_marker"))
            .field("cohort_avg_w", comparison.get("cohort_avg_w"))
            .time(timestamp, write_precision="s")
        )

        cohort = comparison.get("cohort", {})
        if cohort:
            comparison_point.field("cohort_id", cohort.get("id"))
            comparison_point.field("cohort_area_code", cohort.get("area_code"))
            comparison_point.field("cohort_state", cohort.get("state"))
            comparison_point.field("cohort_home_size", cohort.get("home_size"))

        await self.write_points([comparison_point])

        # Handle devices within "always_on"
        for device in always_on.get("devices", []):
            device_id = device.get("id")
            device_watts = device.get("w")

            # Check if the device name is cached
            if device_id not in self.device_name_cache:
                # If not cached, add to queue for later processing
                storage_logger.debug(
                    f"Device name for {device_id} not in cache. Queuing for later."
                )
                self.device_data_queue[device_id].append(
                    (monitor_id, device_watts, timestamp)
                )
            else:
                device_name = self.device_name_cache[device_id]
                storage_logger.debug(f"Device {device_id} - {device_name}")

                device_point = (
                    Point("sense_always_on_devices")
                    .tag("monitor_id", monitor_id)
                    .tag("parent_device_id", "always_on")
                    .tag("device_id", device_id)
                    .tag("device_name", device_name)  # Include device_name tag
                    .field("watts", device_watts)
                    .time(timestamp, write_precision="s")
                )

                await self.write_points([device_point])

    async def process_device_queue(self):
        while True:
            for device_id, data_list in list(self.device_data_queue.items()):
                if device_id in self.device_name_cache:
                    device_name = self.device_name_cache[device_id]
                    for monitor_id, device_watts, timestamp in data_list:
                        storage_logger.debug(
                            f"Processing queued data for device {device_id} - {device_name}"
                        )
                        device_point = (
                            Point("sense_always_on_devices")
                            .tag("monitor_id", monitor_id)
                            .tag("parent_device_id", "always_on")
                            .tag("device_id", device_id)
                            .tag("device_name", device_name)  # Include device_name tag
                            .field("watts", device_watts)
                            .time(timestamp, write_precision="s")
                        )
                        await self.write_points([device_point])
                    del self.device_data_queue[device_id]
            await asyncio.sleep(1)  # Sleep briefly to avoid busy waiting

    async def write_points(self, points):
        storage_logger.debug("Writing points to InfluxDB")
        try:
            self.write_api.write(
                bucket=self.bucket,
                org=self.influxdb_client.org,
                record=points,
                write_precision="s",
            )
        except Exception as e:
            storage_logger.error(f"Error writing points to InfluxDB: {e}")
            for point in points:
                storage_logger.error(f"Point: {point.to_line_protocol()}")

    async def persist_timeline_data(
        self,
        device_id,
        device_name,
        time,
        event_type,
        icon,
        body,
        device_state,
        user_device_type,
        device_transition_from_state,
    ):
        timeline_point = (
            Point("sense_event")
            .tag("device_id", device_id)
            .tag("device_name", device_name)
            .field("time", time)
            .field("type", event_type)
            .field("icon", icon)
            .field("body", body)
            .field("device_state", device_state)
            .field("user_device_type", user_device_type)
            .field("device_transition_from_state", device_transition_from_state)
            .time(time, write_precision="s")
        )
        await self.write_points([timeline_point])

    async def persist_hello_event(self, monitor_id, online_status, timestamp):
        hello_point = (
            Point("hello_event")
            .tag("monitor_id", monitor_id)
            .field("online", online_status)
            .time(timestamp, write_precision="s")
        )
        await self.write_points([hello_point])

    async def persist_data_change_event(
        self,
        monitor_id,
        device_id,
        user_version,
        guid,
        epoch_timestamp,
        influxdb_timestamp,
    ):
        data_change_point = (
            Point("data_change_event")
            .tag("monitor_id", monitor_id)
            .tag("device_id", device_id)
            .field("user_version", user_version)
            .field("guid", guid)
            .field("json_timestamp", epoch_timestamp)
            .time(influxdb_timestamp, write_precision="s")
        )
        await self.write_points([data_change_point])

    async def persist_device_state(
        self, monitor_id, device_id, mode, device_state, timestamp
    ):
        device_state_point = (
            Point("device_state_event")
            .tag("monitor_id", monitor_id)
            .tag("device_id", device_id)
            .field("mode", mode)
            .field("state", device_state)
            .time(timestamp, write_precision="s")
        )
        await self.write_points([device_state_point])

    async def persist_monitor_status(self, monitor_id, monitor_status):
        storage_logger.debug(f"Persisting monitor status for monitor_id: {monitor_id}")
        storage_logger.debug(f"Monitor status data: {monitor_status}")

        try:
            timestamp = int(datetime.now(timezone.utc).timestamp())
            signals = monitor_status.get("signals", {})
            monitor_info = monitor_status.get("monitor_info", {})
            wifi_strength = float(monitor_info.get("wifi_strength", 0))

            monitor_info_point = (
                Point("sense_monitor_status")
                .tag("monitor_id", monitor_id)
                .field("ethernet", monitor_info.get("ethernet"))
                .field("online", monitor_info.get("online"))
                .field("ip_address", monitor_info.get("ip_address"))
                .field("version", monitor_info.get("version"))
                .field("ssid", monitor_info.get("ssid"))
                .field("ndt_enabled", monitor_info.get("ndt_enabled"))
                .field("mac", monitor_info.get("mac"))
                .field("progress", float(signals.get("progress")))
                .field("status", signals.get("status"))
                .time(timestamp, write_precision="s")
            )

            if wifi_strength != 0:
                monitor_info_point.field("wifi_strength", wifi_strength)

            await self.write_points([monitor_info_point])

            device_detection = monitor_status.get("device_detection", {})
            points = []
            for status in ["in_progress", "found"]:
                for device in device_detection.get(status, []):
                    points.append(
                        Point("sense_device_detection")
                        .tag("monitor_id", monitor_id)
                        .tag("status", status)
                        .field("icon", device.get("icon"))
                        .tag("name", device.get("name"))
                        .field("progress", float(device.get("progress", 0)))
                        .time(timestamp, write_precision="s")
                    )

            await self.write_points(points)
            storage_logger.debug(f"Persisted monitor status for {monitor_id}")

        except KeyError as e:
            storage_logger.error(
                f"KeyError in persist_monitor_status: {e}, monitor_status: {monitor_status}"
            )
        except Exception as e:
            storage_logger.error(
                f"Error in persist_monitor_status: {e}, monitor_status: {monitor_status}"
            )

    async def write_points(self, points):
        storage_logger.debug("Writing points to InfluxDB")
        try:
            self.write_api.write(
                bucket=self.bucket,
                org=self.influxdb_client.org,
                record=points,
                write_precision="s",
            )
        except Exception as e:
            storage_logger.error(f"Error writing points to InfluxDB: {e}")
            for point in points:
                storage_logger.error(f"Point: {point.to_line_protocol()}")
