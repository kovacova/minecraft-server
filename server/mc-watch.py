#!/usr/bin/env python3
"""Ask the server how many players are online (over RCON); after IDLE_MINUTES
with nobody on, stop Minecraft cleanly and power the machine off.

Runs every minute from mc-watch.timer. The empty-since time is kept in /run,
which is cleared on boot, so every start gets a fresh countdown."""
import os
import re
import socket
import struct
import subprocess
import time

STATE = "/run/mc-watch-empty-since"
IDLE = int(os.environ.get("IDLE_MINUTES", "15")) * 60


def rcon(command: str) -> str:
    props = dict(
        line.strip().split("=", 1)
        for line in open("/srv/minecraft/server.properties")
        if "=" in line and not line.startswith("#")
    )
    with socket.create_connection(("127.0.0.1", int(props["rcon.port"])), timeout=5) as s:
        def send(req_id: int, kind: int, body: str) -> None:
            data = struct.pack("<ii", req_id, kind) + body.encode() + b"\x00\x00"
            s.sendall(struct.pack("<i", len(data)) + data)

        def recv() -> tuple[int, str]:
            size = struct.unpack("<i", s.recv(4))[0]
            data = b""
            while len(data) < size:
                data += s.recv(size - len(data))
            req_id, _ = struct.unpack("<ii", data[:8])
            return req_id, data[8:-2].decode(errors="replace")

        send(1, 3, props["rcon.password"])  # 3 = login
        if recv()[0] == -1:
            raise RuntimeError("RCON password rejected")
        send(2, 2, command)  # 2 = command
        return recv()[1]


def players_online() -> int:
    # "There are 0 of a max of 20 players online: "
    match = re.search(r"There are (\d+)", rcon("list"))
    return int(match.group(1)) if match else 0


def main() -> None:
    try:
        online = players_online()
    except (OSError, RuntimeError):
        # Still starting, or crashed. systemd restarts a crash; if it never comes
        # back, the countdown below still ends in a stopped (cheap) machine.
        online = 0

    if online:
        if os.path.exists(STATE):
            os.remove(STATE)
        return

    now = time.time()
    if not os.path.exists(STATE):
        with open(STATE, "w") as f:
            f.write(str(now))
        return

    empty_since = float(open(STATE).read())
    if now - empty_since >= IDLE:
        print(f"empty for {int((now - empty_since) / 60)} min, shutting down")
        subprocess.run(["systemctl", "stop", "minecraft.service"], check=False)  # saves + backs up
        subprocess.run(["shutdown", "-h", "now"], check=False)


if __name__ == "__main__":
    main()
