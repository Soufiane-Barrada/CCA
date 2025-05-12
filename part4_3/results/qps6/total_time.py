from datetime import datetime

with open("jobs_3.txt") as f:
    lines = f.readlines()

start_times = [datetime.fromisoformat(line.split()[0]) for line in lines if "start " in line and "scheduler" not in line]
end_times = [datetime.fromisoformat(line.split()[0]) for line in lines if "end " in line and "scheduler" not in line]

makespan = max(end_times) - min(start_times)
print("Makespan (seconds):", makespan.total_seconds())
