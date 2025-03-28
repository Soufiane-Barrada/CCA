import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("speedup_data.csv")

df_single_thread = df[df["Threads"] == 1][["Workload", "Real_Time"]].rename(columns={"Real_Time": "Base_Time"})
df_speedup = pd.merge(df, df_single_thread, on="Workload")
df_speedup["Speedup"] = df_speedup["Base_Time"] / df_speedup["Real_Time"]

plt.figure(figsize=(12, 6))

for workload in df_speedup["Workload"].unique():
    workload_data = df_speedup[df_speedup["Workload"] == workload]
    plt.plot(
        workload_data["Threads"],
        workload_data["Speedup"],
        marker='o',
        label=workload
    )

plt.title("Speedup vs Number of Threads")
plt.xlabel("Number of Threads")
plt.ylabel("Speedup (Time_1 / Time_n)")
plt.xticks([1, 2, 4, 8])
plt.grid(True, linestyle='--', alpha=0.6)
plt.legend(title="Workloads", bbox_to_anchor=(1.05, 1), loc="upper left")
plt.tight_layout()

#save the plot 
plt.savefig("speedup_plot.png")
print("✅ Plot saved as speedup_plot.png")
plt.show()

