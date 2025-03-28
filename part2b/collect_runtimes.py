import os
import re
import pandas as pd

log_dir = 'part2b_logs'
data = []

for log_file in os.listdir(log_dir):
    if log_file.endswith('.log'):
        with open(os.path.join(log_dir, log_file)) as f:
            for line in f:
                if line.startswith('real'):
                    match = re.match(r'real\s+(\d+)m(\d+\.\d+)s', line)
                    if match:
                        minutes = int(match.group(1))
                        seconds = float(match.group(2))
                        total_seconds = minutes * 60 + seconds

                        workload, thread_part = log_file.replace('.log', '').split('_')
                        threads = int(thread_part.replace('threads', ''))

                        data.append([workload, threads, total_seconds])
                    break  # stop after first "real" line

df = pd.DataFrame(data, columns=['Workload', 'Threads', 'Real_Time'])
df.sort_values(by=['Workload', 'Threads'], inplace=True)
df.to_csv('speedup_data.csv', index=False)

print("✅ Data collected and saved to speedup_data.csv")
print(df)

