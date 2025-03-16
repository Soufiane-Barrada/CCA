# Import necessary libraries
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys

# File paths (replace with your actual file paths)
file1 = "/Users/ccylmichel/Desktop/CCA/cloud-comp-arch-project/PlotPart1/mcperf_output.txt"

# Define file paths for 7 configurations, each with 3 runs
# Remplacer file1 par les vrais fichiers txt.
configurations = {
    "no_interference": [
        file1, file1, file1
    ],
    "ibench-CPU": [
        file1, file1, file1
    ],
    "ibench-l1d": [
        file1, file1, file1
    ],
    "ibench-l1i": [
        file1, file1, file1
    ],
    "ibench-l2": [
        file1, file1, file1
    ],
    "ibench-llc": [
        file1, file1, file1
    ],
    "ibench-membw": [
        file1, file1, file1
    ]
}

def read_mcperf_file(file_path):
    """Reads an mcperf output file and extracts QPS and p95."""
    df = pd.read_csv(file_path, delim_whitespace=True, comment="W")
    if "QPS" not in df.columns or "p95" not in df.columns:
        print(f"ERROR: QPS or p95 column not found in {file_path}")
        return pd.DataFrame()
    
    df = df[["QPS", "p95"]].copy()
    df["p95"] = pd.to_numeric(df["p95"], errors="coerce") / 1000  # Convert µs to ms
    df["QPS"] = pd.to_numeric(df["QPS"], errors="coerce").round(0)  # Round QPS for consistency
    return df.dropna()

def compute_weighted_avg_no_merge(df1, df2, df3):
    """Computes the weighted average and standard deviation for QPS and p95."""
    
    if not (len(df1) == len(df2) == len(df3)):
        print("Error: DataFrames do not have the same number of rows")
        return None

    weighted_qps, weighted_p95, std_p95 = [], [], []
    
    for i in range(len(df1)):
        qps1, qps2, qps3 = df1.iloc[i]["QPS"], df2.iloc[i]["QPS"], df3.iloc[i]["QPS"]
        p95_1, p95_2, p95_3 = df1.iloc[i]["p95"], df2.iloc[i]["p95"], df3.iloc[i]["p95"]

        total_qps = qps1 + qps2 + qps3
        weighted_p95_avg = (qps1 * p95_1 + qps2 * p95_2 + qps3 * p95_3) / total_qps
        weighted_qps_avg = total_qps / 3
        std_p95_val = np.var([p95_1, p95_2, p95_3], ddof=1)  # Variance instead of std

        weighted_qps.append(weighted_qps_avg)
        weighted_p95.append(weighted_p95_avg)
        std_p95.append(std_p95_val)

    return weighted_qps, weighted_p95, std_p95

    """
    Reads three mcperf output text files, extracts QPS and p95 values, 
    computes weighted average of p95 using QPS as weight, calculates standard deviation,
    and plots the results with error bars.
    """

    # Read all three files
    df1, df2, df3 = read_mcperf_file(file1), read_mcperf_file(file2), read_mcperf_file(file3)
    print("DF1:", df1)
    print("DF2:", df2)
    print("DF3:", df3)

    # Run function
    weighted_qps, weighted_p95, std_p95= compute_weighted_avg_no_merge(df1, df2, df3)
    
    print(weighted_qps)
    print(weighted_p95)
    print(std_p95)
    
    return weighted_qps, weighted_p95, std_p95

def plot_results(results):
    """
    Plots all 7 configurations on the same graph.
    :param results: Dictionary containing weighted QPS, p95, and std_p95 for each configuration
    """
    plt.figure(figsize=(12, 8))
    
    colors = ["g", "b", "orange", "r", "purple", "brown", "pink"]

    for i, (config, data) in enumerate(results.items()):
        weighted_qps, weighted_p95, std_p95 = data
        plt.errorbar(weighted_qps, weighted_p95, yerr=std_p95, capsize=3, marker='o', 
                     linestyle='-', color=colors[i], label=config)

    # Configure plot
    plt.xlabel("Achieved QPS")
    plt.ylabel("Weighted 95th Percentile Latency (ms)")
    plt.title("Part1.a")
    plt.legend()
    plt.grid()
    plt.xlim(0, 80000)  # X-axis from 0 to 80,000
    plt.ylim(0, 6)  # Y-axis from 0 to 6 ms
    plt.show()

def main():
    """
    Main function to read files, process 7 configurations, and plot results.
    """
    results = {}
    for config, files in configurations.items():
        file1, file2, file3 = files
        # Read the three files for each configuration
        df1, df2, df3 = read_mcperf_file(file1), read_mcperf_file(file2), read_mcperf_file(file3)
        # Compute weighted averages and error bars
        weighted_qps, weighted_p95, std_p95 = compute_weighted_avg_no_merge(df1, df2, df3)
        # Store results
        results[config] = (weighted_qps, weighted_p95, std_p95)

    plot_results(results)

# Run the script
if __name__ == "__main__":
    main()
    

# def main():
#     process_mcperf_runs(file1, file2, file3)
    
# def process_file(filename):
#     try:
#         with open(filename, 'r', encoding='utf-8') as file:
#             content = file.read()
#             print(f"Contents of {filename}:")
#             print(content[:100])  # Print first 100 characters for preview
#     except Exception as e:
#         print(f"Error reading {filename}: {e}")

# if __name__ == "__main__":
#     if len(sys.argv) < 2:
#         print("Usage: python script.py <file1> <file2> ...")
#     else:
#         for filename in sys.argv[1:]:
#             process_file(filename)

