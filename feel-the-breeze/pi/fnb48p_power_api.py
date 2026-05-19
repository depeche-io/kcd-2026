#!/usr/bin/env python3
import json
import os
import threading
import time
import traceback
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlsplit

from prometheus_client import Gauge, generate_latest

try:
    import tinytuya
except ImportError:
    tinytuya = None

try:
    import usb.core
    import usb.util
except ImportError:
    usb = None


SOLAR_POWER = Gauge("solar_generation_watts", "Measured solar power production in Watts")
FAN_CONTROLLER_ENABLED = Gauge(
    "fan_controller_enabled",
    "Whether fan controller deployment should be enabled (1) or scaled down (0)",
)
METER_CONNECTED = Gauge("solar_meter_connected", "Whether FNB48P meter is currently reachable")
SOLAR_MODE = Gauge("solar_mode", "1=sun, 0=cloud/blackout")

SUN_THRESHOLD_W = float(os.getenv("SUN_THRESHOLD_W", "0.5"))
CLOUD_FALLBACK_W = float(os.getenv("CLOUD_FALLBACK_W", "0.2"))
METER_STALE_SECONDS = float(os.getenv("METER_STALE_SECONDS", "10"))

SUPPORTED_DEVICES = [
    (0x2E3C, 0x0049),
    (0x2E3C, 0x5558),
    (0x0483, 0x003A),
    (0x0483, 0x003B),
]


class TuyaSwitch:
    def __init__(self, prefix: str, default_kind: str = "device"):
        self.name = prefix.lower()
        self.kind = os.getenv(f"TUYA_{prefix}_DEVICE_KIND", default_kind).lower()
        self.device_id = os.getenv(f"TUYA_{prefix}_DEVICE_ID", "").strip()
        self.ip = os.getenv(f"TUYA_{prefix}_IP", "").strip()
        self.local_key = os.getenv(f"TUYA_{prefix}_LOCAL_KEY", "").strip()
        self.version = os.getenv(f"TUYA_{prefix}_VERSION", "3.3").strip()
        self.switch_dp = int(os.getenv(f"TUYA_{prefix}_SWITCH_DP", "1"))
        self.max_retries = int(os.getenv("TUYA_MAX_RETRIES", "2"))
        self.enabled = bool(self.device_id and self.ip and self.local_key)
        self.device = None

        if self.enabled and tinytuya is not None:
            self.device = self._new_device()
            print(
                f"[TUYA] {self.name}: ready ({self.ip}, kind={self.kind}, dp={self.switch_dp}, ver={self.version})",
                flush=True,
            )
        elif tinytuya is None:
            print(f"[TUYA] {self.name}: tinytuya not installed", flush=True)
        else:
            print(f"[TUYA] {self.name}: missing config, endpoint calls will fail", flush=True)

    def _new_device(self):
        cls = tinytuya.Device
        if self.kind == "outlet":
            cls = tinytuya.OutletDevice
        elif self.kind == "bulb":
            cls = tinytuya.BulbDevice

        device = cls(self.device_id, self.ip, self.local_key)
        try:
            device.set_version(float(self.version))
        except Exception:
            pass
        return device

    def set_power(self, on: bool):
        if tinytuya is None:
            return False, "tinytuya not installed"
        if not self.enabled:
            return False, "device is not configured"

        last_error = None
        for _ in range(1, self.max_retries + 1):
            try:
                if self.device is None:
                    self.device = self._new_device()

                result = self.device.set_status(bool(on), switch=self.switch_dp)
                if isinstance(result, dict) and result.get("Error"):
                    last_error = f"tuya-error: {result.get('Error')}"
                    self.device = None
                    continue
                return True, "ok"
            except Exception as exc:
                last_error = f"{type(exc).__name__}: {exc}"
                self.device = None

        return False, last_error or "unknown error"


class SharedState:
    def __init__(self):
        self.lock = threading.Lock()
        self.manual_mode = None  # None|blackout
        self.measured_power_w = None
        self.last_measurement_ts = 0.0
        self.meter_connected = False
        self.effective_power_w = CLOUD_FALLBACK_W
        self.mode = "cloud"
        self.fan_controller_enabled = True

    def update_meter(self, power_w: float):
        with self.lock:
            self.measured_power_w = power_w
            self.last_measurement_ts = time.time()
            self.meter_connected = True
            self._recompute_locked()

    def meter_error(self):
        with self.lock:
            self.meter_connected = False
            self._recompute_locked()

    def set_blackout(self):
        with self.lock:
            self.manual_mode = "blackout"
            self._recompute_locked()

    def recover(self):
        with self.lock:
            self.manual_mode = None
            self._recompute_locked()

    def snapshot(self):
        with self.lock:
            age = time.time() - self.last_measurement_ts if self.last_measurement_ts else None
            return {
                "manual_mode": self.manual_mode,
                "mode": self.mode,
                "sun_threshold_w": SUN_THRESHOLD_W,
                "cloud_fallback_w": CLOUD_FALLBACK_W,
                "meter_connected": self.meter_connected,
                "measurement_age_s": round(age, 2) if age is not None else None,
                "measured_power_w": self.measured_power_w,
                "solar_generation_watts": self.effective_power_w,
                "fan_controller_enabled": self.fan_controller_enabled,
            }

    def _recompute_locked(self):
        now = time.time()
        stale = (
            self.last_measurement_ts == 0
            or (now - self.last_measurement_ts) > METER_STALE_SECONDS
            or self.measured_power_w is None
        )

        if self.manual_mode == "blackout":
            self.mode = "blackout"
            self.effective_power_w = CLOUD_FALLBACK_W
            self.fan_controller_enabled = False
        elif stale:
            self.mode = "cloud"
            self.effective_power_w = CLOUD_FALLBACK_W
            self.fan_controller_enabled = True
        else:
            if self.measured_power_w > SUN_THRESHOLD_W:
                self.mode = "sun"
            else:
                self.mode = "cloud"
            self.effective_power_w = float(self.measured_power_w)
            self.fan_controller_enabled = True

        SOLAR_POWER.set(self.effective_power_w)
        FAN_CONTROLLER_ENABLED.set(1 if self.fan_controller_enabled else 0)
        METER_CONNECTED.set(1 if self.meter_connected else 0)
        SOLAR_MODE.set(1 if self.mode == "sun" else 0)


def find_device():
    for vid, pid in SUPPORTED_DEVICES:
        dev = usb.core.find(idVendor=vid, idProduct=pid)
        if dev is not None:
            print(f"[FNB] Found device VID=0x{vid:04x} PID=0x{pid:04x}", flush=True)
            return dev
    return None


def claim_device(dev):
    try:
        dev.reset()
    except Exception:
        pass

    try:
        for cfg in dev:
            for intf in cfg:
                num = intf.bInterfaceNumber
                if dev.is_kernel_driver_active(num):
                    try:
                        dev.detach_kernel_driver(num)
                    except Exception as exc:
                        print(f"[FNB] Could not detach kernel driver from {num}: {exc}", flush=True)
    except (NotImplementedError, AttributeError):
        pass

    try:
        dev.set_configuration()
    except Exception:
        pass

    cfg = dev.get_active_configuration()
    intf = cfg[(0, 0)]

    ep_in = usb.util.find_descriptor(
        intf,
        custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_IN,
    )
    ep_out = usb.util.find_descriptor(
        intf,
        custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_OUT,
    )

    if ep_in is None or ep_out is None:
        raise RuntimeError("Could not find USB IN/OUT endpoints")

    return ep_in, ep_out


def write_command(ep_out, command: bytes):
    if len(command) > 64:
        raise ValueError("Command too long")
    packet = command + bytes(64 - len(command))
    ep_out.write(packet)


def init_meter(ep_out):
    write_command(ep_out, b"\xaa\x81" + b"\x00" * 61 + b"\x8e")
    write_command(ep_out, b"\xaa\x82" + b"\x00" * 61 + b"\x96")
    write_command(ep_out, b"\xaa\x82" + b"\x00" * 61 + b"\x96")


def request_continue(ep_out):
    write_command(ep_out, b"\xaa\x83" + b"\x00" * 61 + b"\x9e")


def u32_le(data, offset):
    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)


def decode_latest_power(data):
    data = bytes(data)
    if len(data) < 64 or data[1] != 0x04:
        return None

    latest = None
    for i in range(4):
        offset = 2 + 15 * i
        if offset + 14 >= len(data):
            break
        voltage_v = u32_le(data, offset + 0) / 100000.0
        current_a = u32_le(data, offset + 4) / 100000.0
        if 0 <= voltage_v <= 30 and 0 <= current_a <= 10:
            latest = voltage_v * current_a
    return latest


def meter_loop(state: SharedState):
    if usb is None:
        print("[FNB] pyusb not installed, forcing cloud fallback", flush=True)
        while True:
            state.meter_error()
            time.sleep(5)

    while True:
        dev = find_device()
        if dev is None:
            state.meter_error()
            time.sleep(3)
            continue

        try:
            ep_in, ep_out = claim_device(dev)
            init_meter(ep_out)
            print("[FNB] Meter connected", flush=True)

            last_keepalive = time.time()
            while True:
                data = ep_in.read(size_or_buffer=64, timeout=5000)
                power_w = decode_latest_power(data)

                now = time.time()
                if now - last_keepalive >= 1.0:
                    request_continue(ep_out)
                    last_keepalive = now

                if power_w is not None:
                    state.update_meter(power_w)
        except Exception as exc:
            print(f"[FNB] Read error: {type(exc).__name__}: {exc}", flush=True)
            state.meter_error()
            time.sleep(2)


STATE = SharedState()
FAN = TuyaSwitch("FAN", default_kind="outlet")
LED = TuyaSwitch("LED", default_kind="bulb")


class WebServer(BaseHTTPRequestHandler):
    def do_GET(self):
        self._handle()

    def do_POST(self):
        self._handle()

    def _json_response(self, status: int, payload: dict):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _handle(self):
        path = urlsplit(self.path).path
        if path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return

        print(f"[HTTP] {self.command} {path}", flush=True)

        try:
            if path == "/healthz":
                return self._json_response(200, {"status": "ok"})

            if path == "/metrics":
                body = generate_latest()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; version=0.0.4")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return

            if path in ("/sun", "/cloud"):
                snap = STATE.snapshot()
                return self._json_response(
                    200,
                    {
                        "message": "sun/cloud are now derived automatically from real power meter",
                        **snap,
                    },
                )

            if path in ("/blackout", "/off"):
                STATE.set_blackout()
                fan_ok, fan_msg = FAN.set_power(False)
                led_ok, led_msg = LED.set_power(False)
                snap = STATE.snapshot()
                status = 200 if fan_ok and led_ok else 500
                return self._json_response(
                    status,
                    {
                        "action": "blackout",
                        **snap,
                        "fan": {"ok": fan_ok, "state": "off", "message": fan_msg},
                        "led": {"ok": led_ok, "state": "off", "message": led_msg},
                    },
                )

            if path == "/recover":
                STATE.recover()
                fan_ok, fan_msg = FAN.set_power(True)
                snap = STATE.snapshot()
                status = 200 if fan_ok else 500
                return self._json_response(
                    status,
                    {
                        "action": "recover",
                        **snap,
                        "fan": {"ok": fan_ok, "state": "on", "message": fan_msg},
                        "led": {"state": "managed-by-keda"},
                    },
                )

            if path == "/vetrak/on":
                ok, msg = FAN.set_power(True)
                return self._json_response(200 if ok else 500, {"device": "fan", "state": "on", "ok": ok, "message": msg})

            if path == "/vetrak/off":
                ok, msg = FAN.set_power(False)
                return self._json_response(200 if ok else 500, {"device": "fan", "state": "off", "ok": ok, "message": msg})

            if path in ("/lampa/on", "/led/on"):
                ok, msg = LED.set_power(True)
                return self._json_response(200 if ok else 500, {"device": "led", "state": "on", "ok": ok, "message": msg})

            if path in ("/lampa/off", "/led/off"):
                ok, msg = LED.set_power(False)
                return self._json_response(200 if ok else 500, {"device": "led", "state": "off", "ok": ok, "message": msg})

            if path == "/state":
                return self._json_response(200, STATE.snapshot())

            return self._json_response(404, {"error": "not found", "path": path})

        except Exception:
            print("[CRITICAL] Unhandled exception:", flush=True)
            traceback.print_exc()
            return self._json_response(500, {"error": "internal server error"})


if __name__ == "__main__":
    bind = os.getenv("BIND_ADDR", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))

    print("[START] KCD Tuya + FNB48P API", flush=True)
    print(f"[START] Listening on {bind}:{port}", flush=True)
    print(
        "[START] Endpoints: /metrics /healthz /state /blackout /off /recover /vetrak/on /vetrak/off /led/on /led/off",
        flush=True,
    )
    print(
        f"[START] Auto mode thresholds: sun>{SUN_THRESHOLD_W}W, cloud<={SUN_THRESHOLD_W}W; fallback cloud on read timeout>{METER_STALE_SECONDS}s",
        flush=True,
    )

    meter_thread = threading.Thread(target=meter_loop, args=(STATE,), daemon=True)
    meter_thread.start()

    server = HTTPServer((bind, port), WebServer)
    server.serve_forever()
