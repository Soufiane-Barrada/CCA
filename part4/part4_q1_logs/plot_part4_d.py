import numpy as np
import matplotlib.pyplot as plt
import re
import sys

def parse_memcached_data(data_content):
    """Parse memcached data file and extract achieved QPS and latency information."""
    lines = data_content.strip().split('\n')
    achieved_qps_values = []
    p95_latency_values = []
    
    for line in lines[1:]:  # Skip header line
        if line.startswith('read'):
            parts = re.split(r'\s+', line.strip())
            if len(parts) >= 17:
                p95_latency = float(parts[12]) / 1000.0  # Convert to ms
                achieved_qps = float(parts[16])  # Use achieved QPS (index 16) instead of target
                
                # Filter out zero or negative QPS values
                if achieved_qps > 0:
                    achieved_qps_values.append(achieved_qps)
                    p95_latency_values.append(p95_latency)
    
    return np.array(achieved_qps_values), np.array(p95_latency_values)

def plot_p95_latency(file_path):
    """Plot p95 latency against achieved QPS."""
    try:
        with open(file_path, 'r') as f:
            data_content = f.read()
        
        achieved_qps, p95_latency = parse_memcached_data(data_content)
        print(f"Processed {file_path}: {len(achieved_qps)} data points")
        
        if len(achieved_qps) == 0:
            print("No data points found!")
            return
            
        # Sort data points by achieved QPS for better line plots
        sort_idx = np.argsort(achieved_qps)
        achieved_qps = achieved_qps[sort_idx]
        p95_latency = p95_latency[sort_idx]
        
        # Create figure
        plt.figure(figsize=(12, 8))
        
        # Plot p95 latency against achieved QPS
        plt.plot(achieved_qps/1000.0, p95_latency, 'r-+',linewidth=1, markersize=6, label='p95 Latency')
        
        # Add horizontal line at 0.8ms for latency threshold
        plt.axhline(y=0.8, color='green', linestyle='--', alpha=0.7, label='0.8ms latency threshold')
        
        # Set labels and title
        plt.xlabel('Achieved QPS (K)', fontsize=14)
        plt.ylabel('95th Percentile Latency (ms)', fontsize=14, color='red')
        plt.title('Memcached Performance: p95 Latency vs. Achieved QPS', fontsize=16)
        
        # Configure axes
        plt.xlim(left=0, right=230)  # Set x-axis from 0 to 230K
        plt.ylim(bottom=0)  # Start y-axis at 0
        plt.grid(True, alpha=0.3)
        
        # Add legend
        plt.legend(loc='upper left')
        
        plt.tight_layout()
        plt.savefig('memcached_p95_vs_achieved_qps.png', dpi=300, bbox_inches='tight')
        plt.show()
        print("Plot generated successfully and saved as 'memcached_p95_vs_achieved_qps.png'")
        
    except Exception as e:
        print(f"Error processing file {file_path}: {e}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 plot_p95_vs_achieved.py <memcached_data_file.txt>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    plot_p95_latency(file_path)

if __name__ == "__main__":
    main()