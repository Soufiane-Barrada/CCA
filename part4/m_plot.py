import pandas as pd
import matplotlib.pyplot as plt

T = 2
C = 1
scan_path = f"./part4_q1d_logs/scan_T{T}_C{C}.txt"
cpu_path = f"./part4_q1d_logs/cpu_T{T}_C{C}.txt"



scan_data = []
with open(scan_path, 'r') as f:
    for line in f:
        if line.startswith("read"):
            parts = line.strip().split()
            p95_latency = float(parts[12])  # p95
            qps = float(parts[-4])  # achieved QPS
            scan_data.append((qps, p95_latency))

scan_df = pd.DataFrame(scan_data, columns=["QPS", "P95_Latency"])


cpu_data = pd.read_csv(cpu_path, sep=" ", header=None, names=["CPU", "Timestamp"])
cpu_data["CPU"] = cpu_data["CPU"].astype(float)

min_len = min(len(scan_df), len(cpu_data))
scan_df = scan_df.iloc[:min_len].reset_index(drop=True)
cpu_data = cpu_data.iloc[:min_len].reset_index(drop=True)

fig, ax1 = plt.subplots(figsize=(10, 6))


ax1.plot(scan_df["QPS"], scan_df["P95_Latency"], label="P95 Latency (µs)", color="blue")
ax1.set_ylabel("P95 Latency (µs)", color="blue")
ax1.set_xlabel("Achieved QPS")
ax1.axhline(y=800, color='blue', linestyle='dotted', label="0.8ms SLO")
ax1.tick_params(axis='y', labelcolor='blue')

ax2 = ax1.twinx()
ax2.plot(scan_df["QPS"], cpu_data["CPU"], label="CPU Usage (%)", color="green")
max_cpu = 100 if C == 1 else 200
ax2.set_ylim(0, max_cpu)
ax2.set_ylabel(f"CPU Utilization (0–{max_cpu}%)", color="green")
ax2.tick_params(axis='y', labelcolor='green')

fig.suptitle(f"Memcached Performance (T={T}, C={C})")
fig.tight_layout()
plt.show()
