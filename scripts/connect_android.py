"""Restore CampusHub development ports on a connected physical Android phone."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess


def find_adb():
    """Return an installed ADB path; never install or download anything."""
    on_path = shutil.which("adb")
    if on_path:
        return on_path
    sdk_adb = Path(os.environ.get("LOCALAPPDATA", "")) / "Android/Sdk/platform-tools/adb.exe"
    return str(sdk_adb) if sdk_adb.is_file() else None


def adb_command(adb, *arguments):
    """Run a bounded command with literal arguments, without invoking a shell."""
    return subprocess.run(
        [adb, *arguments], check=True, stdin=subprocess.DEVNULL,
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=12,
    ).stdout


def connected_phone_serials(output):
    """Keep wireless serials containing spaces; the final field is ADB state."""
    devices = []
    for line in output.splitlines():
        fields = line.rsplit(maxsplit=1)
        if len(fields) != 2:
            continue
        serial, state = fields
        if state == "device" and not serial.startswith("emulator-"):
            devices.append(serial)
    return devices


def resolve_single_phone(adb, devices):
    """Resolve duplicate transports only when every hardware serial agrees."""
    if len(devices) == 1:
        return devices[0]
    if not devices:
        return None
    identities = set()
    for serial in devices:
        try:
            identity = adb_command(adb, "-s", serial, "shell", "-n", "getprop", "ro.serialno").strip()
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            return None
        if (not identity or identity.lower() in ("unknown", "null")
                or len(identity) > 128 or any(char.isspace() for char in identity)):
            return None
        identities.add(identity)
    if len(identities) != 1:
        return None

    def preference(serial):
        if "_adb-tls-connect._tcp" in serial:
            return (2, serial)
        return (1 if ":" in serial else 0, serial)

    return min(devices, key=preference)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", help="Explicit connected ADB serial when multiple phones are attached")
    args = parser.parse_args()
    adb = find_adb()
    if not adb:
        print("ADB not found; skipping Android forwarding. Install/configure the Android SDK for phone development.")
        return 0
    try:
        devices = connected_phone_serials(adb_command(adb, "devices"))
        if args.device:
            if args.device not in devices:
                print("The requested phone is not connected/authorized. Check adb devices.")
                return 1
            serial = args.device
        else:
            serial = resolve_single_phone(adb, devices)
            if serial is None:
                print("No single verified physical phone; skipping forwarding. For multiple phones, run with --device <serial>.")
                return 0
        for port in (8000, 8001):
            adb_command(adb, "-s", serial, "reverse", f"tcp:{port}", f"tcp:{port}")
        print(f"CampusHub phone connection restored for {serial}: Django 8000 / chat 8001.")
        print("Keep Django running. In the app, tap Retry or pull to refresh.")
        return 0
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"Unable to restore Android forwarding: {error}. Reconnect/authorize the phone and retry.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
