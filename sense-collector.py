import asyncio
import json
import os
import sys
import time
from datetime import datetime, timezone, timedelta
import aiohttp
from storage import InfluxDBStorage
import logging

# Configure logging based on environment variables
log_level_api = os.getenv("SENSE_COLLECTOR_LOG_LEVEL_API", "INFO").upper()
log_level_storage = os.getenv("SENSE_COLLECTOR_LOG_LEVEL_STORAGE", "INFO").upper()
log_level_general = os.getenv("SENSE_COLLECTOR_LOG_LEVEL_GENERAL", "INFO").upper()
sense_api_receive_data_output = (
    os.getenv("SENSE_COLLECTOR_SENSE_API_RECEIVE_DATA_OUTPUT", "false").lower()
    == "true"
)


logging.basicConfig(
    format="%(asctime)s %(levelname)s:%(name)s:%(message)s",
    handlers=[logging.StreamHandler()],
)

# Create loggers
logger = logging.getLogger("general")
logger.setLevel(log_level_general)

api_logger = logging.getLogger("api")
api_logger.setLevel(log_level_api)

storage_logger = logging.getLogger("storage")
storage_logger.setLevel(log_level_storage)

# Retrieve the export folder path from the environment variable
export_folder = os.getenv("SENSE_COLLECTOR_EXPORT_FOLDER", "export")

# Ensure the export folder exists and is writable
os.makedirs(export_folder, exist_ok=True)
if not os.access(export_folder, os.W_OK):
    raise PermissionError(f"Export folder {export_folder} is not writable")


class SenseAPIEndpoints:
    BASE_URL = "https://api.sense.com/apiservice/api/v1"
    AUTHENTICATE = f"{BASE_URL}/authenticate"
    TIMELINE = f"{BASE_URL}/users/{{user_id}}/timeline"
    DEVICE_DATA = f"{BASE_URL}/app/monitors/{{monitor_id}}/devices/{{device_id}}"
    MONITOR_STATUS = f"{BASE_URL}/app/monitors/{{monitor_id}}/status"
    WS_BASE_URL = "wss://clientrt.sense.com"
    REALTIME_FEED = f"{WS_BASE_URL}/monitors/{{monitor_id}}/realtimefeed"


async def authenticate_with_sense(username, password):
    url = SenseAPIEndpoints.AUTHENTICATE
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {"email": username, "password": password}
    async with aiohttp.ClientSession() as session:
        async with session.post(url, headers=headers, data=data) as response:
            response.raise_for_status()
            return await response.json()


class SenseCollector:
    def __init__(
        self,
        monitor_id,
        token,
        influxdb_storage,
        user_id,
        cache_expiry_seconds=120,
        max_concurrent_lookups=4,
        lookup_delay_seconds=1,
    ):
        self.monitor_id = monitor_id
        self.token = token
        self.user_id = user_id
        self.ws_url = (
            f"wss://clientrt.sense.com/monitors/{self.monitor_id}/realtimefeed"
        )
        self.headers = {
            "Authorization": f"bearer {self.token}",
            "Sense-Collector-Client-Version": "2.0.0",
            "X-Sense-Protocol": "3",
            "User-Agent": "okhttp/3.8.0",
        }
        self.influxdb_storage = influxdb_storage
        self.api_call_queue = asyncio.Queue()
        self.device_cache = {}
        self.cache_expiry_seconds = cache_expiry_seconds
        self.max_concurrent_lookups = max_concurrent_lookups
        self.lookup_delay_seconds = lookup_delay_seconds
        self.semaphore = asyncio.Semaphore(max_concurrent_lookups)
        self.session = None

    async def start_session(self):
        self.session = aiohttp.ClientSession()

    async def close_session(self):
        if self.session:
            await self.session.close()

    async def api_worker(self):
        while True:
            queue_item = await self.api_call_queue.get()
            device_id = queue_item.get("device_id")

            try:
                device_data = await self.lookup_device_data(device_id)
                if device_data:
                    await self.influxdb_storage.persist_device_data(device_data)
            except Exception as e:
                api_logger.error(f"Error processing device {device_id}: {e}")
            finally:
                self.api_call_queue.task_done()

    async def create_connection(self, max_retries=3, backoff_factor=1):
        ws_url = SenseAPIEndpoints.REALTIME_FEED.format(monitor_id=self.monitor_id)
        for attempt in range(max_retries):
            try:
                self.ws = await self.session.ws_connect(ws_url, headers=self.headers)
                api_logger.info("Created WebSocket connection")
                return
            except (
                aiohttp.ClientError,
                asyncio.TimeoutError,
            ) as e:
                api_logger.warning(f"Retry {attempt + 1} for WebSocket connection: {e}")
                if attempt < max_retries - 1:
                    sleep_time = backoff_factor * (2**attempt)
                    await asyncio.sleep(sleep_time)
                else:
                    raise  # Re-raise the last exception if all retries fail

    async def close_connection(self):
        if self.ws:
            await self.ws.close()
            api_logger.info("Closed WebSocket connection")

    async def receive_data(self):
        api_logger.info("Starting data reception")

        while True:
            try:
                await self.create_connection()
                async for msg in self.ws:
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        data = json.loads(msg.data)
                        if sense_api_receive_data_output:
                            export_file_path = os.path.join(
                                export_folder, "received_data.json"
                            )
                            with open(export_file_path, "a") as f:
                                f.write(json.dumps(data) + "\n")
                        await self.process_and_send_data(data)
            except Exception as e:
                api_logger.error(f"Error in data reception: {e}")
            finally:
                await self.close_connection()
                api_logger.info("Stopped data reception")

            # Reconnect after a brief delay
            api_logger.info("Attempting to reconnect in 5 seconds...")
            await asyncio.sleep(5)

    async def process_and_send_data(self, data):
        api_logger.info("Starting to process and send data")
        # api_logger.debug(f"Received data: {data}")

        try:
            data_type = data.get("type")
            api_logger.debug(f"Data type: {data_type}")

            if data_type == "realtime_update":
                api_logger.info("Processing realtime update")
                await self.handle_realtime_update(data["payload"])
            elif data_type == "new_timeline_event":
                api_logger.info("Processing new timeline event")
                await self.handle_new_timeline_event(data["payload"])
            elif data_type == "hello":
                api_logger.info("Processing hello event")
                await self.handle_hello_event(data["payload"])
            elif data_type == "data_change":
                api_logger.info("Processing data change event")
                await self.handle_data_change_event(data["payload"])
            elif data_type == "device_states":
                api_logger.info("Processing device states event")
                await self.handle_device_states_event(data["payload"])
            else:
                api_logger.warning(f"Unknown data type received: {data_type}")

        except Exception as e:
            api_logger.error(f"Error processing data: {e}")
        finally:
            api_logger.info("Finished processing and sending data")

    async def handle_realtime_update(self, payload):
        api_logger.info("Starting to handle realtime update")

        try:
            hertz = float(payload["hz"])
            total_current = float(payload["c"])
            total_watts = float(payload["w"])
            epoch = int(payload["epoch"])  # Use epoch time in seconds directly

            voltage = payload.get("voltage", [])
            devices = payload.get("devices", [])
            channels = payload.get("channels", [])

            await self.influxdb_storage.persist_realtime_data(
                self.monitor_id,
                hertz,
                total_current,
                total_watts,
                epoch,
                voltage,
                devices,
                channels,
            )

            api_logger.info(
                "Data processed and sent to InfluxDB in 'handle_realtime_update' method"
            )

        except Exception as e:
            api_logger.error(f"Error in handle_realtime_update: {e}")

    async def handle_new_timeline_event(self, payload):
        items_added = payload.get("items_added", [])
        for item in items_added:
            device_id = item.get("device_id")
            if device_id:
                await self.process_timeline_item(item)
                queue_item = {
                    "device_id": device_id,
                }
                await self.api_call_queue.put(queue_item)
            else:
                api_logger.warning(f"Missing device_id in item: {item}")

    async def process_timeline_item(self, item):
        api_logger.info("Starting to process timeline item")
        api_logger.debug(f"Timeline item: {item}")

        try:
            time = item.get("time")
            event_type = item.get("type")
            icon = item.get("icon")
            body = item.get("body")
            device_id = item.get("device_id")
            device_state = item.get("device_state")
            user_device_type = item.get("user_device_type")
            device_transition_from_state = item.get("device_transition_from_state")

            api_logger.debug(f"Fetching device data for device_id: {device_id}")
            device_data = await self.lookup_device_data(device_id)
            api_logger.debug(f"Device data: {device_data}")

            if device_data and "device" in device_data:
                device_name = device_data["device"]["name"]
                api_logger.debug(f"Device name: {device_name}")
            else:
                device_name = "Unknown"
                api_logger.warning(
                    f"Device data for device_id {device_id} is missing 'device' key or is None"
                )

            await self.influxdb_storage.persist_timeline_data(
                device_id,
                device_name,
                time,
                event_type,
                icon,
                body,
                device_state,
                user_device_type,
                device_transition_from_state,
            )

            api_logger.info("Timeline item processed and sent to InfluxDB")

        except KeyError as e:
            api_logger.error(f"KeyError in process_timeline_item: {e}")
        except Exception as e:
            api_logger.error(f"Error in process_timeline_item: {e}")

    async def handle_hello_event(self, payload):
        online_status = payload.get("online", False)
        influxdb_timestamp = int(
            datetime.now(timezone.utc).timestamp()
        )  # Convert to epoch seconds
        await self.influxdb_storage.persist_hello_event(
            self.monitor_id, online_status, influxdb_timestamp
        )

    async def handle_data_change_event(self, payload):
        influxdb_timestamp = int(
            datetime.now(timezone.utc).timestamp()
        )  # Convert to epoch seconds
        user_version = payload.get("user_version")
        partner_checksum = payload.get("partner_checksum")
        monitor_overview_checksum = payload.get("monitor_overview_checksum")
        device_data_checksum = payload.get("device_data_checksum")
        settings_version = payload.get("settings_version")

        new_device_events = payload.get("pending_events", {}).get(
            "new_device_found", []
        )
        if not isinstance(new_device_events, list):
            new_device_events = [new_device_events]

        for event in new_device_events:
            device_id = event.get("device_id")
            guid = event.get("guid")
            json_timestamp = event.get("timestamp")
            epoch_timestamp = (
                self.convert_to_epoch(json_timestamp) if json_timestamp else None
            )

            await self.influxdb_storage.persist_data_change_event(
                self.monitor_id,
                device_id,
                user_version,
                guid,
                epoch_timestamp,
                influxdb_timestamp,
            )

            api_logger.info(
                f"Data change event data for device {device_id} sent to InfluxDB"
            )

    async def handle_device_states_event(self, payload):
        states = payload.get("states", [])
        for state in states:
            device_id = state.get("device_id")
            mode = state.get("mode")
            device_state = state.get("state")
            influxdb_timestamp = int(
                datetime.now(timezone.utc).timestamp()
            )  # Convert to epoch seconds

            queue_item = {
                "device_id": device_id,
            }
            await self.api_call_queue.put(queue_item)

            await self.influxdb_storage.persist_device_state(
                self.monitor_id, device_id, mode, device_state, influxdb_timestamp
            )

    async def lookup_device_data(self, device_id):
        async with self.semaphore:
            current_time = time.time()
            # Check if the device data is in cache and not expired
            if device_id in self.device_cache:
                cached_data, timestamp = self.device_cache[device_id]
                time_since_cached = current_time - timestamp
                time_until_expiry = self.cache_expiry_seconds - time_since_cached
                if time_until_expiry > 0:
                    api_logger.debug(
                        f"Cache hit for device_id: {device_id}, time until expiry: {time_until_expiry:.2f} seconds"
                    )
                    return cached_data
                else:
                    api_logger.debug(
                        f"Cache expired for device_id: {device_id}, fetching new data"
                    )

            url = SenseAPIEndpoints.DEVICE_DATA.format(
                monitor_id=self.monitor_id, device_id=device_id
            )
            api_logger.info(
                f"Sending request to fetch device data for device_id: {device_id}"
            )
            try:
                async with self.session.get(url, headers=self.headers) as response:
                    if response.status == 429:  # Handle rate limiting
                        retry_after = int(response.headers.get("Retry-After", 1))
                        api_logger.warning(
                            f"Rate limited. Retrying after {retry_after} seconds"
                        )
                        await asyncio.sleep(retry_after)
                        return await self.lookup_device_data(
                            device_id
                        )  # Retry after delay
                    response.raise_for_status()
                    device_data = await response.json()

                    # Cache the fetched data
                    self.device_cache[device_id] = (device_data, current_time)
                    api_logger.debug(
                        f"Fetched and cached data for device_id: {device_id}"
                    )
                    return device_data
            except aiohttp.ClientError as e:
                api_logger.error(f"Error fetching device data for {device_id}: {e}")
                return None
            finally:
                api_logger.info(
                    f"Completed request for device_id: {device_id}, waiting for {self.lookup_delay_seconds} seconds before next request"
                )
                await asyncio.sleep(self.lookup_delay_seconds)

    async def fetch_monitor_status(self):
        url = SenseAPIEndpoints.MONITOR_STATUS.format(monitor_id=self.monitor_id)
        while True:
            start_time = time.time()
            try:
                async with self.session.get(url, headers=self.headers) as response:
                    response.raise_for_status()
                    monitor_status = await response.json()
                    await self.influxdb_storage.persist_monitor_status(
                        self.monitor_id, monitor_status
                    )
                    api_logger.info("Successfully fetched and persisted monitor status")
            except aiohttp.ClientError as e:
                api_logger.error(f"Failed to fetch monitor status: {e}")

            elapsed_time = time.time() - start_time
            sleep_time = max(60 - elapsed_time, 0)
            await asyncio.sleep(sleep_time)

    async def poll_timeline(self):
        url = SenseAPIEndpoints.TIMELINE.format(user_id=self.user_id)
        while True:
            start_time = time.time()
            human_start_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            try:
                async with self.session.get(url, headers=self.headers) as response:
                    response.raise_for_status()
                    timeline_data = await response.json()
                    await self.process_timeline_data(timeline_data)
                    api_logger.info(
                        f"Successfully fetched and processed timeline data at {human_start_time}"
                    )
                    logger.debug(
                        f"Timeline response: {json.dumps(timeline_data, indent=2)}"
                    )
            except aiohttp.ClientError as e:
                api_logger.error(
                    f"Failed to fetch timeline data at {human_start_time}: {e}"
                )

            elapsed_time = time.time() - start_time
            sleep_time = max(60 - elapsed_time, 0)
            human_sleep_time = datetime.now() + timedelta(seconds=sleep_time)
            human_sleep_time = human_sleep_time.strftime("%Y-%m-%d %H:%M:%S")
            api_logger.info(
                f"Timeline polling completed at {human_start_time}. Next run at {human_sleep_time} after sleeping for {sleep_time:.2f} seconds"
            )
            await asyncio.sleep(sleep_time)

    async def process_timeline_data(self, data):
        for item in data.get("items", []):
            await self.process_timeline_item(item)

    async def fetch_devices(self):
        url = SenseAPIEndpoints.BASE_URL + f"/app/monitors/{self.monitor_id}/devices"
        while True:
            start_time = time.time()
            try:
                async with self.session.get(url, headers=self.headers) as response:
                    api_logger.debug(f"HTTP GET {url} status: {response.status}")
                    response.raise_for_status()
                    devices_response = await response.json()

                    # Output the JSON response for debugging
                    api_logger.debug(
                        f"Fetched devices response: {json.dumps(devices_response, indent=4)}"
                    )

                    if isinstance(devices_response, list):
                        for device in devices_response:
                            device_id = device.get("id")
                            if device_id:
                                api_logger.debug(
                                    f"Queueing device for processing: {device_id}"
                                )
                                await self.api_call_queue.put({"device_id": device_id})
                            else:
                                api_logger.warning(
                                    f"Device without ID found: {json.dumps(device, indent=4)}"
                                )
                        api_logger.info("Successfully fetched and queued devices")
                    else:
                        api_logger.warning(
                            f"Unexpected response format: {devices_response}"
                        )

            except aiohttp.ClientResponseError as e:
                api_logger.error(f"Client response error: {e.status} {e.message}")
            except aiohttp.ClientConnectionError as e:
                api_logger.error(f"Client connection error: {e}")
            except aiohttp.ClientError as e:
                api_logger.error(f"Client error: {e}")
            except Exception as e:
                api_logger.error(f"Unexpected error: {e}")

            elapsed_time = time.time() - start_time
            human_elapsed_time = datetime.now() + timedelta(seconds=elapsed_time)
            human_sleep_time = datetime.now() + timedelta(
                seconds=max(3600 - elapsed_time, 0)
            )
            api_logger.info(
                f"Fetch devices ran at: {human_elapsed_time}. "
                f"Next fetch will run at: {human_sleep_time}. "
                f"Sleeping for {max(3600 - elapsed_time, 0)} seconds."
            )
            await asyncio.sleep(max(3600 - elapsed_time, 0))

    def convert_to_epoch(self, timestamp_str):
        timestamp_format = "%Y-%m-%dT%H:%M:%S.%fZ"
        try:
            datetime_obj = datetime.strptime(timestamp_str, timestamp_format)
            return int(datetime_obj.timestamp())
        except ValueError as e:
            api_logger.error(f"Error converting timestamp: {e}")
            return None


def obfuscate_sensitive_data(data, visible_chars=4):
    if len(data) <= visible_chars:
        return "*" * len(data)
    return data[:visible_chars] + "*" * (len(data) - visible_chars)


async def main():
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logger.info(f"Welcome to Sense Collector! Current time: {current_time}")

    env_vars_defaults = {
        "SENSE_COLLECTOR_API_USERNAME": None,
        "SENSE_COLLECTOR_API_PASSWORD": None,
        "SENSE_COLLECTOR_INFLUXDB_URL": None,
        "SENSE_COLLECTOR_INFLUXDB_TOKEN": None,
        "SENSE_COLLECTOR_INFLUXDB_ORG": None,
        "SENSE_COLLECTOR_INFLUXDB_BUCKET": None,
        "SENSE_COLLECTOR_LOG_LEVEL_API": "INFO",
        "SENSE_COLLECTOR_LOG_LEVEL_STORAGE": "INFO",
        "SENSE_COLLECTOR_LOG_LEVEL_GENERAL": "INFO",
    }

    def obscure_value(value):
        if value and len(value) > 4:
            return value[:2] + "*" * (len(value) - 4) + value[-2:]
        return value

    missing_env_vars = []
    logger.info("Environment Variable Settings:")
    for var, default in env_vars_defaults.items():
        value = os.environ.get(var, default)
        is_default = value == default
        default_indicator = "(default)" if is_default else "(custom)"
        if "PASSWORD" in var or "TOKEN" in var:
            value_to_print = obscure_value(value)
        else:
            value_to_print = value
        logger.info(f"{var}: {value_to_print} {default_indicator}")
        if value is None:
            missing_env_vars.append(var)

    if missing_env_vars:
        logger.error(
            f"Missing required environment variables: {', '.join(missing_env_vars)}"
        )
        sys.exit(1)

    try:
        auth_response = await authenticate_with_sense(
            os.environ["SENSE_COLLECTOR_API_USERNAME"],
            os.environ["SENSE_COLLECTOR_API_PASSWORD"],
        )
        monitor_id = str(auth_response["monitors"][0]["id"])
        token = auth_response["access_token"]
        user_id = auth_response["user_id"]
    except Exception as e:
        logger.error(f"Authentication failed: {e}")
        sys.exit(1)

    influxdb_params = {
        "url": os.environ.get("SENSE_COLLECTOR_INFLUXDB_URL"),
        "token": os.environ.get("SENSE_COLLECTOR_INFLUXDB_TOKEN"),
        "org": os.environ.get("SENSE_COLLECTOR_INFLUXDB_ORG"),
        "bucket": os.environ.get("SENSE_COLLECTOR_INFLUXDB_BUCKET"),
    }

    influxdb_storage = InfluxDBStorage(influxdb_params)

    collector = SenseCollector(monitor_id, token, influxdb_storage, user_id)
    await collector.start_session()

    try:
        await asyncio.gather(
            collector.api_worker(),
            collector.receive_data(),
            collector.fetch_monitor_status(),
            collector.fetch_devices(),
        )
    finally:
        await collector.close_session()


if __name__ == "__main__":
    asyncio.run(main())
