import psutil
import sys
import time

if len(sys.argv) < 4:
    print("Usage: cpu_usage.py <pid> <duration_seconds> <interval_seconds>")
    sys.exit(1)

pid = int(sys.argv[1])
duration_secs = int(sys.argv[2])
interval = int(sys.argv[3])

process = psutil.Process(pid)
end_time = time.time() + duration_secs

try:
    while time.time() < end_time:
        usage = process.cpu_percent(interval=interval)
        ts = time.time_ns()
        print(f"{usage} {ts}")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)


