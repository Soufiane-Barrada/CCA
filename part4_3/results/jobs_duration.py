from datetime import datetime
from collections import defaultdict

input_file = "jobs_3.txt"
output_file = "times_3.txt"

# Load the job log
with open(input_file) as f:
    lines = f.readlines()

jobs = defaultdict(dict)

for line in lines:
    parts = line.strip().split()
    if len(parts) >= 3:
        timestamp_str, action, job = parts[0], parts[1], parts[2]
        if job not in ["memcached", "scheduler"]:
            timestamp = datetime.fromisoformat(timestamp_str)
            jobs[job][action] = timestamp

# Compute durations
durations = {}
for job, times in jobs.items():
    if "start" in times and "end" in times:
        duration = (times["end"] - times["start"]).total_seconds()
        durations[job] = duration

# Write to output file
with open(output_file, "w") as out:
    out.write("Job Durations (in seconds):\n")
    for job, dur in durations.items():
        line = f"{job:15s} {dur:.2f} s\n"
        print(line.strip())  # also print to console
        out.write(line)

print(f"\nResults saved to {output_file}")

