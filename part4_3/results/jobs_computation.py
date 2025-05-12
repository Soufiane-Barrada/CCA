import pandas as pd
import re
from collections import defaultdict

files = ["times_1.txt", "times_2.txt", "times_3.txt"]
job_durations = defaultdict(list)

# Parse each times_X.txt file
for file in files:
    with open(file) as f:
        for line in f:
            match = re.match(r"(\w+)\s+([\d.]+)", line)
            if match:
                job, duration = match.groups()
                job_durations[job].append(float(duration))

# Compute mean and std dev
summary = []
for job, durations in job_durations.items():
    mean = round(pd.Series(durations).mean(), 2)
    std = round(pd.Series(durations).std(), 2)
    summary.append((job, mean, std))

# Sort and display
summary.sort()
print("Job        Mean [s]   Std Dev [s]")
print("-" * 30)
with open("job_duration_summary.txt", "w") as out:
    out.write("Job        Mean [s]   Std Dev [s]\n")
    out.write("-" * 30 + "\n")
    for job, mean, std in summary:
        line = f"{job:<10} {mean:>8.2f}   {std:>10.2f}"
        print(line)
        out.write(line + "\n")

print("\nSaved summary to job_duration_summary.txt")

