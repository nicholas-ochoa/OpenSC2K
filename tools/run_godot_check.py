#!/usr/bin/env python3
"""Run one Godot check; script errors must fail even if Godot stays open."""
import os
import re
import subprocess
import sys
import tempfile
import time


def main():
    timeout = float(os.environ.get("GODOT_TEST_TIMEOUT_SECONDS", "900"))
    with tempfile.NamedTemporaryFile(mode="w+b") as output, open(output.name, "rb") as reader:
        process = subprocess.Popen(sys.argv[1:], stdout=output, stderr=subprocess.STDOUT)
        start = time.monotonic()
        offset = 0
        failed = False
        tail = b""
        try:
            while True:
                reader.seek(offset)
                data = reader.read()
                offset += len(data)
                if data:
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()
                    if re.search(rb"SCRIPT ERROR:|^ERROR:", tail + data, re.MULTILINE):
                        failed = True
                    tail = (tail + data)[-512:]
                if failed or time.monotonic() - start > timeout:
                    if not failed:
                        print(f"ERROR: Godot check exceeded {timeout:g} seconds", flush=True)
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    return 1
                status = process.poll()
                if status is not None:
                    # Drain output written between the read and exit.
                    reader.seek(offset)
                    data = reader.read()
                    sys.stdout.buffer.write(data)
                    if re.search(rb"SCRIPT ERROR:|^ERROR:", tail + data, re.MULTILINE):
                        return 1
                    return status
                time.sleep(0.1)
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)


if __name__ == "__main__":
    sys.exit(main())
