import sys
import os
import json
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import pandas as pd
import numpy as np
from datetime import datetime
import re
from collections import defaultdict, OrderedDict


# Define a color mapping for different job names to ensure consistent visualization
job_colors = {
    'blackscholes': '#CCA000',
    'canneal': '#CCCCAA',
    'dedup': '#CCACCA',
    'ferret': '#AACCCA',
    'freqmine': '#0CCA00',
    'radix': '#00CCA0',
    'vips': '#CC0A00',
    'memcached': '#1f77b4'
}

def extract_core_count(node_name):
    """Extract the number of cores from a node name using regex"""
    match = re.search(r'(\d+)core', node_name)
    return int(match.group(1)) if match else 1

def parse_cores(core_str):
    """Parses a core string like '0-1' or '2' into a list of integers."""
    if '-' in core_str:
        start, end = map(int, core_str.split('-'))
        return list(range(start, end + 1))
    return [int(core_str)]


def read_mcperf_file(file_path):
    """Reads an mcperf output file and extracts QPS and p95."""
    df = pd.read_csv(file_path, delim_whitespace=True, comment="W")
    if "ts_start" not in df.columns or "ts_end" not in df.columns or "p95" not in df.columns:
        print(f"ERROR: QPS or p95 column not found in {file_path}")
        return pd.DataFrame()
    
    df = df[["p95", "ts_start", "ts_end"]].copy()
    return df.dropna()

def parse_results_json(path):
    with open(path, 'r') as f:
        data = json.load(f)

    jobs = []
    
    for item in data['items']:
        container = item['status']['containerStatuses'][0]
        name = container['name'] 
        print("Job: ", str(name))
        if str(name) != 'memcached':
            start_str = container['state']['terminated']['startedAt']
            end_str = container['state']['terminated']['finishedAt']
            node = item['spec']['nodeSelector']['cca-project-nodetype']
            tasket_core = item['spec']['containers'][0]['args'][1]
            
            match = re.search(r'taskset\s+-c\s+([^\s]+)', tasket_core)
            
            if match:
                cores = match.group(1)
                cores = parse_cores(cores)
                # print("-----------Cores INSIDE the loop----------",match.group(1), "---", cores)
            else:
            # No taskset -c at all
                cores = extract_core_count(node)
                cores = list(range(cores))
                # print("-------------Cores OUTSIDE loop-----------", cores)
            try:
                start_time = datetime.fromisoformat(start_str).timestamp()*1000
                print("---START TIME---", start_time)
                end_time = datetime.fromisoformat(end_str).timestamp()*1000
                print("---END TIME---", end_time)

                jobs.append({
                    "name": name,
                    "start": start_time,
                    "end": end_time,
                    "node": node,
                    "cores": cores
                })
            except Exception as e:
                continue
        else:
            #add memcached to jobs
            start_str = container['state']['running']['startedAt'] 
            tasket_core = item['spec']['containers'][0]['args'][1]
            node = item['spec']['nodeSelector']['cca-project-nodetype']
            match = re.search(r'taskset\s+-c\s+([^\s]+)', tasket_core)
            start_time = datetime.fromisoformat(start_str).timestamp()*1000
            if match:
                cores = match.group(1)
                cores = parse_cores(cores)
                # print("-----------Cores INSIDE the loop----------",match.group(1), "---", cores)
            else:
            # No taskset -c at all
                cores = extract_core_count(node)
                cores = list(range(cores))
            try:
                print("memcached job node", node, "memcached job cores", cores)
                jobs.append({
                    "name": name,
                    "node": node,
                    "cores": cores
                })
                
            except Exception as e:
                continue
    return jobs


def plot_results(latency_data, job_data, run_label="run"):
    min_start_time = min(job['start'] for job in job_data if job['name'] != 'memcached')
    max_end_time = max(job['start'] for job in job_data if job['name'] != 'memcached')
    min_start = latency_data['ts_start'][0]
    #min_start1 =  min(latency['ts_start'] for latency in latency_data )
    #print(("----------------MIN START 1", min_start1))
    print(("----------------MIN START ", min_start))
    print(("----------------LATENCY DATA ", latency_data['ts_start']))
    max_ts_start = latency_data['ts_start'].max()
    print("Max ts_start:", max_ts_start)

    # Set up plots
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), gridspec_kw={'height_ratios': [1, 2]})
    fig.suptitle("Memcached p95 latency and batch jobs allocation (run 1)", fontsize=16)

    # --- Plot 1: Memcached p95 latency ---
    ax1.bar(
        (latency_data['ts_start'] - min_start) / 1000,
        latency_data['p95'] / 1000,
        width=(latency_data['ts_end'] - latency_data['ts_start']) / 1000,
        align='edge',
        color=job_colors['memcached']
    )
    ax1.set_ylabel("Memcached p95 latency [ms]")
    ax1.set_xlabel("time [s]")
    xticks = sorted(set(
        ((latency_data['ts_start'] - min_start) / 1000).tolist() +
        ((latency_data['ts_end'] - min_start) / 1000).tolist()
    ))
    
    ax1.set_xlim(-10, 300)
    ax1.set_ylim(0, 1)
    #ax1.set_xticks(xticks)
    #ax1.set_xticklabels([f"{x:.0f}" for x in xticks], rotation=90)
    # for label in ax1.get_xticklabels():
    #     label.set_color('gray')

    # --- Plot 2: Gantt-style job-core allocation ---

    # Step 1: Build and sort core labels
    all_core_entries = set()
    for job in job_data:
        for core in job['cores']:
            label = f"{job['node']}({core})"
            all_core_entries.add((job['node'], core, label))
    sorted_core_entries = sorted(all_core_entries, key=lambda x: (x[0], x[1]))

    core_map = OrderedDict()
    yticks = []
    yticklabels = []
    for y_offset, (_, _, label) in enumerate(sorted_core_entries):
        core_map[label] = y_offset
        yticks.append(y_offset)
        yticklabels.append(label)

    # Step 2: Plot job bars
    for job in job_data:
        job_name = job['name'].replace("parsec-", "")
        color = job_colors.get(job_name, "black")
        if job_name != 'memcached':
            start = (job['start'] - min_start_time) / 1000
            duration = (job['end'] - job['start']) / 1000
            #add vertical lines
            ax1.axvline(start, color=color, linestyle='-', linewidth=1)
            ax1.axvline(start + duration, color=color, linestyle='-', linewidth=1)
            #ax2.axvline(start, color=color, linestyle='-', linewidth=0.9)
            #ax2.axvline(start + duration, color=color, linestyle='-', linewidth=0.9)
        else:
            start = 0
            duration = ((max_ts_start - min_start) / 1000)

        for core in job['cores']:
            label = f"{job['node']}({core})"
            y = core_map[label]
            ax2.barh(y, duration, left=start, height=0.8, color=color, edgecolor='black')

    ax2.set_xlim(ax1.get_xlim())
    ax2.set_yticks(yticks)
    ax2.set_yticklabels(yticklabels)

    # Legend
    patches = [mpatches.Patch(color=color, label=name) for name, color in job_colors.items()]
    ax2.legend(handles=patches, bbox_to_anchor=(1.01, 1), loc='upper left')
    
    # Add grid lines
    ax1.grid(True, which='both', axis='both', linestyle='--', linewidth=0.5)
    ax2.grid(True, which='both', axis='both', linestyle='--', linewidth=0.5)

    plt.tight_layout()
    plt.savefig("runS8_combined.png", dpi=300)
    plt.show()
 

if __name__ == "__main__":
    files_names = sys.argv[1:]
    if not files_names: 
        print("Usage: python plot_part3.py measure.txt results.json") 
        sys.exit(1)

    latency_data = read_mcperf_file(files_names[0])
    job_data = parse_results_json(files_names[1])
    print("------------------LATENCY DATA------------------------")
    print(latency_data)
    print("---------------------JOB DATA------------------------")
    print(job_data)
    
    #plot_results1(latency_data, job_data)

    plot_results(latency_data, job_data,"runTest")
