import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta
import re
import math


# Parse jobs.txt
jobs_data = []
with open('jobs.txt', 'r') as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) >= 2:
            timestamp = parts[0]
            action = parts[1]
            
            # Extract additional information based on action
            if action == 'start':
                job_name = parts[2]
                if len(parts) >= 4:
                    cores = parts[3].strip('[]')
                    cores_count = len(cores.split(','))
                    duration = parts[4] if len(parts) >= 5 else None
                else:
                    cores = None
                    cores_count = None
                    duration = None
                
                jobs_data.append({
                    'timestamp': timestamp,
                    'action': action,
                    'job': job_name,
                    'cores': cores,
                    'cores_count': cores_count,
                    'duration': duration
                })
            elif action == 'end':
                job_name = parts[2]
                jobs_data.append({
                    'timestamp': timestamp,
                    'action': action,
                    'job': job_name
                })
            elif action == 'update_cores':
                job_name = parts[2]
                cores = parts[3].strip('[]')
                cores_count = len(cores.split(','))
                jobs_data.append({
                    'timestamp': timestamp,
                    'action': action,
                    'job': job_name,
                    'cores': cores,
                    'cores_count': cores_count
                })

jobs_df = pd.DataFrame(jobs_data)
jobs_df['datetime'] = pd.to_datetime(jobs_df['timestamp'])

# Parse measure.txt
with open('measure.txt', 'r') as f:
    content = f.read()

# Extract timestamp information
timestamp_start = int(re.search(r'Timestamp start: (\d+)', content).group(1))
timestamp_end = int(re.search(r'Timestamp end: (\d+)', content).group(1))
total_intervals = int(re.search(r'Total number of intervals = (\d+)', content).group(1))

# Calculate time step
time_step = (timestamp_end - timestamp_start) / total_intervals

# Extract performance data
performance_data = []
data_section = content.split('#type')[1].strip()
lines = data_section.strip().split('\n')
header = lines[0].split()

for line in lines[1:]:
    if line.strip():
        values = line.split()
        if values[0] == 'read':
            data_point = {
                'p95': float(values[12]),
                'QPS': float(values[16]),
                'target': float(values[17])
            }
            performance_data.append(data_point)
            
perf_df = pd.DataFrame(performance_data)

# Create a time scale for the performance data
start_time = jobs_df['datetime'].min()
perf_df['time'] = [start_time + timedelta(milliseconds=i*time_step) for i in range(len(perf_df))]
perf_df['seconds'] = [(t - start_time).total_seconds() for t in perf_df['time']]

# Create job timeline data
job_timelines = {}
for job in jobs_df['job'].unique():
    if job in ['scheduler', 'memcached']:  # Skip memcached and scheduler
        continue
        
    job_starts = jobs_df[(jobs_df['job'] == job) & (jobs_df['action'] == 'start')]
    job_ends = jobs_df[(jobs_df['job'] == job) & (jobs_df['action'] == 'end')]
    
    if not job_starts.empty and not job_ends.empty:
        start_time = job_starts.iloc[0]['datetime']
        end_time = job_ends.iloc[0]['datetime']
        job_timelines[job] = {
            'start': (start_time - jobs_df['datetime'].min()).total_seconds(),
            'end': (end_time - jobs_df['datetime'].min()).total_seconds()
        }

# Track memcached core allocations over time
memcached_cores = []
for _, row in jobs_df[jobs_df['job'] == 'memcached'].iterrows():
    if row['cores_count'] is not None:  # Only add if cores count exists
        memcached_cores.append({
            'time': (row['datetime'] - jobs_df['datetime'].min()).total_seconds(),
            'cores': row['cores_count']
        })

# Get the maximum time from QPS data for proper display
max_qps_time = perf_df['seconds'].max()
display_max_time = 1200  # Set fixed display to 1200 seconds

# Make sure we have the last core count and extend it to the end of the plot
if memcached_cores:
    memcached_cores = sorted(memcached_cores, key=lambda x: x['time'])
    last_core_count = memcached_cores[-1]['cores']
    
    # Make sure the line extends to at least the maximum QPS time point
    # This fixes the issue where the orange line doesn't continue to the end
    if memcached_cores[-1]['time'] < max_qps_time:
        memcached_cores.append({
            'time': max_qps_time,
            'cores': last_core_count
        })
    
    # And also extend to display_max_time if needed
    if max_qps_time < display_max_time:
        memcached_cores.append({
            'time': display_max_time,
            'cores': last_core_count
        })

# Create the plot
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(12, 12), sharex=True, gridspec_kw={'height_ratios': [1, 1, 1]})

# Plot 1A: Memcached p95 latency and achieved QPS
ax1.set_title('1A')
ax1_qps = ax1.twinx()

# Plot p95 latency
line1 = ax1.plot(perf_df['seconds'], perf_df['p95']/1000, 'o-', color='orange', markersize=3, label='Memcached p95 latency')
ax1.set_ylabel('memcached p95 [ms]', color='orange')
ax1.set_ylim(0, 1.2)
ax1.tick_params(axis='y', labelcolor='orange')

# Plot achieved QPS
line2 = ax1_qps.plot(perf_df['seconds'], perf_df['QPS'], 'o-', color='steelblue', markersize=3, label='Memcached achieved QPS')
ax1_qps.set_ylabel('memcached QPS', color='steelblue')
ax1_qps.set_ylim(0, 230000)  # Increased to 230,000
ax1_qps.tick_params(axis='y', labelcolor='steelblue')

# Add a horizontal line at target QPS
ax1_qps.axhline(y=153400, color='r', linestyle='-', alpha=0.7)

# Combine the legends
lines = line1 + line2
labels = [l.get_label() for l in lines]
ax1.legend(lines, labels, loc='upper right')

# Plot 1B: Memcached used cores and achieved QPS
ax2.set_title('1B')
ax2_qps = ax2.twinx()

# Sort memcached cores by time to ensure proper display
memcached_cores = sorted(memcached_cores, key=lambda x: x['time'])

# Plot used cores
times = [d['time'] for d in memcached_cores]
times[-1] = perf_df['seconds'].iloc[-1]

core_counts = [d['cores'] for d in memcached_cores]
print("-------------times------------")
print(times)
print("-----------core----------------")
print(core_counts)


# Replace nan with last valid value
fixed_core_counts = []
last_valid = None

for val in core_counts:
    if math.isnan(val):
        fixed_core_counts.append(last_valid)
    else:
        fixed_core_counts.append(val)
        last_valid = val
print("-----------fixed core----------------")
print(fixed_core_counts)

line3 = ax2.step(times, fixed_core_counts, where='post', color='orange', label='Memcached used cores')
ax2.set_ylabel('memcached core number', color='orange')
ax2.set_ylim(0, 4)
ax2.set_yticks([0, 1, 2, 3, 4])  # Set integer ticks only
ax2.tick_params(axis='y', labelcolor='orange')
print("--------------------")
print(perf_df['seconds'].iloc[-1])
# Plot achieved QPS (same as in the first plot)
line4 = ax2_qps.plot(perf_df['seconds'], perf_df['QPS'], 'o-', color='steelblue', markersize=3, label='Memcached achieved QPS')
ax2_qps.set_ylabel('memcached QPS', color='steelblue')
ax2_qps.set_ylim(0, 230000)  # Increased to 230,000
ax2_qps.tick_params(axis='y', labelcolor='steelblue')

# Combine the legends
lines_b = line3 + line4
labels_b = [l.get_label() for l in lines_b]
ax2.legend(lines_b, labels_b, loc='upper right')

# Define the colors for each benchmark
colors = {
    'blackscholes': '#CCA000',
    'canneal': '#CCCCAA',
    'dedup': '#CCACCA',
    'ferret': '#AACCCA',
    'freqmine': '#0CCA00',
    'radix': '#00CCA0',
    'vips': '#CC0A00'
}

# Job timeline setup
job_names = list(job_timelines.keys())
job_names.reverse()  # Reverse to match the order in the screenshot

# Third plot - job timelines
ax3.set_ylim(-0.5, len(job_names) - 0.5)

# Set y-ticks at the positions of the jobs
ax3.set_yticks(range(len(job_names)))
ax3.set_yticklabels(job_names)

# Plot job bars and add duration text
for i, job in enumerate(job_names):
    timeline = job_timelines[job]
    duration = timeline['end'] - timeline['start']
    
    ax3.barh(i, duration, left=timeline['start'], 
             height=0.8, color=colors.get(job, 'gray'), alpha=0.7)
    
    # Add duration text inside the bar 
    if duration > 0:  
        ax3.text(timeline['start'] + duration/2, i, f"{int(duration)}s", 
                 va='center', ha='center', fontsize=8, color='black')

x_ticks = np.arange(0, display_max_time + 50, 50)

# Add vertical lines at job start and end times
for job in job_timelines:
    start_time = job_timelines[job]['start']
    end_time = job_timelines[job]['end']

 
    for axes in [ax1, ax2, ax3]:
        axes.axvline(x=start_time, color=colors.get(job, 'gray'), linestyle='--', alpha=0.5)
        axes.axvline(x=end_time, color=colors.get(job, 'gray'), linestyle='--', alpha=0.5)
        axes.set_xticks(x_ticks)
        axes.set_xticklabels([str(t) for t in x_ticks])
        axes.tick_params(axis='x', labelbottom=True) 
        axes.xaxis.set_visible(True)  # ensure x-axis is visible
        

ax3.set_xlabel('time [s]')

# Make sure all ticks are visible on all plots
for ax in [ax1, ax2, ax3]:
    ax.grid(True, linestyle='--', alpha=0.3)
    ax.set_xlim(-20, display_max_time)


# Final layout adjustments
plt.tight_layout()
plt.savefig('job_performance_analysis.png', dpi=300)
plt.show()