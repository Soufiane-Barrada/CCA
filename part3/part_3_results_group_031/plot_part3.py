import sys
import os
import json
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import pandas as pd
import numpy as np
from datetime import datetime
import re
from collections import defaultdict

# Map job names to consistent colors
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
    print("max_end_time", max_end_time)
    min_start = latency_data['ts_start'][0]

    print(min_start)
    print(".........start.............")
    print(latency_data['ts_start'])
    print("..........start - min............")
    a = latency_data['ts_start']- int(min_start_time)
    print(a)
    print("..........end............")
    print(latency_data['ts_end'][1])
    print("..........end - start............")
    print(latency_data['ts_end']-latency_data['ts_start'])

    # 1. Top plot: memcached p95 latency
    # plt.figure()
    # plt.bar( (latency_data['ts_start']-min_start) / 1000, height=latency_data['p95'], width= (latency_data['ts_end']- latency_data['ts_start']) / 1000)
    # plt.show()
    
    # Set up plots
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), gridspec_kw={'height_ratios': [1, 2]})
    fig.suptitle("Memcached p95 latency and batch jobs allocation (run 1)", fontsize=16)

    # --- Plot 1: Memcached p95 latency ---
    ax1.bar( (latency_data['ts_start']-min_start) / 1000 , latency_data['p95'], width= (latency_data['ts_end']- latency_data['ts_start']) / 1000, align='edge', color=job_colors['memcached'])
    ax1.set_ylabel("Memcached p95 latency [ms]")
    ax1.set_xlabel("time [s]")
    
    xticks = sorted(set( ((latency_data['ts_start']-min_start) / 1000 ).tolist() + ((latency_data['ts_end']- latency_data['ts_start']) / 1000).tolist()))
    ax1.set_xticks(xticks)
    ax1.set_xticklabels([f"{x:.0f}" for x in xticks], rotation=45)
    # ax1.set_xticks(xticks[::2]) 
    
    # 2. Bottom plot: job bars per core
    core_map = {}  # node-core string -> y-position
    y_offset = 0
    yticks, ytick_labels = [], []
    print(".........2nd PLOT.............")
    for job in job_data:
        job_name = job['name'].replace("parsec-", "")
        print(".........job name.............")
        print(job_name)
        color = job_colors.get(job_name, "gray")
        print(".........color.............")
        print(color)
        if job_name != 'memcached':
            start = (job['start'] - min_start_time) / 1000
            print(".........start.............")
            print(start)
            #if job_name != 'memcached':
            end = (job['end'] - min_start_time) / 1000
            print(".........start.............")
            print(end)
        # else:
        #     end = (max_end_time - min_start_time) /1000
        #     start = 0
        node = job['node']
        cores = job['cores']
        
        # Add vertical lines for job starts/ends
        ax1.axvline(start, color=color, linestyle='-', linewidth=0.7)
        ax1.axvline(end, color=color, linestyle='-', linewidth=0.7)
        #ax2.axvline(start, color=color, linestyle='-', linewidth=0.7)
        #ax2.axvline(end, color=color, linestyle='-', linewidth=0.7)
    
    
    # --- Plot 2: Gantt-style job-core allocation ---
    yticks = []
    yticklabels = []
    core_map = {}
    y_offset = 0

    for job in job_data:
        job_name = job['name'].replace("parsec-", "")
        color = job_colors.get(job_name, "black")
        if job_name != 'memcached':
            start = (job['start'] - min_start_time) / 1000
            duration = (job['end'] - job['start']) / 1000
        else:
            start = -10
            duration = 200
            

        for core in job['cores']:
            label = f"{job['node']}({core})"
            if label not in core_map:
                core_map[label] = y_offset
                yticks.append(y_offset)
                yticklabels.append(label)
                y_offset += 1
        
            y = core_map[label]
            ax2.barh(y, duration, left=start, height=0.8, color=color, edgecolor='black')

    
    # Align x-axis of both subplots
    ax2.set_xlim(ax1.get_xlim())
    ax2.set_yticks(yticks)
    ax2.set_yticklabels(yticklabels)

    # Legend
    patches = [mpatches.Patch(color=color, label=name) for name, color in job_colors.items()]
    ax2.legend(handles=patches, bbox_to_anchor=(1.01, 1), loc='upper left')

    plt.tight_layout()
    plt.savefig("run1_combined.png", dpi=300)
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
    print("------------------JOB DATA------------------------")
    print(job_data)
    
    #plot_results1(latency_data, job_data)

    plot_results(latency_data, job_data,"runTest")
