import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import re
import sys

# Function to parse data files and extract relevant information
def parse_memcached_data(data_content):
    lines = data_content.strip().split('\n')
    target_qps_values = []
    achieved_qps_values = []
    p95_latency_values = []
    
    for line in lines[1:]:  # Skip header line
        if line.startswith('read'):
            parts = re.split(r'\s+', line.strip())
            if len(parts) >= 17:
                p95_latency = float(parts[12]) / 1000.0  # Convert to ms
                achieved_qps = float(parts[16])
                target_qps = float(parts[17])
                
                # Only include data points where there's a QPS target
                if target_qps > 0:
                    target_qps_values.append(target_qps)
                    achieved_qps_values.append(achieved_qps)
                    p95_latency_values.append(p95_latency)
    
    return np.array(target_qps_values), np.array(achieved_qps_values), np.array(p95_latency_values)

# Function to compute weighted average using QPS as weight
def compute_weighted_avg(runs_data):
    # Each run contains (target_qps, achieved_qps, p95_latency)
    all_target_qps = sorted(set().union(*[set(run[0]) for run in runs_data]))
    weighted_qps = []
    weighted_p95 = []
    standard_deviation_p95 = []
    
    for target in all_target_qps:
        qps_values = []
        latency_values = []
        
        for run_data in runs_data:
            target_qps, achieved_qps, p95_latency = run_data
            idx = np.where(target_qps == target)[0]
            if len(idx) > 0:
                qps_values.append(achieved_qps[idx[0]])
                latency_values.append(p95_latency[idx[0]])
        
        if qps_values and latency_values:
            # Calculate weighted average of p95 using QPS as weight
            total_qps = sum(qps_values)
            weighted_p95_avg = sum(q * p for q, p in zip(qps_values, latency_values)) / total_qps
            avg_qps = total_qps / len(qps_values)  # Average QPS across runs
            print("LENGTH qps_values", len(qps_values))
            # Calculate std of p95 values
            std_p95 = np.std(latency_values, ddof=1) if len(latency_values) > 1 else 0
            
            weighted_qps.append(avg_qps)
            weighted_p95.append(weighted_p95_avg)
            standard_deviation_p95.append(std_p95)
    
    return np.array(weighted_qps), np.array(weighted_p95), np.array(standard_deviation_p95)

# Function to plot data with error bars
def plot_memcached_performance(config_data, labels, colors, markers):
    plt.figure(figsize=(14, 9))
    plt.grid(True, alpha=0.3)  # Less prominent grid
    
    # Add horizontal line at 1ms
    plt.axhline(y=0.8, color='r', linestyle='-', alpha=0.7, label='0.8ms latency threshold')
    
    for i, (data, label, color, marker) in enumerate(zip(config_data, labels, colors, markers)):
        weighted_qps, weighted_p95, variance_p95 = data
    
        
        plt.errorbar(weighted_qps/1000.0 , weighted_p95, yerr=variance_p95, 
                     label=label, color=color, marker=marker, linestyle='-',
                     capsize=3, markersize=8, linewidth=2,elinewidth=1,markeredgewidth=0.2)
        
    
    plt.title('Weighted Average Memcached Performance over 3 Runs for Different Configurations', fontsize=16)
    plt.xlabel('QPS in thousands (K)', fontsize=14)
    plt.ylabel('95th Percentile Latency (ms)', fontsize=14)
    
    # Adjust axis limits to focus on data
    plt.ylim(bottom=0, top=1.7)  # Adjust top as needed
    plt.xlim(left=0)
    
    # Improved legend placement
    plt.legend(loc='upper right', fontsize=12)
    
    plt.tight_layout()
    plt.savefig('memcached_performance.png', dpi=300, bbox_inches='tight')
    plt.show()


def main():
    if len(sys.argv) != 13:
        print("Usage: python3 plot_part4_1.py scan_T1_C1_run1.txt scan_T1_C1_run2.txt scan_T1_C1_run3.txt " + 
              "scan_T1_C2_run1.txt scan_T1_C2_run2.txt scan_T1_C2_run3.txt " + 
              "scan_T2_C1_run1.txt scan_T2_C1_run2.txt scan_T2_C1_run3.txt " + 
              "scan_T2_C2_run1.txt scan_T2_C2_run2.txt scan_T2_C2_run3.txt")
        sys.exit(1)

    files = sys.argv[1:]
    
    # Define configurations, labels, colors, and markers
    configs = [
        ("T=1 thread, C=1 core", "1T, 1C", "blue", "+"),
        ("T=1 thread, C=2 cores", "1T, 2C", "orange", "+"),
        ("T=2 threads, C=1 core", "2T, 1C", "green", "+"),
        ("T=2 threads, C=2 cores", "2T, 2C", "purple", "+")
    ]
    
    labels = [config[1] for config in configs]
    colors = [config[2] for config in configs]
    markers = [config[3] for config in configs]
    
    all_config_data = []
    
    # Process each configuration (3 files per configuration)
    for i in range(4):  # 4 configurations
        runs_data = []
        
        # Process 3 runs for current configuration
        for j in range(3):  # 3 runs per configuration
            file_index = i * 3 + j
            file_path = files[file_index]
            
            try:
                with open(file_path, 'r') as f:
                    data_content = f.read()
                
                target_qps, achieved_qps, p95_latency = parse_memcached_data(data_content)
                runs_data.append((target_qps, achieved_qps, p95_latency))
                print(f"Processed {file_path}: {len(target_qps)} data points")
                
            except Exception as e:
                print(f"Error processing file {file_path}: {e}")
                sys.exit(1)
        
        # Calculate weighted averages and variance across runs for this configuration
        weighted_data = compute_weighted_avg(runs_data)
        all_config_data.append(weighted_data)
        print(f"Completed processing for configuration: {configs[i][0]}")
    
    # Plot all configurations
    plot_memcached_performance(all_config_data, labels, colors, markers)
    print("Plot generated successfully and saved as 'memcached_performance.png'")



if __name__ == "__main__":
    main()